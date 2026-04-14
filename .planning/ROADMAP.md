# Roadmap: Suckless Environment v2

## Overview

v2 is a brownfield hardening milestone on a working dwm/st/dmenu/slstatus/dunst tree. Four phases take the project from "install.sh hardcoded for Artix, battery-notify silently broken, brightness keys dead" to "one install.sh works on Arch + Artix VMs, every user-facing utility is a fast C program, README is shareable." Phase 1 lands the dual-distro installer (which everything else needs to be VM-tested). Phase 2 ships battery + brightness together because they share `utils/common/`, the dunst replace-id namespace, and config conventions. Phase 3 does the shell-to-C parity audit and doc drift purge after C behavior has stabilized. Phase 4 is the public-release gate (README, screenshots, VM verification).

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Install hardening + platform detection** — One install.sh, Arch + Artix, fails loudly elsewhere; ships udev rule and groups setup that Phase 2 needs
- [ ] **Phase 2: Battery + Brightness utilities** — Working battery-notify and new brightness-notify, sharing utils/common, dunst replace-id namespace, and config.def.h conventions
- [ ] **Phase 3: Shell→C migration hygiene + doc drift** — Parity audit, scripts/ deprecation notice, CLAUDE.md drift fixes against final C behavior
- [ ] **Phase 4: Release readiness** — README overhaul, screenshots, manual VM verification on clean Arch + Artix

## Phase Details

### Phase 1: Install hardening + platform detection
**Goal**: A fresh user can clone the repo and run `./install.sh` on either a clean Arch or clean Artix system and end up with a working environment — or get a clear, actionable error if their distro is unsupported.
**Depends on**: Nothing (first phase)
**Requirements**: INST-01, INST-02, INST-03, INST-04, INST-05, INST-06, INST-07, INST-08, INST-09, INST-10, INST-11, INST-12, MIG-04, BRIGHT-03
**Success Criteria** (what must be TRUE):
  1. `./install.sh` runs to completion on a fresh Arch VM without manual intervention and prints a verification summary listing resolved paths for `dwm`, `st`, `dmenu`, `slstatus`, `dunst`, `brightnessctl`, `betterlockscreen`, `powerprofilesctl`, and `loginctl`.
  2. The same `./install.sh` runs to completion on a fresh Artix VM, picks the `-openrc` PPD package variant, enables the service via `rc-update add` + `rc-service start`, and prints the same verification summary.
  3. Running `sudo ./install.sh` exits non-zero with a clear "do not run as root" message before touching any package manager step.
  4. Running `./install.sh` on Ubuntu (or any unsupported distro) exits non-zero with a clear "unsupported distro: <ID>" message and does not modify the system.
  5. Re-running `./install.sh` on an already-installed system completes successfully without duplicating services, reinstalling unchanged packages, or producing errors.
  6. After install + reboot, the installing user is in the `video` and `input` groups, `90-backlight.rules` is present in `/etc/udev/rules.d/`, and `brightnessctl s 50%` works without sudo.
  7. `dwm/p1.rej` is gone from the tree and `.gitignore` correctly ignores `.planning/` (no typo).
**Plans**: 4 plans
- [x] 01-01-installer-skeleton-guards-aur-PLAN.md — POSIX-sh skeleton, guards (root/distro/chroot), sudo keepalive, interactive AUR helper bootstrap
- [x] 01-02-packages-service-udev-groups-PLAN.md — Package install with PPD dispatch, udev rule install, service enable (systemd/openrc), group membership, ships udev/90-backlight.rules
- [x] 01-03-binaries-dotfiles-verification-PLAN.md — Build+install dwm/st/dmenu/slstatus + utils/, dotfiles with timestamped backup, 15-check verification summary
- [x] 01-04-repo-hygiene-PLAN.md — git rm dwm/p1.rej + delete .plannig typo from .gitignore

