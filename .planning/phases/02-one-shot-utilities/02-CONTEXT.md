# Phase 2: One-Shot Utilities - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver two one-shot C utilities: `battery-notify` (reads sysfs, alerts via dunst when battery ≤20% and discharging) and `screenshot-notify` (captures area via maim, copies to clipboard, notifies via dunst). Both link against common/util.c from Phase 1 and install via the existing Makefile/install.sh pipeline.

</domain>

<decisions>
## Implementation Decisions

### Notification Method
- **D-01:** Both utilities send notifications via `exec notify-send` (fork+execvp from common/util.c). No libnotify, no dunstify, no sd-bus direct calls.
- **D-02:** notify-send is already installed on the system. No new dependencies.

### Battery Monitor (battery-notify)
- **D-03:** Compile-time configuration via config.def.h/config.h (suckless pattern). User copies config.def.h to config.h to customize.
- **D-04:** Default defines: `#define BATTERY "BAT1"` and `#define THRESHOLD 20`
- **D-05:** Reads `/sys/class/power_supply/{BATTERY}/capacity` and `/sys/class/power_supply/{BATTERY}/status` using pscanf() from common/util.c
- **D-06:** State file at `/tmp/battery-notified` prevents re-alert spam. Created when alert fires, cleared when capacity rises above threshold or status changes to Charging/Full.
- **D-07:** Notification uses `notify-send -u critical "Battery Low" "Battery at {N}%"`

### Screenshot (screenshot-notify)
- **D-08:** Capture via fork+exec: `maim -s` piped to `xclip -selection clipboard -t image/png`
- **D-09:** Cancel detection: check maim exit code. Only notify on exit 0.
- **D-10:** Notification text: `notify-send "Screenshot" "Image copied to clipboard"`
- **D-11:** Silent exit on cancel (maim exit non-zero) — no notification, no error, just exit 0.

### Claude's Discretion
- Exact notification urgency levels (normal vs critical)
- State file cleanup strategy details
- Whether to use exec_wait or exec_detach for notify-send (fire-and-forget is fine)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Foundation (Phase 1)
- `utils/common/util.h` — API for die(), warn(), pscanf(), exec_wait(), exec_detach(), setup_sigchld()
- `utils/common/util.c` — Implementation reference for exec patterns
- `utils/config.mk` — Shared compiler flags, PREFIX definition
- `utils/Makefile` — Build system to extend with new BINS entries

### Research
- `.planning/research/STACK.md` — Verified sysfs paths (BAT1), notify-send availability
- `.planning/research/ARCHITECTURE.md` — One-shot utility pattern, exec-only actions
- `.planning/research/PITFALLS.md` — Battery re-alert spam (state file), sysfs stale reads (open/read/close per pscanf)

### Existing Patterns
- `slstatus/components/battery.c` — Read-only reference for sysfs battery reading pattern (DO NOT MODIFY)
- `install.sh` — Installer to extend (add betterlockscreen dep, but that's Phase 3)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `common/util.c:pscanf()` — reads sysfs files (open/read/close per call, avoids stale data)
- `common/util.c:exec_wait()` — fork+execvp+waitpid for commands where exit status matters (maim)
- `common/util.c:exec_detach()` — fork+execvp for fire-and-forget (notify-send)
- `common/util.c:die()/warn()` — error handling

### Established Patterns
- K&R style, tabs, C99, config.mk include
- Process spawning via fork+execvp (never system/popen)
- SIGCHLD handler for zombie prevention

### Integration Points
- `utils/Makefile` BINS variable — add battery-notify and screenshot-notify
- `install.sh` — already handles `make -C utils` and binary installation
- Each utility gets its own subdirectory: `utils/battery-notify/`, `utils/screenshot-notify/`

</code_context>

<specifics>
## Specific Ideas

- Battery notification should use `-u critical` urgency for dunst to show it persistently
- Screenshot notification is intentionally minimal — just "Image copied to clipboard", no thumbnail, no path

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-one-shot-utilities*
*Context gathered: 2026-04-09*
