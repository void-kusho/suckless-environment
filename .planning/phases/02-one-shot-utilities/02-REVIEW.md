---
phase: 02-one-shot-utilities
reviewed: 2026-04-09T14:50:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - utils/battery-notify/battery-notify.c
  - utils/battery-notify/config.def.h
  - utils/battery-notify/config.h
  - utils/screenshot-notify/screenshot-notify.c
  - utils/Makefile
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-04-09T14:50:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed two C utility programs (battery-notify and screenshot-notify), their config headers, and the shared Makefile. Both programs are well-structured, follow suckless conventions, and use the shared `util.h`/`util.c` library correctly. The screenshot-notify pipe-and-fork pattern is clean and handles cancellation properly.

Three warnings were identified: a symlink attack vector on the battery state file in `/tmp`, missing truncation detection on `snprintf` calls, and a misleading unused parameter. Two informational items note minor robustness gaps. No critical issues were found.

## Warnings

### WR-01: Predictable state file path in world-writable /tmp directory

**File:** `utils/battery-notify/config.def.h:10` (also `config.h:10`)
**Issue:** `STATE_FILE` is defined as `/tmp/battery-notified`, a fixed predictable path in a world-writable directory. On a multi-user system, another user could create a symlink at that path pointing to a sensitive file. When the program calls `fopen(STATE_FILE, "w")` at `battery-notify.c:56`, it would follow the symlink and truncate the target file. This is a classic symlink/TOCTOU attack vector. While low risk on a single-user desktop, it is a known security antipattern.
**Fix:** Use `$XDG_RUNTIME_DIR` (which is per-user and mode 0700) or embed the UID in the path:
```c
/* State file to prevent duplicate alerts */
#define STATE_FILE "/run/user/1000/battery-notified"
```
Or compute at runtime using `getuid()` to construct a path under `/run/user/<uid>/`.

### WR-02: snprintf checked for encoding error but not truncation

**File:** `utils/battery-notify/battery-notify.c:18-23`
**Issue:** Both `snprintf` calls check `< 0` (encoding error), but do not check for truncation (`return value >= sizeof(path)`). If the `BATTERY` macro were ever set to an extremely long string, the path would be silently truncated, and the program would attempt to open the wrong file. With `PATH_MAX` (4096) this is unlikely in practice, but the check as written gives a false sense of completeness.
**Fix:** Check for both error and truncation:
```c
int n = snprintf(path, sizeof(path), CAP_PATH, BATTERY);
if (n < 0 || (size_t)n >= sizeof(path))
    return -1;
```

### WR-03: slen parameter accepted but not used for bounds checking

**File:** `utils/battery-notify/battery-notify.c:14,25,28`
**Issue:** `read_battery()` accepts a `slen` parameter (size of the `status` buffer) but silently discards it with `(void)slen` on line 28. The `pscanf` format string `"%15[a-zA-Z ]"` hardcodes the maximum field width to 15, which only works correctly if the caller passes a buffer of exactly 16 bytes. If the caller ever changes the buffer size without updating this function, a buffer overflow or truncation would occur silently. The function signature promises size-safety but does not deliver it.
**Fix:** Either remove the `slen` parameter since the format width is hardcoded (simpler and honest), or use `slen` to build the format string dynamically:
```c
/* Option A: Remove misleading parameter */
static int
read_battery(int *cap, char *status)
{
    /* ... */
    if (pscanf(path, "%15[a-zA-Z ]", status) != 1)
        return -1;
    return 0;
}

/* Option B: Use slen (more robust) */
char fmt[32];
snprintf(fmt, sizeof(fmt), "%%%zu[a-zA-Z ]", slen - 1);
if (pscanf(path, fmt, status) != 1)
    return -1;
```

## Info

### IN-01: snprintf return value unchecked when formatting notification body

**File:** `utils/battery-notify/battery-notify.c:49`
**Issue:** The `snprintf` call formatting the notification body does not check its return value. If truncation occurred, the notification text would be incomplete but otherwise harmless.
**Fix:** Add a return value check for consistency with the style used on lines 18 and 23, or add a comment acknowledging the intentional omission:
```c
snprintf(body, sizeof(body), "Battery at %d%%", cap); /* truncation harmless */
```

### IN-02: State file creation failure silently ignored

**File:** `utils/battery-notify/battery-notify.c:56-58`
**Issue:** If `fopen(STATE_FILE, "w")` fails (e.g., permissions, disk full), no warning is emitted. The program will re-send the notification on every subsequent invocation since the state file was never created. This is arguably acceptable fail-open behavior, but it makes debugging harder.
**Fix:** Add a `warn()` call on failure:
```c
fp = fopen(STATE_FILE, "w");
if (fp)
    fclose(fp);
else
    warn("fopen '%s':", STATE_FILE);
```

---

_Reviewed: 2026-04-09T14:50:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
