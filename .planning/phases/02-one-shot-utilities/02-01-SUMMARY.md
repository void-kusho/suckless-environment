---
phase: 02-one-shot-utilities
plan: 01
subsystem: notifications
tags: [battery, sysfs, dunst, notify-send, state-file, one-shot]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: "pscanf, exec_detach, setup_sigchld in common/util.{c,h} and Makefile build system"
provides:
  - "battery-notify one-shot binary reading sysfs and sending dunst critical alerts"
  - "config.def.h/config.h compile-time configuration pattern for battery utility"
  - "State file duplicate notification prevention pattern"
affects: [02-02, 03-interactive-utilities]

# Tech tracking
tech-stack:
  added: []
  patterns: ["sysfs reading via pscanf with PATH_MAX-bounded snprintf paths", "state file for idempotent one-shot execution", "exec_detach notify-send for fire-and-forget notifications"]

key-files:
  created:
    - utils/battery-notify/battery-notify.c
    - utils/battery-notify/config.def.h
    - utils/battery-notify/config.h
  modified:
    - utils/Makefile

key-decisions:
  - "Used snprintf with PATH_MAX for sysfs path construction (safe, bounded)"
  - "Status scanf format '%15[a-zA-Z ]' handles 'Not charging' with spaces"

patterns-established:
  - "One-shot utility pattern: read sysfs, decide, notify, exit"
  - "State file pattern: access(F_OK) guard before notify, unlink on recovery"

requirements-completed: [BATT-01, BATT-02, BATT-03, BATT-04]

# Metrics
duration: 2min
completed: 2026-04-09
---

# Phase 02 Plan 01: Battery Notify Summary

**One-shot sysfs battery monitor with state-file dedup and exec_detach critical dunst notification**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-09T17:39:15Z
- **Completed:** 2026-04-09T17:41:18Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- battery-notify.c reads /sys/class/power_supply/BAT1/capacity and status via pscanf
- Sends critical dunst notification via exec_detach when battery <= 20% and discharging
- State file (/tmp/battery-notified) prevents duplicate alerts; cleared on recovery
- Full Makefile integration with clean/install/uninstall support

## Task Commits

Each task was committed atomically:

1. **Task 1: Create battery-notify config and source** - `3bc3ac6` (feat)
2. **Task 2: Add battery-notify to Makefile and verify build** - `ab61ebc` (feat)

## Files Created/Modified
- `utils/battery-notify/config.def.h` - Compile-time defaults: BATTERY, THRESHOLD, STATE_FILE
- `utils/battery-notify/config.h` - User copy of config.def.h (suckless pattern)
- `utils/battery-notify/battery-notify.c` - One-shot battery check with state file logic (~65 lines)
- `utils/Makefile` - Added BINS entry, compilation rules, clean target for battery-notify

## Decisions Made
- Used `%15[a-zA-Z ]` scanf format to handle "Not charging" status with embedded space (per slstatus battery.c reference pattern)
- State file uses simple fopen("w")+fclose for creation, unlink for removal -- minimal and correct for single-user desktop

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- battery-notify binary compiles, links, and runs cleanly
- Pattern established for screenshot-notify (Plan 02) which follows identical one-shot structure
- exec_detach + state file pattern validated against real sysfs reads

---
*Phase: 02-one-shot-utilities*
*Completed: 2026-04-09*
