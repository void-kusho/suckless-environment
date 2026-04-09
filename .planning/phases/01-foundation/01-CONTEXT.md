# Phase 1: Foundation - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a shared C utility library (`common/`) and build system that all subsequent utilities compile against. This phase produces no user-facing binaries — it establishes the foundation code and Makefile convention. install.sh is updated to compile and install the new utilities.

</domain>

<decisions>
## Implementation Decisions

### Code Reuse Strategy
- **D-01:** NEVER modify suckless source directories (dwm/, dmenu/, st/, slstatus/). These are upstream-patched and must remain untouched.
- **D-02:** common/util.c is a fresh standalone implementation inspired by suckless patterns. Same function names (die, warn, pscanf) but independent code. Not a copy-paste from slstatus.
- **D-03:** common/util.c provides: die(), warn(), pscanf(), exec_wait() (fork+execvp+waitpid for commands where exit status matters), exec_detach() (fork+execvp for fire-and-forget spawning), and a SIGCHLD zombie reaper setup function.

### Build Layout
- **D-04:** All new C utilities live under `utils/` at repo root — sibling to dwm/, dmenu/, etc.
- **D-05:** Directory structure: `utils/common/`, `utils/dmenu-session/`, `utils/dmenu-cpupower/`, `utils/dmenu-clip/`, `utils/dmenu-clipd/`, `utils/battery-notify/`, `utils/screenshot-notify/`
- **D-06:** A single top-level Makefile at `utils/` builds all utilities in one `make` command. Individual utility directories contain their .c source files but no standalone Makefiles.
- **D-07:** install.sh calls `make -C utils` to build, then installs binaries to ~/.local/bin.

### dmenu Pipe API
- **D-08:** Two-step API design: dmenu_open(prompt, argv) returns a handle, dmenu_write()/dmenu_read() operate on it, dmenu_close() cleans up. This gives callers control over when to write items and read selection.
- **D-09:** Uses fork+dup2+exec internally (never popen) to avoid bidirectional pipe deadlock.
- **D-10:** dmenu_read() returns NULL on cancel (user pressed Escape) or empty selection.

### Claude's Discretion
- Zombie reaping strategy (SIGCHLD handler vs per-call waitpid) — Claude picks per utility
- config.mk variable names and flag organization
- Header file organization within common/

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Patterns
- `slstatus/util.c` — Reference for die/warn/pscanf pattern (DO NOT MODIFY, read-only reference)
- `slstatus/util.h` — Reference for header style and LEN macro
- `slstatus/Makefile` — Reference for suckless Makefile convention
- `dwm/Makefile` — Reference for config.mk pattern
- `install.sh` — Current installer that must be extended (not replaced)

### Research
- `.planning/research/STACK.md` — Verified library dependencies and build flags
- `.planning/research/ARCHITECTURE.md` — Component boundaries and shared code design
- `.planning/research/PITFALLS.md` — Zombie process, pipe deadlock, and signal safety pitfalls

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `slstatus/util.c` pattern: die/warn with verr() helper, pscanf for sysfs reads — **read-only reference** for API design
- `slstatus/Makefile` + `config.mk`: suckless build convention with `-lX11` flags — reference for utils/ build system
- `dwm/config.h`: Shows how compile-time config works in suckless ecosystem

### Established Patterns
- K&R style braces, tab indentation, 80-col target
- Static helper functions with `static` keyword
- `#include` order: stdlib → POSIX → X11 → local headers
- `const char *` return for display strings, NULL on error

### Integration Points
- install.sh: needs new section for `make -C utils` and binary installation
- dwm-start: will launch new binaries (future phases, not this phase)
- ~/.local/bin: installation target for all utility binaries

</code_context>

<specifics>
## Specific Ideas

- User explicitly stated: "Do not touch any suckless software! This will bring too much problems." This is a hard constraint — all suckless directories are read-only reference material.
- Build should match suckless aesthetic (Makefile + config.mk) but be independent.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-04-09*
