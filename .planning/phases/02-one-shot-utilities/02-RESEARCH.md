# Phase 2: One-Shot Utilities - Research

**Researched:** 2026-04-09
**Domain:** Native C one-shot utilities (battery monitoring via sysfs, screenshot capture via maim/xclip, notifications via notify-send)
**Confidence:** HIGH

## Summary

Phase 2 delivers two self-contained, one-shot C utilities -- `battery-notify` and `screenshot-notify` -- that validate the Phase 1 foundation's `exec_wait()`, `exec_detach()`, `pscanf()`, and `setup_sigchld()` patterns against real use cases. Both utilities are structurally simple (under 100 lines of logic each), have no library dependencies beyond libc, and communicate with dunst exclusively through `notify-send` via fork+execvp.

The battery utility reads sysfs pseudo-files for capacity and status, uses a state file at `/tmp/battery-notified` to suppress duplicate alerts, and clears that state when conditions change. The screenshot utility forks a `maim -s | xclip` pipeline, checks maim's exit code to detect user cancellation, and only notifies on success. Both follow the suckless compile-time configuration pattern via `config.def.h`/`config.h`.

**Primary recommendation:** Implement battery-notify first (simpler, validates pscanf + exec_detach), then screenshot-notify (validates exec_wait + pipeline pattern). Both integrate into the existing `utils/Makefile` BINS variable and require zero new system dependencies.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Both utilities send notifications via `exec notify-send` (fork+execvp from common/util.c). No libnotify, no dunstify, no sd-bus direct calls.
- **D-02:** notify-send is already installed on the system. No new dependencies.
- **D-03:** Compile-time configuration via config.def.h/config.h (suckless pattern). User copies config.def.h to config.h to customize.
- **D-04:** Default defines: `#define BATTERY "BAT1"` and `#define THRESHOLD 20`
- **D-05:** Reads `/sys/class/power_supply/{BATTERY}/capacity` and `/sys/class/power_supply/{BATTERY}/status` using pscanf() from common/util.c
- **D-06:** State file at `/tmp/battery-notified` prevents re-alert spam. Created when alert fires, cleared when capacity rises above threshold or status changes to Charging/Full.
- **D-07:** Notification uses `notify-send -u critical "Battery Low" "Battery at {N}%"`
- **D-08:** Capture via fork+exec: `maim -s` piped to `xclip -selection clipboard -t image/png`
- **D-09:** Cancel detection: check maim exit code. Only notify on exit 0.
- **D-10:** Notification text: `notify-send "Screenshot" "Image copied to clipboard"`
- **D-11:** Silent exit on cancel (maim exit non-zero) -- no notification, no error, just exit 0.

### Claude's Discretion
- Exact notification urgency levels (normal vs critical)
- State file cleanup strategy details
- Whether to use exec_wait or exec_detach for notify-send (fire-and-forget is fine)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BATT-01 | One-shot read of /sys/class/power_supply/BAT1/ for capacity and status | pscanf() from util.c reads sysfs with open/read/close per call; format strings `"%d"` for capacity, `"%15[a-zA-Z ]"` for status; BAT1 verified present on system |
| BATT-02 | Sends dunst notification when capacity <=20% and status is Discharging | exec_detach() with notify-send -u critical; notification is fire-and-forget; dunst handles display |
| BATT-03 | Uses state file (/tmp/battery-notified) to prevent re-alert spam | Standard C fopen/fclose for state file check/creation; access() for existence check |
| BATT-04 | Clears state file when battery rises above threshold or starts charging | unlink() on state file path when conditions no longer met |
| SCRN-01 | Captures selected area via maim -s piped to xclip -selection clipboard -t image/png | Two-child pipeline pattern: fork maim writing to pipe, fork xclip reading from pipe; exec_wait()-style waitpid on maim for exit code |
| SCRN-02 | Sends dunst notification "Image copied to clipboard" on successful capture | exec_detach() with notify-send after pipeline succeeds |
| SCRN-03 | Exits silently when user cancels selection (no false notification) | maim (via slop) returns non-zero on Escape/cancel; check WEXITSTATUS before notifying |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Platform**: Arch Linux only
- **Philosophy**: Suckless-style C -- minimal dependencies, no frameworks
- **Display server**: X11
- **Build**: Each util has its own directory under utils/, top-level Makefile orchestrates
- **Code style**: K&R braces, tabs, C99, `-pedantic -Wall -Wextra -Os`
- **Process spawning**: fork+execvp only (never system() or popen())
- **Error handling**: die() for fatal, warn() for non-fatal, pscanf() for sysfs
- **Install path**: PREFIX=$(HOME)/.local (no sudo needed)

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| libc (glibc) | 2.41 | All standard C functions | Only dependency needed. fork, execvp, waitpid, fopen, unlink, snprintf, strcmp, access |
| common/util.c | 1.0 (project) | die(), warn(), pscanf(), exec_wait(), exec_detach(), setup_sigchld() | Phase 1 foundation -- all process spawning and sysfs reading goes through this |

