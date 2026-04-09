/* See LICENSE file for copyright and license details. */
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/select.h>
#include <sys/stat.h>
#include <unistd.h>

#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/extensions/Xfixes.h>

#include "../common/util.h"
#include "config.h"

#define FNV_OFFSET_BASIS 0xcbf29ce484222325ULL
#define FNV_PRIME        0x100000001b3ULL

/* Maximum iterations waiting for SelectionNotify (50 * 10ms = 500ms) */
#define CONVERT_RETRIES  50
#define CONVERT_DELAY    10000 /* microseconds */

static Display *dpy;
static Window win;
static int xfixes_event_base;
static Atom clipboard_atom;
static Atom utf8_string_atom;
static Atom xa_string_atom;
static Atom xsel_data_atom;
static int lock_fd = -1;
static volatile sig_atomic_t done = 0;
static char cache_dir[PATH_MAX];

struct prune_entry {
	char name[NAME_MAX + 1];
	time_t mtime;
};

static void
sigterm_handler(int sig)
{
	(void)sig;
	done = 1;
}

static int
get_cache_dir(char *buf, size_t bufsz)
{
	const char *cache, *home;
	int ret;

	cache = getenv("XDG_CACHE_HOME");
	if (cache && cache[0] != '\0') {
		ret = snprintf(buf, bufsz, "%s/%s", cache, CACHE_DIR_NAME);
	} else {
		home = getenv("HOME");
		if (!home)
			die("HOME not set");
		ret = snprintf(buf, bufsz, "%s/.cache/%s", home, CACHE_DIR_NAME);
	}

	if (ret < 0 || (size_t)ret >= bufsz)
		return -1;
	return 0;
}

static void
acquire_lock(const char *dir)
{
	char lockpath[PATH_MAX];
	int ret;

	ret = snprintf(lockpath, sizeof(lockpath), "%s/.lock", dir);
	if (ret < 0 || (size_t)ret >= sizeof(lockpath))
		die("lock path too long");

	lock_fd = open(lockpath, O_CREAT | O_RDWR, 0600);
	if (lock_fd < 0)
		die("open '%s':", lockpath);

	if (flock(lock_fd, LOCK_EX | LOCK_NB) < 0) {
		if (errno == EWOULDBLOCK)
			die("dmenu-clipd: already running");
		die("flock:");
	}
}

static uint64_t
fnv1a(const char *data, size_t len)
{
	uint64_t hash = FNV_OFFSET_BASIS;
	size_t i;

	for (i = 0; i < len; i++) {
		hash ^= (uint8_t)data[i];
		hash *= FNV_PRIME;
	}
	return hash;
}

static void
hash_to_filename(uint64_t hash, char *buf, size_t bufsz)
{
	snprintf(buf, bufsz, "%016llx", (unsigned long long)hash);
}

static int
is_whitespace_only(const char *s, size_t len)
{
	size_t i;

	for (i = 0; i < len; i++) {
		if (s[i] != ' ' && s[i] != '\t' &&
		    s[i] != '\n' && s[i] != '\r')
			return 0;
	}
	return 1;
}

static void
setup_x11(void)
{
	int evt_base, err_base;

	dpy = XOpenDisplay(NULL);
	if (!dpy)
		die("XOpenDisplay: failed to open display");

	if (!XFixesQueryExtension(dpy, &evt_base, &err_base))
		die("XFixes extension not available");
	xfixes_event_base = evt_base;

	/* Create invisible window for receiving SelectionNotify events */
	win = XCreateSimpleWindow(dpy, DefaultRootWindow(dpy),
	                          0, 0, 1, 1, 0, 0, 0);

	clipboard_atom = XInternAtom(dpy, "CLIPBOARD", False);
	utf8_string_atom = XInternAtom(dpy, "UTF8_STRING", False);
	xa_string_atom = XA_STRING;
	xsel_data_atom = XInternAtom(dpy, "XSEL_DATA", False);

	/* Register for clipboard owner change events -- CLIPBOARD only (D-01, D-02) */
	XFixesSelectSelectionInput(dpy, win, clipboard_atom,
	                           XFixesSetSelectionOwnerNotifyMask);
	XFlush(dpy);
}

/*
 * Wait for a SelectionNotify event with bounded retry.
 * Returns 1 if event received, 0 on timeout.
 */
static int
wait_selection_notify(XEvent *ev)
{
	int i;

	for (i = 0; i < CONVERT_RETRIES; i++) {
		if (XCheckTypedWindowEvent(dpy, win, SelectionNotify, ev))
			return 1;
		XFlush(dpy);
		usleep(CONVERT_DELAY);
	}
	return 0;
}

static char *
get_clipboard_text(size_t *out_len)
{
	XEvent ev;
	Atom actual_type;
	int actual_format;
	unsigned long nitems, bytes_after;
	unsigned char *prop_data = NULL;
	char *result = NULL;

	*out_len = 0;

	/* Step 1: Request conversion to UTF8_STRING */
	XConvertSelection(dpy, clipboard_atom, utf8_string_atom,
	                  xsel_data_atom, win, CurrentTime);
	XFlush(dpy);

	/* Step 2: Wait for SelectionNotify */
	if (!wait_selection_notify(&ev)) {
		return NULL; /* Timeout -- owner unresponsive */
	}

	/* Step 2b: If UTF8_STRING failed, try STRING fallback (D-05) */
	if (ev.xselection.property == None) {
		XConvertSelection(dpy, clipboard_atom, xa_string_atom,
		                  xsel_data_atom, win, CurrentTime);
		XFlush(dpy);

		if (!wait_selection_notify(&ev)) {
			return NULL;
		}
		if (ev.xselection.property == None) {
			return NULL; /* Not text content */
		}
	}

	/* Step 3: Read the property data */
	XGetWindowProperty(dpy, win, xsel_data_atom, 0, LONG_MAX, True,
	                   AnyPropertyType, &actual_type, &actual_format,
	                   &nitems, &bytes_after, &prop_data);

	if (prop_data && nitems > 0) {
		result = malloc(nitems + 1);
		if (result) {
			memcpy(result, prop_data, nitems);
			result[nitems] = '\0';
			*out_len = nitems;
		}
	}
	if (prop_data)
		XFree(prop_data);

	return result;
}

