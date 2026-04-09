/* See LICENSE file for copyright and license details. */
#include <errno.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#include "util.h"

char *argv0;

static void
verr(const char *fmt, va_list ap)
{
	if (argv0)
		fprintf(stderr, "%s: ", argv0);

	vfprintf(stderr, fmt, ap);

	if (fmt[0] && fmt[strlen(fmt) - 1] == ':') {
		fputc(' ', stderr);
		perror(NULL);
	} else {
		fputc('\n', stderr);
	}
}

void
warn(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	verr(fmt, ap);
	va_end(ap);
}

void
die(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	verr(fmt, ap);
	va_end(ap);

	exit(1);
}

int
pscanf(const char *path, const char *fmt, ...)
{
	FILE *fp;
	va_list ap;
	int n;

	if (!(fp = fopen(path, "r"))) {
		warn("fopen '%s':", path);
		return -1;
	}
	va_start(ap, fmt);
	n = vfscanf(fp, fmt, ap);
	va_end(ap);
	fclose(fp);

	return (n == EOF) ? -1 : n;
}

int
exec_wait(const char *const argv[])
{
	pid_t pid;
	int status;

	pid = fork();
	if (pid < 0)
		die("fork:");
	if (pid == 0) {
		execvp(argv[0], (char *const *)argv);
		_exit(127);
	}
	waitpid(pid, &status, 0);
	return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}

void
exec_detach(const char *const argv[])
{
	pid_t pid;

	pid = fork();
	if (pid < 0)
		die("fork:");
	if (pid == 0) {
		setsid();
		execvp(argv[0], (char *const *)argv);
		_exit(127);
	}
	/* Parent returns immediately. SIGCHLD handler reaps zombie. */
}

static void
sigchld_handler(int sig)
{
	(void)sig;
	while (waitpid(-1, NULL, WNOHANG) > 0)
		;
}

void
setup_sigchld(void)
{
	struct sigaction sa;

	sa.sa_handler = sigchld_handler;
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = SA_RESTART | SA_NOCLDSTOP;
	if (sigaction(SIGCHLD, &sa, NULL) < 0)
		warn("sigaction:");
}