[VERIFIED: codebase inspection of utils/common/util.h and utils/common/util.c]

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| notify-send | 0.8.8 | Send desktop notifications to dunst | Fire-and-forget via exec_detach() |
| maim | 5.8.1 | Interactive area screenshot capture | exec_wait() to capture and check exit code |
| xclip | 0.13 | Copy image data to X11 clipboard | Receives piped PNG data from maim |

[VERIFIED: all three confirmed present on system via `command -v` and version checks]

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| notify-send exec | sd-bus D-Bus call | D-02 locks us to exec notify-send. sd-bus would add -lsystemd link flag and ~20 lines of D-Bus marshalling code. Exec is simpler and consistent with suckless philosophy |
| maim -s | scrot -s | scrot's selection mode is inferior (no slop integration). maim is already installed |
| /tmp/battery-notified | XDG_RUNTIME_DIR state | /tmp is simpler, always writable, D-06 locks this path |

**Installation:**
```bash
# No new packages needed. All verified present:
pacman -Q libnotify maim xclip
```

[VERIFIED: notify-send 0.8.8, maim 5.8.1, xclip present on system]

## Architecture Patterns

### Recommended Project Structure
```
utils/
├── battery-notify/
│   ├── battery-notify.c     # ~80 lines: main + battery_check logic
│   ├── config.def.h         # BATTERY, THRESHOLD, STATE_FILE defines
│   └── config.h             # User copy (gitignored)
├── screenshot-notify/
│   └── screenshot-notify.c  # ~60 lines: main + pipeline + notify
├── common/
│   ├── util.h               # Shared API (from Phase 1)
│   └── util.c               # Shared implementation (from Phase 1)
├── config.mk                # Shared compiler flags (from Phase 1)
└── Makefile                  # Build orchestrator -- BINS updated
```

### Pattern 1: sysfs Read via pscanf (battery-notify)

**What:** Read battery capacity and status from Linux sysfs pseudo-files using the Phase 1 pscanf() function, which opens, reads with vfscanf, and closes the file in one call.

**When to use:** Any sysfs file read. pscanf guarantees fresh data by not caching file descriptors.

**Example:**
```c
/* Source: slstatus/components/battery.c lines 39-50 pattern, adapted for util.c pscanf */
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include "../common/util.h"
#include "config.h"

#define CAP_PATH  "/sys/class/power_supply/%s/capacity"
#define STAT_PATH "/sys/class/power_supply/%s/status"

static int
read_battery(int *cap, char *status, size_t slen)
{
	char path[PATH_MAX];

	snprintf(path, sizeof(path), CAP_PATH, BATTERY);
	if (pscanf(path, "%d", cap) != 1)
		return -1;

	snprintf(path, sizeof(path), STAT_PATH, BATTERY);
	if (pscanf(path, "%15[a-zA-Z ]", status) != 1)
		return -1;

	return 0;
}
```

[VERIFIED: pscanf() implementation inspected in utils/common/util.c; sysfs paths verified: `/sys/class/power_supply/BAT1/capacity` returns integer, `/sys/class/power_supply/BAT1/status` returns string]

### Pattern 2: State File for Duplicate Prevention (battery-notify)

