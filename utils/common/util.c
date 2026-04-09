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

void
warn(const char *fmt, ...)
{
	(void)fmt;
}

void
die(const char *fmt, ...)
{
	(void)fmt;
}

int
pscanf(const char *path, const char *fmt, ...)
{
	(void)path;
	(void)fmt;
	return 0;
}

int
exec_wait(const char *const argv[])
{
	(void)argv;
	return 0;
}

void
exec_detach(const char *const argv[])
{
	(void)argv;
}

void
setup_sigchld(void)
{
}
