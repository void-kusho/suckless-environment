---
phase: 02-battery-brightness-utilities
plan: 01
subsystem: battery-notify
tags: [battery, notifications, dunst, state-machine]
dependency_graph:
  requires: []
  provides: [battery-notify]
  affects: [dwm-start]
tech_stack:
  - C99 with POSIX (glob, pscanf)
  - dunst notifications via notify-send
  - Tiered urgency with replace-id
key_files:
  created: []
  modified:
    - utils/battery-notify/battery-notify.c
    - utils/battery-notify/config.def.h
    - utils/battery-notify/config.h
    - dwm-start
decisions: []
metrics:
  duration: 2m
  completed_date: "2026-04-14"
---

# Phase 02 Plan 01: Battery State Machine Summary

**One-liner:** Battery state machine with tiered notifications at 20%/5%, glob detection, and desktop handling.

## What Was Built

Implemented a complete battery notification system with:

1. **Tiered thresholds** in config.def.h: LOW_THRESHOLD=20, CRITICAL_THRESHOLD=5, REARM_THRESHOLD=25
2. **Glob battery auto-detection** using `glob("/sys/class/power_supply/BAT*")` - finds any battery
3. **Tiered notifications** with dunst replace-ids: 9001 (low/normal), 9002 (critical)
4. **State machine** tracking transitions: Normal → Low → Critical, with AC re-arm
5. **Hysteresis** preventing rapid toggling near thresholds
6. **Desktop handling** - exits silently (status 0) when no battery found
7. **dwm-start loop** - battery-notify runs every 30 seconds

## Verification

- Compile: ✓ `make -C utils battery-notify`
- Desktop test: ✓ Exits 0 silently
- Build artifacts: All source files created with correct configuration
- No notifications fired on first run (desktop has no battery)

## Known Stubs

None - the implementation is complete and functional.

## Threat Flags

None - this is a read-only utility that sends local notifications.

---

Commits:
- e6c0a27: feat(02-01): implement battery state machine with tiered notifications