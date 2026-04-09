---
phase: 4
slug: clipboard-daemon
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-09
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | GNU Make + GCC compilation + manual daemon testing |
| **Config file** | `utils/config.mk` + `utils/dmenu-clipd/config.def.h` |
| **Quick run command** | `make -C utils clean all` |
| **Full suite command** | `make -C utils clean all && make -C utils test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `make -C utils clean all`
- **After every plan wave:** Run full suite + manual daemon test
- **Before `/gsd-verify-work`:** Full suite must be green + daemon tested
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | CLIPD-02 | — | N/A | compile | `test -f utils/dmenu-clipd/config.def.h` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | CLIPD-01,02,03,04,05 | — | N/A | compile | `make -C utils` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 2 | CLIPD-01 | — | N/A | compile+link | `make -C utils clean all` | ❌ W0 | ⬜ pending |
| 04-02-02 | 02 | 2 | CLIPD-01,04,05 | — | N/A | manual | daemon e2e test | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `utils/dmenu-clipd/dmenu-clipd.c` — daemon source
- [ ] `utils/dmenu-clipd/config.def.h` — compile-time config
- [ ] Makefile integration with `-lX11 -lXfixes`

*Note: Unit tests for FNV-1a, LRU pruning, and flock are deferred. The daemon is inherently interactive (X11 event loop) — automated testing requires a running X display. Build verification + manual e2e testing is the appropriate Nyquist-level sampling for this domain.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| XFixes event capture | CLIPD-01 | Requires running X11 display | Start daemon, copy text, check cache dir |
| Dedup via FNV-1a | CLIPD-02 | Requires clipboard interaction | Copy same text twice, verify single cache file |
| LRU pruning | CLIPD-03 | Requires 50+ clipboard operations | Populate cache beyond 50, verify oldest removed |
| Single instance (flock) | CLIPD-04 | Requires running daemon | Start two instances, verify second exits |
| SIGTERM shutdown | CLIPD-05 | Requires running daemon | Send SIGTERM, verify clean exit within 1s |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-04-09
