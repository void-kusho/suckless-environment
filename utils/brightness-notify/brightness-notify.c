/* See LICENSE file for copyright and license details. */
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <unistd.h>

#include "../common/util.h"
#include "config.h"

#define LOCK_FILE   "/tmp/brightness.lock"
#define BACKLIGHT_DEV "backlight"

static int get_brightness(void);
static int set_brightness(int percent);
static void send_osd(int percent);

static int
get_brightness(void)
{
	FILE *fp;
	int percent = -1;
	char buf[32];

	/* Use brightnessctl to get current brightness */
	fp = popen("brightnessctl -c backlight g", "r");
	if (!fp)
		return -1;

	if (fgets(buf, sizeof(buf), fp)) {
		/* Parse percentage from output like "80%" */
		char *p = strchr(buf, '%');
		if (p)
			*p = '\0';
		percent = atoi(buf);
	}
	pclose(fp);

	return percent;
}

static int
set_brightness(int percent)
{
	char cmd[64];

	/* Clamp to valid range */
	if (percent < MIN_BRIGHTNESS)
		percent = MIN_BRIGHTNESS;
	if (percent > MAX_BRIGHTNESS)
		percent = MAX_BRIGHTNESS;

	/* Set absolute brightness via brightnessctl */
	snprintf(cmd, sizeof(cmd),
	         "brightnessctl -c %s s %d%%",
	         BACKLIGHT_DEV, percent);

	/* Shell out to brightnessctl */
	const char *argv[] = { "sh", "-c", cmd, NULL };
	return exec_wait(argv);
}

static void
send_osd(int percent)
{
	char notif_cmd[128];

	/* Build command with replace-id and progress bar for dunst */
	snprintf(notif_cmd, sizeof(notif_cmd),
	        "notify-send -r %d 'Brightness: %d%%' -h int:value:%d",
	        REPLACE_ID, percent, percent);

	const char *shargv[] = { "sh", "-c", notif_cmd, NULL };
	exec_detach(shargv);
}

int
main(int argc, char *argv[])
{
	int fd;
	int current, new;
	int direction = 0;

	argv0 = argv[0];
	setup_sigchld();

	/* Parse argument: "up" or "down" */
	if (argc != 2) {
		die("usage: brightness-notify {up|down}");
		return 1;
	}

	if (strcmp(argv[1], "up") == 0) {
		direction = 1;
	} else if (strcmp(argv[1], "down") == 0) {
		direction = -1;
	} else {
		die("invalid argument: %s (use up or down)", argv[1]);
		return 1;
	}

	/* flock serialization to prevent fork-storm on rapid key-repeat */
	fd = open(LOCK_FILE, O_CREAT | O_RDWR, 0600);
	if (fd < 0)
		return 1;

	if (flock(fd, LOCK_EX | LOCK_NB) != 0) {
		/* Another instance already running - exit silently */
		close(fd);
		return 0;
	}

	/* Get current brightness */
	current = get_brightness();
	if (current < 0) {
		close(fd);
		warn("failed to get brightness");
		return 1;
	}

	/* Calculate new brightness with step */
	new = current + (direction * STEP_SIZE);

	/* Enforce floor (prevent black screen) */
	if (new < MIN_BRIGHTNESS)
		new = MIN_BRIGHTNESS;
	/* Enforce ceiling */
	if (new > MAX_BRIGHTNESS)
		new = MAX_BRIGHTNESS;

	/* Set the new brightness */
	set_brightness(new);

	/* Send OSD notification with progress bar */
	send_osd(new);

	/* Release lock */
	flock(fd, LOCK_UN);
	close(fd);

	return 0;
}