static int
cmp_mtime_asc(const void *a, const void *b)
{
	const struct prune_entry *ea = a;
	const struct prune_entry *eb = b;

	if (ea->mtime < eb->mtime)
		return -1;
	if (ea->mtime > eb->mtime)
		return 1;
	return 0;
}

static void
prune_old_entries(void)
{
	DIR *dp;
	struct dirent *de;
	struct stat st;
	char path[PATH_MAX];
	struct prune_entry files[MAX_ENTRIES + 20];
	int count = 0, i, ret, to_remove;

	dp = opendir(cache_dir);
	if (!dp)
		return;

	while ((de = readdir(dp)) != NULL) {
		if (de->d_name[0] == '.')
			continue;

		ret = snprintf(path, sizeof(path), "%s/%s",
		               cache_dir, de->d_name);
		if (ret < 0 || (size_t)ret >= sizeof(path))
			continue;

		if (stat(path, &st) < 0)
			continue;
		if (!S_ISREG(st.st_mode))
			continue;

		if (count < (int)(sizeof(files) / sizeof(files[0]))) {
			snprintf(files[count].name, sizeof(files[count].name),
			         "%s", de->d_name);
			files[count].mtime = st.st_mtime;
			count++;
		}
	}
	closedir(dp);

	if (count <= MAX_ENTRIES)
		return;

	/* Sort oldest first, remove excess */
	qsort(files, count, sizeof(files[0]), cmp_mtime_asc);

	to_remove = count - MAX_ENTRIES;
	for (i = 0; i < to_remove; i++) {
		ret = snprintf(path, sizeof(path), "%s/%s",
		               cache_dir, files[i].name);
		if (ret < 0 || (size_t)ret >= sizeof(path))
			continue;
		unlink(path);
	}
}

static void
store_entry(const char *text, size_t len)
{
	uint64_t hash;
	char hashname[20];
	char path[PATH_MAX];
	int fd, ret;

	hash = fnv1a(text, len);
	hash_to_filename(hash, hashname, sizeof(hashname));

	ret = snprintf(path, sizeof(path), "%s/%s", cache_dir, hashname);
	if (ret < 0 || (size_t)ret >= sizeof(path))
		return; /* Path too long, skip */

	fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0600);
	if (fd < 0) {
		warn("open '%s':", path);
		return;
	}

	write(fd, text, len);
	close(fd);

	prune_old_entries();
}

static void
handle_event(XEvent *ev)
{
	char *text;
	size_t len;

	if (ev->type == xfixes_event_base + XFixesSelectionNotify) {
		text = get_clipboard_text(&len);
		if (text && len > 0 && !is_whitespace_only(text, len))
			store_entry(text, len);
		free(text);
	}
	/* Silently ignore all other event types */
}

static void
run_event_loop(void)
{
	int xfd = ConnectionNumber(dpy);
	fd_set fds;
	struct timeval tv;
	XEvent ev;

	while (!done) {
		/* Drain buffered events first (Pitfall 2) */
		while (XPending(dpy) > 0) {
			XNextEvent(dpy, &ev);
			handle_event(&ev);
			if (done)
				return;
		}

		/* Wait for X11 data or timeout (1 second) */
		FD_ZERO(&fds);
		FD_SET(xfd, &fds);
		tv.tv_sec = 1;
		tv.tv_usec = 0;

		select(xfd + 1, &fds, NULL, NULL, &tv);
		/* On timeout: loop back, check done flag */
		/* On data: loop back, XPending will find events */
		/* On EINTR (signal): loop back, done flag set by handler */
	}
}

int
main(int argc, char *argv[])
{
	struct sigaction sa;

	(void)argc;
	argv0 = argv[0];

	/* Resolve cache directory */
	if (get_cache_dir(cache_dir, sizeof(cache_dir)) < 0)
		die("cache dir path too long");

	/* Create cache directory if missing */
	if (mkdir(cache_dir, 0700) < 0 && errno != EEXIST)
		die("mkdir '%s':", cache_dir);

	/* Acquire single-instance lock (D-10) */
	acquire_lock(cache_dir);

	/* Set up signal handlers (D-11) -- do NOT use SA_RESTART */
	sa.sa_handler = sigterm_handler;
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = 0;
	sigaction(SIGTERM, &sa, NULL);
	sigaction(SIGINT, &sa, NULL);

	/* Initialize X11 and XFixes (D-03) */
	setup_x11();

	/* Enter event loop (D-13) */
	run_event_loop();

	/* Clean shutdown (D-12) */
	XDestroyWindow(dpy, win);
	XCloseDisplay(dpy);
	if (lock_fd >= 0)
		close(lock_fd);

	return 0;
}
