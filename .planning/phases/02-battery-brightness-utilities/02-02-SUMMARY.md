---
phase: 02-battery-brightness-utilities
plan: 02
subsystem: brightness-notify
tags: [brightness, osd, dunst, fork-safety]
dependency_graph:
  requires: []
  provides: [brightness-notify]
  affects: [dwm/config.def.h]
tech_stack:
  - C99 with flock serialization
  - brightnessctl (unprivileged)
  - dunst OSD with replace-id
key_files:
  created:
    - utils/brightness-notify/brightness-notify.c
    - utils/brightness-notify/config.def.h
    - utils/brightness-notify/config.h
  modified:
    - utils/Makefile
    - dwm/config.def.h
decisions: []
metrics:
  duration: 3m
  completed_date: "2026-04-14"
---

# Phase 02 Plan 02: Brightness OSD Summary

**One-liner:** Brightness control utility with dunst OSD progress bar and flock fork-serialization.

## What Was Built

Implemented complete brightness control:

1. **brightness-notify utility** - accepts "up" or "down" arguments
2. **flock serialization** - prevents fork-storm on rapid key-repeat using `/tmp/brightness.lock`
3. **brightnessctl integration** - uses unprivileged `brightnessctl -c backlight s` for adjustments
4. **Floor enforcement** - MIN_BRIGHTNESS=5% prevents accidental black screen
5. **Step size** - STEP_SIZE=5% per keypress
6. **Dunst OSD** - shows progress bar with replace-id 9101 that updates in place
7. **Makefile integration** - build and install targets added
8. **dwm keybindings** - wired into config.def.h

## Verification

- Compile: ✓ `make -C utils` builds brightness-notify
- Test: ✓ `brightness-notify up/down` works (shows current 100%)
- Lock file: Created on each run, released after

## Known Stubs

None - implementation is complete.

## Threat Flags

None - uses unprivileged brightnessctl with flock protection.

---

Commits:
- fc2d3bb: feat(02-02): implement brightness-notify with OSD and fork-serialization