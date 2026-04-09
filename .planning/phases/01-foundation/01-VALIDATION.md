---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-09
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | GNU Make + GCC compilation + manual execution |
| **Config file** | `utils/config.mk` |
| **Quick run command** | `make -C utils clean all` |
| **Full suite command** | `make -C utils clean all && utils/test-util && utils/test-dmenu` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `make -C utils clean all`
- **After every plan wave:** Run full suite command (compile + test binaries)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | FOUND-01 | — | N/A | compile | `make -C utils` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | FOUND-02 | — | N/A | compile | `make -C utils` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | FOUND-03 | — | N/A | compile | `make -C utils` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 1 | FOUND-04 | — | N/A | compile | `./install.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `utils/Makefile` — top-level build system
- [ ] `utils/config.mk` — shared compiler flags
- [ ] `utils/common/util.c` — shared utility library
- [ ] `utils/common/dmenu.c` — dmenu pipe helpers

*Existing infrastructure: None — this phase creates the build foundation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| dmenu pipe interaction | FOUND-02 | Requires running X11 display + dmenu | Run `utils/test-dmenu`, verify dmenu appears, select item, check output |
| install.sh binary placement | FOUND-04 | Requires checking ~/.local/bin | Run `./install.sh`, verify binaries exist in `~/.local/bin/` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
