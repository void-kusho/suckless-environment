# Phase 1: Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-09
**Phase:** 01-foundation
**Areas discussed:** Code reuse strategy, Build layout, dmenu pipe API

---

## Code Reuse Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Extract + extend | Copy die/warn/pscanf from slstatus, add exec helpers. Drop slstatus-specific funcs. | |
| Write fresh | Same API names but rewritten from scratch | |
| You decide | Claude picks | |

**User's choice:** "Do not touch any suckless software! This will bring too much problems, you can consume his utilities, but not change them"
**Notes:** Hard constraint established — all suckless directories (dwm/, dmenu/, st/, slstatus/) are completely read-only. common/util.c must be an independent implementation.

### Follow-up: SIGCHLD zombie reaper

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, include reaper | setup_sigchld() as shared function | |
| Per-utility handling | Each utility handles own child reaping | |
| You decide | Claude picks per utility | ✓ |

**User's choice:** Asked for clarification on purpose — Claude explained zombie processes, then deferred to Claude's discretion.

---

## Build Layout

| Option | Description | Selected |
|--------|-------------|----------|
| utils/ at root | utils/dmenu-session/, utils/common/ — sibling to dwm/ | ✓ |
| tools/ at root | Different name to distinguish from suckless | |
| You decide | Claude picks | |

**User's choice:** utils/ at root

### Follow-up: install.sh integration

| Option | Description | Selected |
|--------|-------------|----------|
| Same pattern | cd utils/X && make clean install for each | |
| Top-level make | Single Makefile at utils/ root builds everything | ✓ |
| Both | Top-level + individual Makefiles | |

**User's choice:** Top-level make

---

## dmenu Pipe API

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal | Single dmenu_run() function | |
| Two-step | dmenu_open/dmenu_write/dmenu_read/dmenu_close | ✓ |
| You decide | Claude designs simplest API | |

**User's choice:** Two-step API

---

## Claude's Discretion

- SIGCHLD zombie reaping strategy (per utility)
- config.mk variables and flag organization
- Header file organization within common/

## Deferred Ideas

None
