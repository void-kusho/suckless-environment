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

static int read_int_cmd(const char *cmd);
static int get_brightness_raw(void);
static int get_max_brightness(void);
static int set_brightness_raw(int value);
static void send_osd(int percent);

static int
read_int_cmd(const char *cmd)
{
	FILE *fp;
	int value = -1;
	char buf[32];

	fp = popen(cmd, "r");
	if (!fp)
		return -1;

	if (fgets(buf, sizeof(buf), fp))
		value = atoi(buf);
	pclose(fp);

	return value;
}

static int
get_brightness_raw(void)
{
	/* `brightnessctl g` returns raw value (e.g. 96000), not percent */
	return read_int_cmd("brightnessctl -c " BACKLIGHT_DEV " g");
}

static int
get_max_brightness(void)
{
	return read_int_cmd("brightnessctl -c " BACKLIGHT_DEV " m");
}

static int
set_brightness_raw(int value)
{
	char cmd[64];

	snprintf(cmd, sizeof(cmd),
	         "brightnessctl -c %s s %d",
	         BACKLIGHT_DEV, value);

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
	int current, max_raw, step_raw, min_raw, new, percent;
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

	/* Get current and max brightness in raw units */
	current = get_brightness_raw();
	max_raw = get_max_brightness();
	if (current < 0 || max_raw <= 0) {
		close(fd);
		warn("failed to get brightness");
		return 1;
	}

	/* Convert percent-based config to raw step/floor */
	step_raw = max_raw * STEP_SIZE / 100;
	if (step_raw < 1)
		step_raw = 1;
	min_raw = max_raw * MIN_BRIGHTNESS / 100;

	/* Calculate new brightness in raw units */
	new = current + (direction * step_raw);

	/* Enforce floor (prevent black screen) and ceiling */
	if (new < min_raw)
		new = min_raw;
	if (new > max_raw)
		new = max_raw;

	/* Set the new brightness */
	set_brightness_raw(new);

	/* Compute percent for OSD */
	percent = (new * 100 + max_raw / 2) / max_raw;

	/* Send OSD notification with progress bar */
	send_osd(percent);

	/* Release lock */
	flock(fd, LOCK_UN);
	close(fd);

	return 0;
}