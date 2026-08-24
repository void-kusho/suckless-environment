/* See LICENSE file for copyright and license details. */

/* Lock command — default to slock (free, suckless) on Guix,
 * override to betterlockscreen on Arch/Artix via config.h or CFLAGS. */
#ifndef LOCK_CMD
#define LOCK_CMD "slock"
#endif

/* PGREP_TARGET is the process name substring to check for duplicates.
 * slock is 5 chars (< 15 TASK_COMM_LEN), betterlockscreen is 16. */
#ifndef LOCK_PGREP_TARGET
#define LOCK_PGREP_TARGET "slock"
#endif