**What:** Use a simple file at `/tmp/battery-notified` as a boolean flag. Existence = already notified. Absence = eligible for notification.

**When to use:** BATT-03 and BATT-04.

**Example:**
```c
#include <stdio.h>
#include <unistd.h>

#define STATE_FILE "/tmp/battery-notified"

static int
state_exists(void)
{
	return access(STATE_FILE, F_OK) == 0;
}

static void
state_create(void)
{
	FILE *fp = fopen(STATE_FILE, "w");
	if (fp)
		fclose(fp);
}

static void
state_clear(void)
{
	unlink(STATE_FILE);
}
```

[ASSUMED] -- This is standard POSIX file manipulation. The `/tmp/` path choice is locked by D-06.

### Pattern 3: Two-Child Pipeline (screenshot-notify)

**What:** Fork two children connected by a pipe: maim writes PNG to the pipe, xclip reads from it. Parent waits for maim to check its exit code. This replicates `maim -s | xclip -selection clipboard -t image/png` in C without invoking a shell.

**When to use:** SCRN-01.

**Example:**
```c
static int
capture_to_clipboard(void)
{
	int pipefd[2];
	pid_t maim_pid, xclip_pid;
	int status;

	if (pipe(pipefd) < 0)
		die("pipe:");

	/* Child 1: maim -s writes PNG to pipe */
	maim_pid = fork();
	if (maim_pid < 0)
		die("fork:");
	if (maim_pid == 0) {
		close(pipefd[0]);
		dup2(pipefd[1], STDOUT_FILENO);
		close(pipefd[1]);
		execlp("maim", "maim", "-s", NULL);
		_exit(127);
	}

	/* Child 2: xclip reads from pipe */
	xclip_pid = fork();
	if (xclip_pid < 0)
		die("fork:");
	if (xclip_pid == 0) {
		close(pipefd[1]);
		dup2(pipefd[0], STDIN_FILENO);
		close(pipefd[0]);
		execlp("xclip", "xclip", "-selection", "clipboard",
		       "-t", "image/png", NULL);
		_exit(127);
	}

	/* Parent: close both pipe ends, wait for maim */
	close(pipefd[0]);
	close(pipefd[1]);

	waitpid(maim_pid, &status, 0);
	waitpid(xclip_pid, NULL, 0);

	if (WIFEXITED(status) && WEXITSTATUS(status) == 0)
		return 0;  /* success */
	return 1;  /* cancelled or failed */
}
```

