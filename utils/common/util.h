/* See LICENSE file for copyright and license details. */
#ifndef UTIL_H
#define UTIL_H

#include <stdarg.h>

#define LEN(x) (sizeof(x) / sizeof((x)[0]))

extern char *argv0;

void die(const char *fmt, ...);
void warn(const char *fmt, ...);
int pscanf(const char *path, const char *fmt, ...);
int exec_wait(const char *const argv[]);
void exec_detach(const char *const argv[]);
void setup_sigchld(void);

#endif /* UTIL_H */
