---
phase: 01-foundation
plan: 01
subsystem: build-system
tags: [c, makefile, posix, suckless]

requires:
  - phase: none
    provides: first phase
provides:
  - Shared utility library (common/util.c) with die, warn, pscanf, exec_wait, exec_detach, setup_sigchld
  - Shared dmenu pipe header (common/dmenu.h) with DmenuCtx, dmenu_open, dmenu_write, dmenu_read, dmenu_close
  - Build system (config.mk + Makefile) with suckless-standard C99 flags
  - Directory structure for all 6 utilities under utils/
  - Test program (test-util) validating compilation and API linkage
affects: [01-02, phase-2, phase-3, phase-4]

tech-stack:
  added: [gcc, gnu-make, posix-c99]
  patterns: [config.mk-include, fork-execvp-waitpid, sigaction-sigchld]

key-files:
  created:
    - utils/config.mk
    - utils/Makefile
    - utils/common/util.h
    - utils/common/util.c
    - utils/common/dmenu.h
    - utils/common/dmenu.c
    - utils/tests/test-util.c
  modified: []

key-decisions:
  - "Fresh implementation of util.c (not copied from slstatus)"
  - "Single top-level Makefile at utils/ (no per-utility Makefiles)"
  - "PREFIX = $(HOME)/.local for user-level installation"

patterns-established:
  - "K&R style, tabs, C99: all utils follow suckless convention"
  - "fork+dup2+exec: process spawning pattern (never system() or popen)"
  - "config.mk include: shared flags across all utility builds"
  - "SIGCHLD handler: setup_sigchld() for zombie process prevention"
---

# Plan 01-01 Summary: Build System + Shared Utility Library

## What Was Built

Created the foundation build system and shared C utility library that all Phase 2-4 utilities will compile against.

### Build System
- `utils/config.mk` — shared compiler flags (-std=c99, -pedantic, -Wall, -Wextra, -Os)
- `utils/Makefile` — top-level build orchestrator with pattern rules for subdirectory compilation

### Shared Utility Library (common/)
- `utils/common/util.h` / `util.c` — die(), warn(), pscanf(), exec_wait(), exec_detach(), setup_sigchld()
- `utils/common/dmenu.h` / `dmenu.c` — DmenuCtx struct, dmenu_open(), dmenu_write(), dmenu_read(), dmenu_close() declarations and stub implementation

### Test Infrastructure
- `utils/tests/test-util.c` — compilation and linkage test for all util.c functions

## Verification

- `make -C utils clean all` compiles without errors or warnings
- All 6 utility subdirectories created under utils/
- util.h exports all 6 public functions + LEN macro + argv0
- dmenu.h exports DmenuCtx struct + 4 pipe helper functions
- config.mk contains PREFIX = $(HOME)/.local and -std=c99 flags

## Self-Check: PASSED

All must_haves from PLAN.md verified against the codebase.

## Deviations

- dmenu.c was included with stub/skeleton implementation alongside the header (Plan 01-02 will complete the full implementation)
- test-util.c is comprehensive (253 lines) covering all util.c functions with proper test structure
