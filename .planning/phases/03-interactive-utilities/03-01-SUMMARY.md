---
phase: 03-interactive-utilities
plan: 01
subsystem: interactive-utilities
tags: [dmenu, session-management, power-profiles, c-utility]
dependency_graph:
  requires: [01-01, 01-02]
  provides: [dmenu-session, dmenu-cpupower]
  affects: [install.sh, dwm-config]
tech_stack:
  added: [powerprofilesctl, betterlockscreen]
  patterns: [dmenu-pipe-api, confirmation-dialog, stdout-capture, fork-execvp]
key_files:
  created:
    - utils/dmenu-session/dmenu-session.c
    - utils/dmenu-cpupower/dmenu-cpupower.c
  modified:
    - utils/Makefile
decisions:
  - "pgrep -f (not -x) for betterlockscreen duplicate detection -- 16-char name exceeds 15-char comm field"
  - "exec_detach for systemctl reboot/poweroff -- these commands do not return"
  - "Kill order for logout: slstatus, dmenu-clipd, dunst, dwm (session leader last)"
  - "Whitelist validation for powerprofilesctl set input -- prevents command injection"
  - "No config.def.h for either utility -- no configurable values needed"
metrics:
  duration: "2 minutes"
  completed: "2026-04-09T19:06:43Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 1
---

# Phase 3 Plan 1: Session & Power Utilities Summary

Native C dmenu-session (lock/logout/reboot/shutdown with confirmations) and dmenu-cpupower (power profile switcher via powerprofilesctl) using Phase 1 dmenu pipe library.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create dmenu-session.c with lock/logout/reboot/shutdown actions | 89001d3 | utils/dmenu-session/dmenu-session.c |
| 2 | Create dmenu-cpupower.c and integrate both into Makefile | 3560c6c | utils/dmenu-cpupower/dmenu-cpupower.c, utils/Makefile |

## Implementation Details

### dmenu-session (130 lines)
- **4 actions:** logout, lock, reboot, shutdown presented via dmenu pipe API
- **confirm() helper:** Opens second dmenu with "no"/"yes" for destructive actions (logout, reboot, shutdown)
- **action_lock():** Validates DISPLAY env var, checks for duplicate via `pgrep -f betterlockscreen`, spawns with `exec_detach`
- **action_logout():** Kills daemons in correct order (slstatus, dmenu-clipd, dunst, dwm last as session leader)
- **action_reboot/shutdown():** Confirmation dialog then `exec_detach` (systemctl does not return)
- **argv forwarding:** Extra args passed through to all dmenu invocations

### dmenu-cpupower (98 lines)
- **capture_stdout() helper:** fork+pipe+dup2+execvp to read powerprofilesctl output
- **Prompt shows current profile:** "cpu: balanced" (or "cpu: unknown" on failure)
- **3 profiles:** performance, balanced, power-saver (hardcoded per powerprofilesctl)
- **Input validation:** Selection whitelist-checked before passing to `powerprofilesctl set`
- **argv forwarding:** Extra args passed through to dmenu

### Makefile Integration
- BINS extended with dmenu-session/dmenu-session and dmenu-cpupower/dmenu-cpupower
- Both link against common/util.o and common/dmenu.o (Phase 1 foundation)
- Clean target updated to remove .o files from both new subdirectories
- `make clean all` builds all 4 utilities (battery-notify, screenshot-notify, dmenu-session, dmenu-cpupower) with zero warnings

## Decisions Made

1. **pgrep -f over pgrep -x:** "betterlockscreen" is 16 characters, exceeding Linux's 15-char TASK_COMM_LEN. Using -f searches full cmdline instead.
2. **exec_detach for reboot/poweroff:** systemctl reboot/poweroff initiate system shutdown and never return, so exec_wait would hang.
3. **Logout kill order:** slstatus -> dmenu-clipd -> dunst -> dwm. dwm must die last as session leader -- its exit tears down the X session.
4. **Whitelist validation for powerprofilesctl:** Only "performance", "balanced", "power-saver" accepted. Prevents arbitrary user input from reaching exec args.
5. **No config.def.h:** Neither utility has configurable values worth extracting to config headers.

## Verification Results

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| make clean all | Zero warnings | Zero warnings | PASS |
| dmenu-session binary exists | Yes | Yes (14688 bytes) | PASS |
| dmenu-cpupower binary exists | Yes | Yes (14632 bytes) | PASS |
| confirm() count in dmenu-session | >= 4 | 4 | PASS |
| exec_detach count in dmenu-session | >= 2 | 5 | PASS |
| capture_stdout in dmenu-cpupower | Present | Present | PASS |
| powerprofilesctl (not cpupower) | Present | Present | PASS |

## Deviations from Plan

None -- plan executed exactly as written.

## Known Stubs

None -- both utilities are fully implemented with real data sources and actions wired.

## Security Notes

- No shell interpretation anywhere: all process spawning via fork+execvp (CERT C ENV33-C compliant)
- DISPLAY validation before spawning X11-dependent betterlockscreen
- pgrep -f duplicate prevention for lock screen
- Profile name whitelist prevents command injection via dmenu input to powerprofilesctl
- systemctl reboot/poweroff: no user-controlled arguments reach these commands

## Self-Check: PASSED

- [x] utils/dmenu-session/dmenu-session.c exists
- [x] utils/dmenu-cpupower/dmenu-cpupower.c exists
- [x] 03-01-SUMMARY.md exists
- [x] Commit 89001d3 exists
- [x] Commit 3560c6c exists
