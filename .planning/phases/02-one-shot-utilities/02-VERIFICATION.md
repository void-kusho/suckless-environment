---
phase: 02-one-shot-utilities
verified: 2026-04-09T18:10:00Z
status: human_needed
score: 5/5
overrides_applied: 0
human_verification:
  - test: "With battery below 20% and discharging, run battery-notify and verify dunst notification appears with 'Battery Low' / 'Battery at N%'"
    expected: "Critical dunst notification displayed"
    why_human: "Requires specific battery state and visual dunst confirmation"
  - test: "Run battery-notify a second time without clearing /tmp/battery-notified and verify NO duplicate notification appears"
    expected: "No notification; state file prevents re-alert"
    why_human: "Requires observing absence of notification with specific battery state"
  - test: "Run screenshot-notify, select a screen area, verify clipboard contains PNG and dunst shows 'Image copied to clipboard'"
    expected: "Area captured, clipboard has PNG, notification displayed"
    why_human: "Requires X11 display interaction (mouse selection) and visual clipboard/notification confirmation"
  - test: "Run screenshot-notify and press Escape during area selection; verify no notification and clean exit"
    expected: "No notification, exit code 0, silent"
    why_human: "Requires interactive X11 cancellation and observing absence of notification"
---

# Phase 2: One-Shot Utilities Verification Report

**Phase Goal:** Users receive battery low alerts and screenshot-copied notifications from native C binaries, validating the foundation's exec and sysfs patterns
**Verified:** 2026-04-09T18:10:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | When battery is at or below 20% and discharging, running battery-notify produces a dunst notification | VERIFIED | battery-notify.c:47 checks `cap <= THRESHOLD && strcmp(status, "Discharging") == 0`, then calls exec_detach with `notify-send -u critical "Battery Low" body` (lines 49-54). THRESHOLD=20 in config.h. |
| 2 | Running battery-notify a second time while still below threshold does NOT produce a duplicate notification (state file prevents re-alert) | VERIFIED | battery-notify.c:48 checks `access(STATE_FILE, F_OK) != 0` before notifying; state file created at lines 56-58 after first notification. Second run finds file exists, skips notification. |
| 3 | When battery rises above threshold or starts charging, the state file is cleared so future drops trigger a new alert | VERIFIED | battery-notify.c:60-61 `else` branch calls `unlink(STATE_FILE)`. The else fires when either `cap > THRESHOLD` or `status != "Discharging"`, covering both conditions. |
| 4 | Selecting a screen area with screenshot-notify captures it to clipboard and shows a dunst "Image copied to clipboard" notification | VERIFIED | screenshot-notify.c:10-55 implements two-child pipeline: child1=`maim -s` (line 27), child2=`xclip -selection clipboard -t image/png` (lines 39-40), piped via pipe(2). On success (WEXITSTATUS==0, line 54), exec_detach fires notify-send "Screenshot" "Image copied to clipboard" (lines 66-70). |
| 5 | Canceling the area selection (pressing Escape) produces no notification and exits cleanly | VERIFIED | screenshot-notify.c:54 returns 1 when `WEXITSTATUS != 0` (maim exits non-zero on cancel). Line 65 only calls exec_detach on success (==0). Line 73 `return 0` always -- clean exit regardless of cancel. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `utils/battery-notify/battery-notify.c` | One-shot battery check with state file logic and exec_detach notification | VERIFIED | 65 lines, contains pscanf calls (lines 20,25), exec_detach (line 54), state file logic (lines 47-62). No stubs, no TODOs. |
| `utils/battery-notify/config.def.h` | Compile-time defaults for BATTERY, THRESHOLD, STATE_FILE | VERIFIED | 10 lines, defines BATTERY="BAT1", THRESHOLD=20, STATE_FILE="/tmp/battery-notified". |
| `utils/battery-notify/config.h` | User copy of config.def.h | VERIFIED | Identical to config.def.h (suckless pattern). Contains THRESHOLD define. |
| `utils/screenshot-notify/screenshot-notify.c` | Two-child pipeline (maim pipe xclip) with exit code check and fire-and-forget notification | VERIFIED | 74 lines, contains capture_to_clipboard function (line 10), two-child fork+execlp pipeline, WIFEXITED+WEXITSTATUS check, exec_detach notification on success. No stubs, no TODOs. |
| `utils/Makefile` | Build rules for both battery-notify and screenshot-notify | VERIFIED | BINS line contains both binaries (line 11). Compilation rules at lines 22-34. Clean target handles both .o directories (lines 39-40). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| battery-notify.c | common/util.h | `#include "../common/util.h"` | WIRED | Line 7; calls pscanf, exec_detach, setup_sigchld, die -- all declared in util.h, implemented in util.c, linked via Makefile COMMON_OBJ |
| battery-notify.c | config.h | `#include "config.h"` | WIRED | Line 8; uses BATTERY, THRESHOLD, STATE_FILE defines from config.h |
| screenshot-notify.c | common/util.h | `#include "../common/util.h"` | WIRED | Line 7; calls die, exec_detach, setup_sigchld -- all declared in util.h |
| screenshot-notify.c | maim/xclip executables | fork+execlp in pipeline | WIRED | Lines 27 (execlp maim -s) and 39 (execlp xclip -selection clipboard -t image/png) |
| Makefile | battery-notify binary | BINS variable and rules | WIRED | Line 11 BINS includes battery-notify; lines 23-27 compilation rules with COMMON_OBJ linkage |
| Makefile | screenshot-notify binary | BINS variable and rules | WIRED | Line 11 BINS includes screenshot-notify; lines 30-34 compilation rules with COMMON_OBJ linkage |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Both utilities compile with zero warnings | `make -C utils clean all` | Clean build, zero warnings, both binaries produced | PASS |
| Existing tests still pass | `make -C utils test` | test-util: 10/10, test-dmenu: 11/11 | PASS |
| battery-notify binary is executable | `test -x utils/battery-notify/battery-notify` | True | PASS |
| screenshot-notify binary is executable | `test -x utils/screenshot-notify/screenshot-notify` | True | PASS |
| battery-notify runs without crash | `utils/battery-notify/battery-notify` | Exit code 0 | PASS |
| screenshot-notify interactive test | Skipped | Requires X11 display interaction | SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-----------|-------------|--------|----------|
| BATT-01 | 02-01 | One-shot read of /sys/class/power_supply/BAT1/ for capacity and status | SATISFIED | pscanf reads CAP_PATH and STAT_PATH with BATTERY="BAT1" (battery-notify.c:18-26) |
| BATT-02 | 02-01 | Sends dunst notification when capacity <=20% and status is Discharging | SATISFIED | exec_detach with notify-send -u critical when cap<=THRESHOLD and Discharging (battery-notify.c:47-54) |
| BATT-03 | 02-01 | Uses state file (/tmp/battery-notified) to prevent re-alert spam | SATISFIED | access(STATE_FILE, F_OK) guard before notify; fopen to create state file (battery-notify.c:48,56-58) |
| BATT-04 | 02-01 | Clears state file when battery rises above threshold or starts charging | SATISFIED | unlink(STATE_FILE) in else branch (battery-notify.c:61) |
| SCRN-01 | 02-02 | Captures selected area via maim -s piped to xclip -selection clipboard -t image/png | SATISFIED | Two-child pipeline: child1 execlp("maim","maim","-s"), child2 execlp("xclip",..."-t","image/png") (screenshot-notify.c:16-55) |
| SCRN-02 | 02-02 | Sends dunst notification "Image copied to clipboard" on successful capture | SATISFIED | exec_detach with notify-send "Screenshot" "Image copied to clipboard" on success (screenshot-notify.c:65-70) |
| SCRN-03 | 02-02 | Exits silently when user cancels selection (no false notification) | SATISFIED | WEXITSTATUS check returns 1 on cancel; notification only on ==0; main returns 0 always (screenshot-notify.c:54,65,73) |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | - | - | - | No TODO, FIXME, placeholder, stub, or empty return patterns found in any phase artifact |

