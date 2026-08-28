/* See LICENSE file for copyright and license details. */

/* Lock command — default to swaylock (Wayland) on Guix,
 * override to slock/other via config.h or CFLAGS. */
#ifndef LOCK_CMD
#define LOCK_CMD "swaylock"
#endif

/* PGREP_TARGET is the process name substring to check for duplicates.
 * swaylock is 8 chars (< 15 TASK_COMM_LEN), betterlockscreen is 16. */
#ifndef LOCK_PGREP_TARGET
#define LOCK_PGREP_TARGET "swaylock"
#endif