### Phase 2: Battery + Brightness utilities
**Goal**: A laptop user gets a dunst notification when battery hits 20% (normal urgency) and again at 5% (critical, persistent), and sees a brightness OSD with a progress bar each time they press the brightness keys — both built as one-shot C utilities sharing the project's config and notification conventions.
**Depends on**: Phase 1 (needs `brightnessctl` package, `90-backlight.rules`, and `video`/`input` group membership from Phase 1)
**Requirements**: BATT-01, BATT-02, BATT-03, BATT-04, BATT-05, BATT-06, BRIGHT-01, BRIGHT-02, BRIGHT-04, BRIGHT-05
**Success Criteria** (what must be TRUE):
  1. On a laptop, draining the battery past 20% produces exactly one dunst notification at normal urgency; draining past 5% produces a separate persistent critical notification (different replace-id, low warning is not overwritten by critical).
  2. On a desktop with no battery, `battery-notify` exits silently with status 0 and the `dwm-start` 30s supervisor loop does not spam errors.
  3. Plugging in AC and discharging again re-arms the tier transitions (a second drain past 20% fires a second low notification — the state machine works across charge cycles).
  4. Pressing `XF86MonBrightnessUp` / `XF86MonBrightnessDown` adjusts backlight in 5% steps, never goes below 5% (no black screen), and shows a single dunst OSD with a progress bar that updates in place on rapid key-repeat (replace-id 9101, no notification flooding).
  5. Holding a brightness key for 2 seconds does not fork-storm: `flock` serializes invocations and the OSD updates smoothly.
  6. Both `LOW_THRESHOLD` and `CRITICAL_THRESHOLD` are configurable in `utils/battery-notify/config.def.h` following the suckless `config.def.h → config.h` pattern, and rebuilding picks them up.
**Plans**: 2 plans
- [x] 02-01-battery-state-machine-PLAN.md — Tiered notifications, glob detection, state machine, hysteresis
- [x] 02-02-brightness-osd-PLAN.md — brightness-notify utility, dwm integration, flock serialization, OSD
**UI hint**: yes

### Phase 3: Shell→C migration hygiene + doc drift
**Goal**: A reader of the repo (or `CLAUDE.md`) sees only the C utilities as the supported path; the `scripts/` directory is clearly marked as deprecated with a migration note; and there are no stale references to `slock`, `pkexec cpupower`, or Void Linux anywhere in tracked docs.
**Depends on**: Phase 2 (parity audit must document FINAL C behavior, which only stabilizes after battery + brightness ship)
**Requirements**: MIG-01, MIG-02, MIG-03
**Success Criteria** (what must be TRUE):
  1. `scripts/README.md` exists and explicitly states the directory is deprecated, names the C util that supersedes each shell script, and notes removal is planned for the next milestone.
  2. A line-by-line parity audit document exists in `.planning/` (or commit message) showing each `scripts/` shell script vs its `utils/` C counterpart — flags, edge cases, error messages — with any C gaps either fixed or recorded as deferred.
  3. `CLAUDE.md` references `betterlockscreen` (not `slock`), `powerprofilesctl` (not `pkexec cpupower`), and contains zero references to Void Linux.
  4. `grep -r slock CLAUDE.md` and `grep -r 'pkexec cpupower' CLAUDE.md` both return no matches.
**Plans**: TBD

### Phase 4: Release readiness
**Goal**: A new user landing on the GitHub repo can read the README, understand what the project is, see screenshots of it running, follow the install instructions on Arch or Artix, and reach a working desktop without asking the maintainer questions.
**Depends on**: Phase 3 (README documents the final, drift-free state — slock/pkexec references must be purged before README quotes them)
**Requirements**: REL-01, REL-02, REL-03
**Success Criteria** (what must be TRUE):
  1. `README.md` covers: project purpose, supported distros (Arch + Artix only), one-line install, full keybinding reference table, troubleshooting section for the top 3 install failures, and a link to `CLAUDE.md` / `.planning/` for contributors.
  2. README contains at least 3 screenshots: dwm bar with status, dmenu open, and a dunst notification (battery low or brightness OSD) — captured on a real desktop.
  3. `install.sh` has been verified on a clean Arch VM AND a clean Artix VM (or the README explicitly states "tested on the author's Arch and Artix machines, VM verification deferred") — and the result is documented somewhere in the repo.
  4. A first-time reader can identify what to install, what to expect, and where to look when something breaks — without reading any C source.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Install hardening + platform detection | 0/4 | Not started | - |
| 2. Battery + Brightness utilities | 0/TBD | Not started | - |
| 3. Shell→C migration hygiene + doc drift | 0/TBD | Not started | - |
| 4. Release readiness | 0/TBD | Not started | - |