### Human Verification Required

### 1. Battery Low Notification Display

**Test:** With battery below 20% and discharging, run `utils/battery-notify/battery-notify` and check dunst for "Battery Low" / "Battery at N%" notification.
**Expected:** Critical dunst notification appears with correct battery percentage.
**Why human:** Requires specific battery state (below 20%, discharging) and visual confirmation of dunst rendering.

### 2. Duplicate Notification Prevention

**Test:** While state file exists (`/tmp/battery-notified`), run battery-notify again with battery still low.
**Expected:** No second notification appears.
**Why human:** Requires observing the absence of a notification, which cannot be verified programmatically.

### 3. Screenshot Capture and Notification

**Test:** Run `utils/screenshot-notify/screenshot-notify`, select a screen area with the mouse, then check clipboard (paste into image viewer) and dunst.
**Expected:** Selected area captured as PNG in clipboard; dunst shows "Screenshot" / "Image copied to clipboard".
**Why human:** Requires X11 mouse interaction for area selection and visual confirmation of clipboard contents and notification.

### 4. Screenshot Cancel Behavior

**Test:** Run `utils/screenshot-notify/screenshot-notify` and press Escape during area selection.
**Expected:** No notification, no error output, exit code 0.
**Why human:** Requires interactive X11 cancellation (keyboard input during maim selection).

### Gaps Summary

No automated gaps found. All 5 observable truths verified through code analysis and build verification. All 7 requirements (BATT-01 through BATT-04, SCRN-01 through SCRN-03) satisfied with implementation evidence. All key links wired and confirmed through compilation. No anti-patterns detected.

Status is **human_needed** because 4 items require interactive X11 testing that cannot be performed programmatically (notification display, duplicate prevention, screenshot capture, cancel behavior).

---

_Verified: 2026-04-09T18:10:00Z_
_Verifier: Claude (gsd-verifier)_
