/* See LICENSE file for copyright and license details. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#include "../common/dmenu.h"
#include "../common/util.h"
#include "config.h"

static int
capture_stdout(const char *const argv[], char *buf, size_t bufsz)
{
	int fd[2];
	pid_t pid;
	ssize_t n;

	if (pipe(fd) < 0)
		return -1;

	pid = fork();
	if (pid < 0) {
		close(fd[0]);
		close(fd[1]);
		return -1;
	}

	if (pid == 0) {
		close(fd[0]);
		dup2(fd[1], STDOUT_FILENO);
		close(fd[1]);
		execvp(argv[0], (char *const *)argv);
		_exit(127);
	}

	close(fd[1]);
	n = read(fd[0], buf, bufsz - 1);
	close(fd[0]);
	waitpid(pid, NULL, 0);

	if (n <= 0)
		return -1;

	buf[n] = '\0';

	/* Strip trailing newline */
	if (n > 0 && buf[n - 1] == '\n')
		buf[n - 1] = '\0';

	return 0;
}

int
main(int argc, char *argv[])
{
	DmenuCtx *ctx;
	char *sel;
	char current[64];
	char prompt[80];

	(void)argc;
	argv0 = argv[0];
	setup_sigchld();

#if USE_CPUPOWER
	/* cpupower backend — uses governor names */
	const char *get_cmd[] = { "cpupower", "frequency-info", "-p", NULL };
	const char *set_cmd[] = { "cpupower", "frequency-set", "-g", NULL, NULL };

	if (capture_stdout(get_cmd, current, sizeof(current)) < 0)
		snprintf(current, sizeof(current), "unknown");

	snprintf(prompt, sizeof(prompt), "cpu: %s", current);

	ctx = dmenu_open(prompt, 3, argv + 1);
	dmenu_write(ctx, "performance");
	dmenu_write(ctx, "ondemand");
	dmenu_write(ctx, "powersave");
	sel = dmenu_read(ctx);
	dmenu_close(ctx);

	if (!sel)
		return 0;

	if (strcmp(sel, "performance") != 0 &&
	    strcmp(sel, "ondemand") != 0 &&
	    strcmp(sel, "powersave") != 0) {
		free(sel);
		return 1;
	}

	set_cmd[3] = sel;
	if (exec_wait(set_cmd) != 0)
		warn("cpupower frequency-set failed");
#else
	/* power-profiles-daemon backend — uses profile names */
	const char *get_cmd[] = { "powerprofilesctl", "get", NULL };
	const char *set_cmd[] = { "powerprofilesctl", "set", NULL, NULL };

	if (capture_stdout(get_cmd, current, sizeof(current)) < 0)
		snprintf(current, sizeof(current), "unknown");

	snprintf(prompt, sizeof(prompt), "cpu: %s", current);

	ctx = dmenu_open(prompt, 3, argv + 1);
	dmenu_write(ctx, "performance");
	dmenu_write(ctx, "balanced");
	dmenu_write(ctx, "power-saver");
	sel = dmenu_read(ctx);
	dmenu_close(ctx);

	if (!sel)
		return 0;

	if (strcmp(sel, "performance") != 0 &&
	    strcmp(sel, "balanced") != 0 &&
	    strcmp(sel, "power-saver") != 0) {
		free(sel);
		return 1;
	}

	set_cmd[2] = sel;
	if (exec_wait(set_cmd) != 0)
		warn("powerprofilesctl set failed");
#endif

	free(sel);
	return 0;
}
