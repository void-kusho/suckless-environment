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
#include <sys/stat.h>
#include <unistd.h>

#include "../common/util.h"
#include "config.h"

#define FNV_OFFSET_BASIS 0xcbf29ce484222325ULL
#define FNV_PRIME        0x100000001b3ULL

/* The daemon delegates clipboard watching to wl-clipboard: `wl-paste --watch`
 * re-runs our own process (with the "store" argv) on every clipboard change,
 * piping the new contents to stdin.  The top-level daemon process holds the
 * single-instance lock and simply waits on wl-paste.
 */
#define CMD_STORE "store"

static char cache_dir[PATH_MAX];
static int lock_fd = -1;
static volatile sig_atomic_t done = 0;

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

	/* Skip if already cached (content-hash dedup). */
	if (access(path, F_OK) == 0)
		return;

	fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0600);
	if (fd < 0) {
		warn("open '%s':", path);
		return;
	}

	write(fd, text, len);
	close(fd);

	prune_old_entries();
}

/* Child invocation (via wl-paste --watch): store one clipboard snapshot. */
static int
run_store(void)
{
	char *buf;
	size_t cap, len;
	ssize_t n;

	cap = 4096;
	len = 0;
	buf = malloc(cap + 1);
	if (!buf)
		die("malloc:");

	for (;;) {
		if (len == cap) {
			cap *= 2;
			buf = realloc(buf, cap + 1);
			if (!buf)
				die("realloc:");
		}
		n = read(STDIN_FILENO, buf + len, cap - len);
		if (n < 0) {
			if (errno == EINTR)
				continue;
			break;
		}
		if (n == 0)
			break;
		len += (size_t)n;
	}

	if (len > 0 && !is_whitespace_only(buf, len))
		store_entry(buf, len);

	free(buf);
	return 0;
}

/* Top-level: hold the lock and run `wl-paste --watch <self> store`. */
static void
run_daemon(void)
{
	const char *argv[] = { "wl-paste", "--watch", NULL, CMD_STORE, NULL };
	char self[PATH_MAX];
	ssize_t n;

	n = readlink("/proc/self/exe", self, sizeof(self) - 1);
	if (n <= 0)
		die("readlink /proc/self/exe:");
	self[n] = '\0';
	argv[2] = self;

	while (!done) {
		execvp(argv[0], (char *const *)argv);
		/* wl-paste --watch only exits on error / done; if it returns,
		 * wait briefly and retry (e.g. transient Wayland failure). */
		warn("wl-paste returned; retrying");
		sleep(1);
	}
}

int
main(int argc, char *argv[])
{
	struct sigaction sa;

	argv0 = argv[0];

	/* Resolve cache directory */
	if (get_cache_dir(cache_dir, sizeof(cache_dir)) < 0)
		die("cache dir path too long");

	/* Create cache directory if missing */
	if (mkdir(cache_dir, 0700) < 0 && errno != EEXIST)
		die("mkdir '%s':", cache_dir);

	if (argc > 1 && strcmp(argv[1], CMD_STORE) == 0)
		return run_store();

	/* Top-level daemon: single instance + clipboard watching. */
	acquire_lock(cache_dir);

	/* Set up signal handlers (do NOT use SA_RESTART). */
	sa.sa_handler = sigterm_handler;
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = 0;
	sigaction(SIGTERM, &sa, NULL);
	sigaction(SIGINT, &sa, NULL);

	run_daemon();

	if (lock_fd >= 0)
		close(lock_fd);

	return 0;
}
