/* See LICENSE file for copyright and license details. */
/*
 * dmenu pipe helpers -- stub implementation.
 * Full implementation in plan 01-02 (dmenu pipe API).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#include "dmenu.h"
#include "util.h"

DmenuCtx *
dmenu_open(const char *prompt, char *const extra_argv[])
{
	(void)prompt;
	(void)extra_argv;
	warn("dmenu_open: not yet implemented");
	return NULL;
}

void
dmenu_write(DmenuCtx *ctx, const char *item)
{
	(void)ctx;
	(void)item;
}

char *
dmenu_read(DmenuCtx *ctx)
{
	(void)ctx;
	return NULL;
}

void
dmenu_close(DmenuCtx *ctx)
{
	(void)ctx;
}
