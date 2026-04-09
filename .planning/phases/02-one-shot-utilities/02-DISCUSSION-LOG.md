# Phase 2: One-Shot Utilities - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-09
**Phase:** 02-one-shot-utilities
**Areas discussed:** Notification method, Battery config, Screenshot workflow

---

## Notification Method

| Option | Description | Selected |
|--------|-------------|----------|
| notify-send (Recommended) | exec notify-send, no library deps, suckless philosophy | ✓ |
| dunstify | Dunst-specific, supports replace-id | |
| You decide | Claude picks | |

**User's choice:** notify-send (Recommended)

---

## Battery Config

| Option | Description | Selected |
|--------|-------------|----------|
| Compile-time config | config.def.h with #define BATTERY and THRESHOLD — suckless pattern | ✓ |
| Hardcoded | BAT1 and 20% in source | |
| You decide | Claude picks | |

**User's choice:** Compile-time config

---

## Screenshot Workflow

| Option | Description | Selected |
|--------|-------------|----------|
| Check maim exit code | maim -s exits non-zero on cancel, only notify on 0 | ✓ |
| Check xclip input | More complex, unnecessary | |
| You decide | Claude picks | |

**User's choice:** Check maim exit code

---

## Claude's Discretion

- Notification urgency levels
- State file cleanup details
- exec_wait vs exec_detach for notify-send

## Deferred Ideas

None
