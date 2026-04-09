---
phase: 02-one-shot-utilities
plan: 02
subsystem: screenshots
tags: [screenshot, maim, xclip, pipe, dunst, notify-send, one-shot]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: "exec_detach, setup_sigchld, die in common/util.{c,h}"
  - plan: 02-01
    provides: "Makefile build system with BINS pattern and battery-notify rules"
provides:
  - "screenshot-notify one-shot binary with maim|xclip two-child pipeline"
  - "Cancel detection via maim exit code with silent exit"
  - "Fire-and-forget dunst notification on successful capture"
affects: [03-interactive-utilities]

# Tech tracking
tech-stack:
  added: []
  patterns: ["two-child fork+execlp pipeline with pipe(2)", "parent closes both pipe ends before waitpid to prevent hang", "WIFEXITED+WEXITSTATUS exit code checking for cancel detection"]

key-files:
  created:
    - utils/screenshot-notify/screenshot-notify.c
  modified:
    - utils/Makefile

key-decisions:
  - "No config.h for screenshot-notify -- no user-configurable values (hardcoded maim/xclip/notify-send args)"
  - "Default urgency for notify-send (no -u flag) -- screenshot is informational, not critical"

patterns-established:
  - "Two-child pipeline pattern: pipe(2) + fork twice + parent closes both ends + waitpid both children"
  - "Cancel detection pattern: check maim WEXITSTATUS to distinguish success from user escape"

requirements-completed: [SCRN-01, SCRN-02, SCRN-03]

# Metrics
duration: 2min
completed: 2026-04-09
---

# Phase 02 Plan 02: Screenshot Notify Summary

**Two-child maim|xclip pipeline with cancel detection and fire-and-forget dunst notification**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-09T17:43:47Z
- **Completed:** 2026-04-09T17:45:12Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- screenshot-notify.c implements a pure fork+execlp two-child pipeline (no shell invocation)
- Child 1 runs `maim -s` writing PNG to pipe stdout; Child 2 runs `xclip -selection clipboard -t image/png` reading from pipe stdin
- Parent closes both pipe ends immediately after forking both children, preventing xclip hang (T-02-07 mitigated)
- Cancel detection: checks maim exit code via WIFEXITED && WEXITSTATUS == 0 (SCRN-03)
- Success notification via exec_detach with notify-send "Screenshot" "Image copied to clipboard" (SCRN-02)
- Silent exit 0 on cancel -- no notification, no error output (SCRN-03)
- setup_sigchld() called for zombie prevention (T-02-08 mitigated)
- All exec arguments are compile-time string literals (T-02-06 mitigated)
- Makefile updated: BINS includes both battery-notify and screenshot-notify
- Full build pipeline verified: clean, all, test, install all pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Create screenshot-notify source** - `5d47ce1` (feat)
2. **Task 2: Add screenshot-notify to Makefile and verify full build** - `ffc6b6c` (feat)

## Files Created/Modified

- `utils/screenshot-notify/screenshot-notify.c` - Two-child pipeline with cancel detection (~74 lines)
- `utils/Makefile` - Added screenshot-notify to BINS, compilation rules, clean target

## Decisions Made

- No config.h needed for screenshot-notify -- all values (binary names, args, notification text) are fixed and not user-configurable
- Used default urgency for notify-send (no -u flag) since screenshot is informational, not critical like battery alerts

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - requires maim and xclip to be installed (already listed as project dependencies in CLAUDE.md).

## Threat Mitigations Verified

| Threat ID | Mitigation | Status |
|-----------|-----------|--------|
| T-02-06 | All argv arrays are const string literals | Verified in source |
| T-02-07 | Parent closes both pipe ends before waitpid | Verified in source |
| T-02-08 | setup_sigchld + explicit waitpid for both children | Verified in source |
| T-02-09 | Accepted -- in-process pipe, no network | N/A |

## Next Phase Readiness

- Both one-shot utilities (battery-notify, screenshot-notify) compile, link, and install cleanly
- Phase 2 complete -- all one-shot utilities delivered
- Foundation patterns (exec_detach, setup_sigchld, die) validated against two distinct use cases
- Build system scales: adding new utilities follows established BINS + rules + clean pattern

---
*Phase: 02-one-shot-utilities*
*Completed: 2026-04-09*