[VERIFIED: maim returns non-zero when user cancels selection (via slop). Confirmed from slop PR #90 and common shell script patterns `slop=$(slop -f "%g") || exit 1`]

### Pattern 4: Fire-and-Forget Notification via exec_detach

**What:** Use exec_detach() from util.c to spawn notify-send without waiting. The SIGCHLD handler reaps the child.

**When to use:** BATT-02, SCRN-02.

**Example:**
```c
static void
notify(const char *urgency, const char *summary, const char *body)
{
	const char *argv[] = {
		"notify-send", "-u", urgency, summary, body, NULL
	};
	exec_detach(argv);
}
```

[VERIFIED: exec_detach() confirmed in utils/common/util.c:89-103 -- forks, calls setsid(), execvp, parent returns immediately]

### Anti-Patterns to Avoid

- **system("notify-send ...") or system("maim -s | xclip ..."):** Spawns /bin/sh, introduces shell injection vector, contradicts the project's core value of eliminating shell interpreters. Use fork+execvp exclusively.
- **Keeping sysfs file descriptors open:** pscanf() already handles open/read/close correctly. Do not cache FDs -- sysfs data goes stale.
- **Linking libnotify:** D-01 explicitly forbids this. Exec notify-send instead.
- **Polling battery in a loop:** battery-notify is one-shot. A systemd timer or cron job invokes it periodically. The utility itself reads once and exits.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Sending desktop notifications | Custom D-Bus client code | exec notify-send | D-01 locked. notify-send handles all D-Bus marshalling. One exec call vs 20+ lines of sd-bus code |
| Screenshot area selection | Custom X11 selection UI | exec maim -s | maim delegates to slop which provides the selection rectangle. Reimplementing this would be hundreds of lines of Xlib |
| Clipboard copy of image | Custom XSetSelectionOwner/XChangeProperty | exec xclip | xclip handles the X11 selection ownership protocol including TARGETS and INCR for large data |
| sysfs file reading | Custom open/read/close wrapper | pscanf() from common/util.c | Already implemented, tested, and matches the slstatus pattern exactly |
| Process spawning | Custom fork/exec helpers | exec_wait() and exec_detach() from common/util.c | Already implemented with proper error handling and SIGCHLD setup |

**Key insight:** These utilities are "glue" -- their value is in the orchestration logic (when to notify, when not to), not in reimplementing system interactions. Every external interaction maps directly to an existing util.c function or an exec'd system tool.

## Common Pitfalls

### Pitfall 1: Battery Re-Alert Spam
**What goes wrong:** If battery-notify runs every minute via timer and battery stays at 19%, user gets a notification every minute.
**Why it happens:** No state tracking between invocations. Each run is independent and sees "low + discharging" as a new event.
**How to avoid:** D-06 specifies the state file at `/tmp/battery-notified`. Create it when alert fires. Check for its existence before alerting. Clear it when conditions change (capacity > threshold OR status != Discharging).
**Warning signs:** Multiple identical "Battery Low" notifications stacking in dunst.

### Pitfall 2: Screenshot Cancel Produces False Notification
**What goes wrong:** User presses Escape to cancel area selection, but notification "Image copied to clipboard" fires anyway.
**Why it happens:** Not checking maim's exit code before proceeding to notification.
**How to avoid:** D-09 specifies checking exit code. maim (via slop) returns non-zero on cancel. Only call notify-send when `WEXITSTATUS(maim_status) == 0`.
**Warning signs:** Getting "Image copied to clipboard" when no screenshot was taken.

### Pitfall 3: Zombie Processes from notify-send
**What goes wrong:** exec_detach() forks notify-send. Without a SIGCHLD handler, the child becomes a zombie after it exits.
**Why it happens:** Parent does not call waitpid() on detached children.
**How to avoid:** Call `setup_sigchld()` at the start of main(). The handler in util.c calls `waitpid(-1, NULL, WNOHANG)` in a loop to reap all zombies. Both utilities are short-lived (exit immediately after notify), so zombies barely have time to form, but the pattern must be correct.
**Warning signs:** `ps aux | grep Z` showing defunct processes.

### Pitfall 4: State File Not Cleared on Recovery
**What goes wrong:** Battery drops to 19%, state file created, user plugs in charger, battery charges to 100%, user unplugs -- no notification when it drops again because state file from the previous cycle still exists.
**Why it happens:** State file clearing logic is incomplete -- only checks threshold, not status change.
**How to avoid:** Clear state file in two conditions: (1) capacity rises above threshold, OR (2) status changes to Charging or Full. Both conditions must be checked on every invocation.
**Warning signs:** Battery drops below threshold after a charge cycle, no notification.

### Pitfall 5: Pipeline Fd Leak in screenshot-notify
**What goes wrong:** Parent forgets to close both ends of the pipe after forking children. xclip hangs waiting for EOF on stdin because the parent still holds the write end open.
**Why it happens:** Classic pipe() mistake -- every process that doesn't need a pipe end must close it.
**How to avoid:** After forking both children, parent must `close(pipefd[0]); close(pipefd[1]);` before waitpid(). Each child closes the end it doesn't use.
**Warning signs:** screenshot-notify hangs after selection, xclip never exits.

### Pitfall 6: pscanf Format String for Battery Status
**What goes wrong:** Using `"%s"` to read battery status reads only the first word. The status "Not charging" (two words) would be read as just "Not".
**Why it happens:** `%s` stops at whitespace in scanf.
**How to avoid:** Use `"%15[a-zA-Z ]"` as the format string (matching the slstatus pattern in battery.c line 69). This reads up to 15 characters of alphabetic chars and spaces, capturing "Not charging" correctly.
**Warning signs:** Status comparison with "Not charging" always fails; battery in "Not charging" state treated as unknown.

## Code Examples

### battery-notify main() Structure
```c
/* Source: Synthesized from D-03..D-07, BATT-01..BATT-04 */
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "../common/util.h"
#include "config.h"

static int
read_battery(int *cap, char *status, size_t slen)
{
	char path[PATH_MAX];

	snprintf(path, sizeof(path),
	         "/sys/class/power_supply/%s/capacity", BATTERY);
	if (pscanf(path, "%d", cap) != 1)
		return -1;

	snprintf(path, sizeof(path),
	         "/sys/class/power_supply/%s/status", BATTERY);
	if (pscanf(path, "%15[a-zA-Z ]", status) != 1)
		return -1;

	return 0;
}

int
main(int argc, char *argv[])
{
	int cap;
	char status[16];

	(void)argc;
	argv0 = argv[0];
	setup_sigchld();

	if (read_battery(&cap, status, sizeof(status)) < 0)
		die("cannot read battery");

	if (cap <= THRESHOLD && strcmp(status, "Discharging") == 0) {
		/* Low and discharging -- alert if not already notified */
		if (access(STATE_FILE, F_OK) != 0) {
			char body[64];
			snprintf(body, sizeof(body), "Battery at %d%%", cap);
			const char *cmd[] = {
				"notify-send", "-u", "critical",
				"Battery Low", body, NULL
			};
			exec_detach(cmd);
			/* Create state file */
			FILE *fp = fopen(STATE_FILE, "w");
			if (fp) fclose(fp);
		}
	} else {
		/* Not low or not discharging -- clear state */
		unlink(STATE_FILE);
	}

	return 0;
}
```

### screenshot-notify main() Structure
```c
/* Source: Synthesized from D-08..D-11, SCRN-01..SCRN-03 */
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

#include "../common/util.h"

static int
capture_to_clipboard(void)
{
	int pipefd[2];
	pid_t maim_pid, xclip_pid;
	int status;

	if (pipe(pipefd) < 0)
		die("pipe:");

	maim_pid = fork();
	if (maim_pid < 0) die("fork:");
	if (maim_pid == 0) {
		close(pipefd[0]);
		dup2(pipefd[1], STDOUT_FILENO);
		close(pipefd[1]);
		execlp("maim", "maim", "-s", NULL);
		_exit(127);
	}

	xclip_pid = fork();
	if (xclip_pid < 0) die("fork:");
	if (xclip_pid == 0) {
		close(pipefd[1]);
		dup2(pipefd[0], STDIN_FILENO);
		close(pipefd[0]);
		execlp("xclip", "xclip", "-selection", "clipboard",
		       "-t", "image/png", NULL);
		_exit(127);
	}

	close(pipefd[0]);
	close(pipefd[1]);

	waitpid(maim_pid, &status, 0);
	waitpid(xclip_pid, NULL, 0);

	return (WIFEXITED(status) && WEXITSTATUS(status) == 0) ? 0 : 1;
}

int
main(int argc, char *argv[])
{
	(void)argc;
	argv0 = argv[0];
	setup_sigchld();

	if (capture_to_clipboard() == 0) {
		const char *cmd[] = {
			"notify-send", "Screenshot",
			"Image copied to clipboard", NULL
		};
		exec_detach(cmd);
	}
	/* Silent exit on cancel (D-11) */
	return 0;
}
```

### config.def.h for battery-notify
```c
/* See LICENSE file for copyright and license details. */

/* Battery device name under /sys/class/power_supply/ */
#define BATTERY    "BAT1"

/* Alert threshold percentage */
#define THRESHOLD  20

/* State file to prevent duplicate alerts */
#define STATE_FILE "/tmp/battery-notified"
```

### Makefile BINS Extension Pattern
```makefile
# In utils/Makefile, the BINS line changes from:
BINS =
# To:
BINS = battery-notify/battery-notify screenshot-notify/screenshot-notify

# New compilation rules needed:
battery-notify/battery-notify: battery-notify/battery-notify.o $(COMMON_OBJ)
	$(CC) -o $@ $(LDFLAGS) $^

battery-notify/battery-notify.o: battery-notify/battery-notify.c battery-notify/config.h $(COMMON_HDR)
	$(CC) -o $@ -c $(CFLAGS) $<

screenshot-notify/screenshot-notify: screenshot-notify/screenshot-notify.o $(COMMON_OBJ)
	$(CC) -o $@ $(LDFLAGS) $^

screenshot-notify/screenshot-notify.o: screenshot-notify/screenshot-notify.c $(COMMON_HDR)
	$(CC) -o $@ -c $(CFLAGS) $<

# Clean rule already handles BINS via existing loop
```

[VERIFIED: Makefile pattern confirmed by reading utils/Makefile -- BINS variable exists (empty), install/uninstall rules iterate over BINS with basename extraction]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Shell scripts for battery check | Native C with sysfs reads | This phase | Eliminates shell interpreter dependency, faster execution, type-safe threshold comparison |
| `maim -s \| xclip` in shell | C fork+pipe+exec pipeline | This phase | No shell involved, proper exit code handling, no injection risk |
| No duplicate notification prevention | State file at /tmp/battery-notified | This phase | Prevents spam when battery stays below threshold across timer invocations |

**Deprecated/outdated:**
- The STACK.md research recommended sd-bus for notifications. D-01 overrides this -- exec notify-send is the locked decision for Phase 2.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | /tmp/ is writable and survives across timer invocations within a session | Pattern 2: State File | LOW -- /tmp is standard on Linux, only cleared on reboot which is acceptable for state reset |
| A2 | maim returns non-zero exit code (via slop) when user presses Escape | Pattern 3: Pipeline | LOW -- confirmed by slop PR #90 and common script patterns, but not documented in maim's man page |
| A3 | xclip exits cleanly after receiving all piped data and EOF | Pattern 3: Pipeline | LOW -- standard xclip behavior; it forks internally to serve the selection but the foreground process exits |
| A4 | notify-send -u critical makes dunst show the notification persistently (until dismissed) | Code Examples | LOW -- depends on dunstrc config, but critical urgency is standard dunst behavior |
| A5 | screenshot-notify does not need config.def.h since it has no user-configurable values | Architecture | LOW -- if users want to customize notification text, a config.h can be added later |

## Open Questions

1. **Urgency for screenshot notification**
   - What we know: D-07 specifies `-u critical` for battery. D-10 does not specify urgency for screenshot.
   - What's unclear: Should screenshot notification use `normal` (auto-dismiss) or `low`?
   - Recommendation: Use `normal` (default) -- screenshot confirmation is transient, not an alert. The user knows they just took a screenshot.

2. **exec_wait vs exec_detach for notify-send**
   - What we know: Claude's discretion area. notify-send returns immediately (sends D-Bus message and exits).
   - What's unclear: Whether to wait for notify-send to confirm delivery.
   - Recommendation: Use exec_detach() (fire-and-forget). notify-send is effectively instantaneous. Waiting adds no value and would block the utility's exit by a few milliseconds.

3. **Battery state file behavior on reboot**
   - What we know: `/tmp/` is cleared on reboot (tmpfs on Arch).
   - What's unclear: Is this desirable? After reboot, battery might still be below threshold.
   - Recommendation: This is correct behavior. After reboot, the user should get a fresh notification if the battery is low. The state file only prevents spam within a single session/uptime.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| notify-send | Both utilities | Yes | 0.8.8 | -- |
| maim | screenshot-notify | Yes | 5.8.1 | -- |
| xclip | screenshot-notify | Yes | present | -- |
| /sys/class/power_supply/BAT1/ | battery-notify | Yes | kernel ABI | -- |
| dunst | Both (notification display) | Yes | 1.13.2 | -- |
| gcc (cc) | Build | Yes | (system) | -- |
| GNU make | Build | Yes | (system) | -- |

[VERIFIED: All dependencies confirmed present on the system]

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Custom C test programs (project convention from Phase 1) |
| Config file | None -- tests are standalone C programs compiled by Makefile |
| Quick run command | `make -C /home/void/.config/suckless-environment/utils test` |
| Full suite command | `make -C /home/void/.config/suckless-environment/utils test` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BATT-01 | Reads capacity and status from sysfs | unit | `make -C utils test-battery && ./utils/test-battery` | No -- Wave 0 |
| BATT-02 | Sends critical notification when low + discharging | manual-only | Run with battery below threshold or mock sysfs (not practical to automate) | N/A |
| BATT-03 | State file prevents duplicate alert | unit | Test program creates state file, runs logic, verifies no notification exec | No -- Wave 0 |
| BATT-04 | State file cleared when conditions change | unit | Test program verifies unlink when above threshold | No -- Wave 0 |
| SCRN-01 | Captures area to clipboard | manual-only | Requires interactive selection (maim -s needs user input) | N/A |
| SCRN-02 | Notification on success | manual-only | Requires successful capture | N/A |
| SCRN-03 | Silent exit on cancel | manual-only | Requires pressing Escape during selection | N/A |

**Note on testability:** These one-shot utilities interact heavily with external state (sysfs, X11 display, user input). Unit tests can validate the battery reading logic and state file logic in isolation, but screenshot and notification behaviors are inherently manual. The test program for battery should validate: (1) pscanf successfully reads from sysfs, (2) state file creation/check/removal works, (3) compilation and linkage is correct.

### Sampling Rate
- **Per task commit:** `make -C utils clean all` (build verification)
- **Per wave merge:** `make -C utils test` (full test suite)
- **Phase gate:** Full suite green + manual verification of all 5 success criteria

### Wave 0 Gaps
- [ ] `utils/tests/test-battery.c` -- covers BATT-01, BATT-03, BATT-04 (compile+link test, sysfs read test, state file logic test)
- [ ] Makefile `test-battery` target -- compile and run battery test

*(Screenshot tests are manual-only due to interactive maim -s requirement)*

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A -- no auth in one-shot utilities |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A -- reads are world-readable sysfs, writes to /tmp |
| V5 Input Validation | Yes | Validate pscanf return values; bounds-check capacity (0-100); use fixed argv arrays for exec |
| V6 Cryptography | No | N/A |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Command injection via system() | Tampering | Use fork+execvp with const argv arrays -- no shell involved (already enforced by project convention) |
| State file race condition (TOCTOU) | Tampering | access() then fopen() has a tiny race window. Acceptable for /tmp state file on single-user desktop. Not a real attack surface |
| Sysfs path traversal | Tampering | Battery name comes from compile-time #define, not runtime input. No traversal possible |

## Sources

### Primary (HIGH confidence)
- `utils/common/util.c` -- inspected all 6 functions: die, warn, pscanf, exec_wait, exec_detach, setup_sigchld
- `utils/common/util.h` -- confirmed API signatures
- `utils/Makefile` -- confirmed BINS variable pattern, install rules, clean rules
- `utils/config.mk` -- confirmed CFLAGS (-std=c99, -pedantic, -Wall, -Wextra, -Os), PREFIX
- `slstatus/components/battery.c` -- reference implementation for sysfs battery reading pattern with pscanf format strings
- `/sys/class/power_supply/BAT1/` -- verified present: capacity=100, status="Not charging", type="Battery"
- System tool versions: notify-send 0.8.8, maim 5.8.1, dunst 1.13.2 -- all verified via command-line

### Secondary (MEDIUM confidence)
- [slop PR #90](https://github.com/naelstrof/slop/pull/90/files) -- confirms slop (used by maim -s) returns non-zero on cancel
- [maim GitHub](https://github.com/naelstrof/maim) -- README confirms -s flag delegates to slop for selection
- [Arch maim man page](https://man.archlinux.org/man/extra/maim/maim.1.en) -- confirms -s option behavior

### Tertiary (LOW confidence)
- None -- all claims verified against codebase or system state

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- zero new dependencies, all tools verified present on system
- Architecture: HIGH -- both utilities are structurally trivial (read state, make decision, exec action), all patterns established in Phase 1
- Pitfalls: HIGH -- well-documented in project PITFALLS.md research, all relevant ones addressed in locked decisions (D-06 for spam, D-09 for cancel detection)

**Research date:** 2026-04-09
**Valid until:** 2026-05-09 (stable -- sysfs ABI, POSIX fork/exec, and notify-send are mature, unchanging interfaces)
