# Milestones

## v1.0 Native C Utilities (Shipped: 2026-04-09)

**Phases completed:** 4 phases, 8 plans, 8 tasks

**Key accomplishments:**

- Bidirectional dmenu pipe API using fork+dup2+exec with deadlock-safe read ordering and install.sh build pipeline
- One-shot sysfs battery monitor with state-file dedup and exec_detach critical dunst notification
- Two-child maim|xclip pipeline with cancel detection and fire-and-forget dunst notification
- 1. [Rule 1 - Bug] Fixed -Wformat-truncation warning on path snprintf
- Event-driven X11 clipboard daemon using XFixes, FNV-1a dedup, flock single-instance, and select()-based interruptible event loop
- Makefile integration for dmenu-clipd with X11_LIBS (-lX11 -lXfixes) scoped linking and zero-warning compilation of all 6 utilities

---
