# Suckless Environment v2

## What This Is

A hardened, C-native utility suite for a dwm-based Arch Linux desktop environment. Six compiled C programs replace shell scripts — clipboard daemon (XFixes event-driven), clipboard picker, session manager (betterlockscreen), power profiles (powerprofilesctl), battery monitor, and screenshot notifier. All built with suckless conventions: minimal dependencies, config.def.h, Makefile+config.mk.

## Core Value

Every user-facing utility is a fast, safe, native C program that works reliably without runtime dependencies on shell interpreters.

## Requirements

### Validated

- ✓ dwm + st + dmenu + slstatus build pipeline — existing
- ✓ dunst notification system with Tokyo Night theme — existing
- ✓ Installer script for Arch Linux — existing
- ✓ Shared utility library (die, warn, pscanf, exec helpers) — v1.0 Phase 1
- ✓ Shared dmenu pipe library (fork+dup2+exec) — v1.0 Phase 1
- ✓ Per-tool directory structure under utils/ — v1.0 Phase 1
- ✓ Updated install.sh with C build pipeline — v1.0 Phase 1
- ✓ Battery notification (one-shot sysfs, state file dedup) — v1.0 Phase 2
- ✓ Screenshot notification (maim|xclip pipeline, cancel detection) — v1.0 Phase 2
- ✓ Lock screen via betterlockscreen (blur 0.8, DISPLAY validation, duplicate prevention) — v1.0 Phase 3
- ✓ Power profiles via powerprofilesctl (performance/balanced/power-saver) — v1.0 Phase 3
- ✓ Clipboard history picker (mtime sort, 80-char previews, xclip restore) — v1.0 Phase 3
- ✓ Session manager (logout/lock/reboot/shutdown with confirmations) — v1.0 Phase 3
- ✓ Clipboard daemon (XFixes events, FNV-1a dedup, flock, SIGTERM shutdown) — v1.0 Phase 4

### Active

(None — v1.0 scope fully delivered)

### Out of Scope

- dwm/st/dmenu/slstatus source modifications — separate concern
- Wayland support — X11 only
- Multi-monitor betterlockscreen config — single display target
- Interactive screenshot tools (annotation, cropping UI) — just capture and notify
- Full SelectionRequest serving in clipboard daemon — deferred to v2
- Atomic file writes in clipboard daemon — deferred to v2
- INCR protocol for >256KB clipboard entries — deferred to v2

## Context

- Arch Linux with pacman + AUR (yay/paru)
- Suckless ecosystem: dwm, st, dmenu, slstatus — all built from patched source
- Tokyo Night color scheme throughout (dwm, st, dmenu, slstatus, dunst)
- dwm-start is the session launcher (stays as shell script)
- 6 C utilities totaling ~1,748 lines under utils/
- All utilities linked against shared common/util.c and common/dmenu.c
- dmenu-clipd is the most complex (405 lines, X11 event loop)

## Constraints

- **Platform**: Arch Linux only — pacman/AUR package names
- **Philosophy**: Suckless-style C — minimal dependencies, no frameworks
- **Display server**: X11 — dmenu-clipd uses Xlib/XFixes directly
- **Deps**: betterlockscreen (AUR), power-profiles-daemon (pacman), maim + xclip (pacman)
- **Build**: Single top-level Makefile at utils/, install.sh orchestrates everything

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Replace slock with betterlockscreen | Better UX (blur, wallpaper-based lock) | ✓ Good |
| Replace cpupower with powerprofilesctl | Modern power management, no privilege escalation | ✓ Good |
| X11 XFixes events for clipboard daemon | Zero CPU idle, instant change detection | ✓ Good |
| Per-tool directories under utils/ | Clean separation, shared Makefile | ✓ Good |
| dwm-start stays as shell script | Launcher role — shell appropriate for spawning | ✓ Good |
| All utilities compiled C | Fast, safe, no shell interpreter dependency | ✓ Good |
| FNV-1a over MD5 for clipboard dedup | Zero dependencies, sufficient for non-crypto hashing | ✓ Good |
| exec notify-send over libnotify/sd-bus | Simpler, consistent with suckless exec-everything | ✓ Good |
| flock over PID file for single-instance | Auto-releases on crash, no stale files | ✓ Good |
| select()+ConnectionNumber for event loop | SIGTERM-safe without busy waiting | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:**
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone:**
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-09 after v1.0 milestone*
