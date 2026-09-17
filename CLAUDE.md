# CLAUDE.md — project context, `nixos` branch

`README.md` is the manual. This file is the *why*, and the record of what
was found broken, how, and what fixed it. Every claim here was checked
against the reference machine below, not against the repository.

## What this is

The X11 suckless desktop — dwm, st, dmenu, slstatus, a C utility suite,
Doom Emacs — for **NixOS**, declaratively. Sibling branches: `guix` (same
desktop on GNU Guix), `origin/artix` (the imperative Arch/Artix build, and
the machine this all targets), `guix-wayland` (an abandoned dwl port).

## Rules

- **Talk to the owner in Portuguese. Write code, comments and docs in English.**
- **Doom Emacs is the editor.** No Neovim, no Helix, no Yazi.
- **Minimal.** One entry point per concern. Nothing in the system that
  `nix shell nixpkgs#…` can provide per project — no compilers, no language
  servers (decision 4). The *user's* home-manager list is the user's call.
- **Nothing that fails `nix flake check` reaches `nixos-rebuild switch`.**
  `nixfmt $(git ls-files '*.nix')` is the formatting check; `nix fmt` is
  `nixfmt-tree`, walks past this tree, and exits non-zero on unrelated files.
- **Tokyo Night:** `#1a1b26` `#a9b1d6` `#414868` `#7aa2f7` `#565f89` `#f7768e`
  `#9ece6a` `#e0af68` `#bb9af7` `#7dcfff`.
- **Session state** (monitor layout, pointer warp) lives in
  `~/.config/suckless/autostart.sh`, never in `nix/`. For the reference
  machine that file is `hosts/nixos-btw/autostart.sh`, installed by activation.
- **`utils/` carries no `config.h` on this branch.** The backends —
  `powerprofilesctl`, `betterlockscreen`, `systemctl` — are in the `.c`
  files, which is why `services.power-profiles-daemon` is on — and
  `services.upower`, which is where that daemon learns AC from battery
  (2026-09-17 below). `.gitignore`
  blocks a `config.h`; do not copy the `guix` branch's. Where `origin/artix`
  reads `loginctl`, this branch reads `systemctl`: elogind and systemd
  disagree about who owns the power verbs.
- **Parity with `origin/artix` is byte-identical** for `dwm/config.h`,
  `st/config.h`, `dmenu/config.h`, `slstatus/config.h`, `dunst/dunstrc`,
  `fcitx5/profile`, `fcitx5/config`. nixpkgs carries every font and tool the
  Arch build uses, so unlike `guix` nothing had to diverge.
- **Documents describe the state that exists.** A claim about the machine
  ("`/etc/nixos` is a pointer") is checked on the machine before it is
  written, and written in the tense that is true.

## The reference machine

Read live. Reinstalled 2026-09-05; the UUIDs in
`hosts/nixos-btw/hardware-configuration.nix` are the ones that produced.

```
Intel i5-1135G7 (TigerLake-LP), 8 threads, 16 GiB, NVMe
Iris Xe Graphics                          [8086:9a49]
Intel Wi-Fi 6 AX201                       [8086:a0f0]
Intel Bluetooth 9460/9560 Jefferson Peak  [8087:0aaa]
Intel HD Audio, 500 series                [8086:a0c8]
BAT1 · intel_backlight · keyboard br/abnt2 · console br-abnt2
eDP-1 1920x1080@60 at 0x0 (BOE, 8-bit, no VRR)
DP-1  1920x1080@180 at 1920x0, primary — AOC 27G4: FreeSync 48–180, 10 bpc, HDR10
```

The three PCI IDs are why `hardware.enableRedistributableFirmware` is not
optional: AX201, Jefferson Peak and the Iris Xe GuC/HuC all load microcode
at runtime.

**The battery is worn** (read 2026-09-16): SAMSUNG "SR Real Battery",
`charge_full` 2458 mAh of 3780 design — 65 % health, 734 cycles. It enters
the constant-voltage taper at ~84 % (pack at 12.3–12.56 V, 4.1–4.19 V per
cell), so the last sixth charges at a few hundred mA and any load turns
the net negative while the EC still reports `Charging` — which is all
slstatus' `+` means. The EC also carries Samsung's charge cap
(`charge_control_end_threshold`, the `samsung-galaxybook` driver); it read
80, raising it to 100 changed nothing measurable, and the value persists
in firmware, so it is not host configuration. USB-C `port0` has the laptop
as the *source*, feeding the monitor or hub out of the charger's budget.

**How it is built.** `/etc/nixos` is a symlink to the clone at
`/home/void/suckless-environment`. `nixos-rebuild` implies `--flake /etc/nixos`
when `/etc/nixos/flake.nix` exists and picks `nixosConfigurations.<hostname>`,
so the daily command is `sudo nixos-rebuild switch`, and it builds the same
store path as `--flake .#nixos-btw`. `checks.nixos-btw` builds the whole host
— home-manager, disks and all — so `nix flake check` fails when *this
machine* stops building, not a stand-in.

**What the host holds** (`hosts/nixos-btw/`): systemd-boot on the existing
ESP; the user (`wheel networkmanager video input`); English default with a
`japanese` specialisation (the module's default inverted, `mkForce` on the
whole set); the monitor layout; VRR on DP-1 and the `vrr` command; weekly
`nix.gc` (7 d) and `nix.optimise`; `programs.steam` at the system level
(it does not exist in home-manager, and only the system module can set
`enable32Bit`, open the firewall and install the FHS wrapper); a five-name
`allowUnfreePredicate` (`spotify obsidian steam steam-unwrapped steamcmd`);
home-manager (`useGlobalPkgs`, `useUserPackages`) for the user's
applications and toolchains.

**Refresh the disks after a reinstall:**
`nixos-generate-config --show-hardware-config | nixfmt > hosts/nixos-btw/hardware-configuration.nix`.

## What owns what

| Path | Owns | Never contains |
|---|---|---|
| `nix/module.nix` | the desktop: `programs.suckless-environment.{enable, extraPackages, wallpaper}`, session daemons, fonts, fcitx5/mozc, Ly, nix-ld libraries, xdg files | a disk, a user, a hostname |
| `nix/laptop.nix` | the chipset: firmware, microcode, `modesetting`, iHD (VA-API), `vpl-gpu-rt` (QuickSync), thermald, fstrim, fwupd, flatpak + GTK portal | same |
| `hosts/nixos-btw/` | this machine, whole | anything anyone imports |
| `hosts/vm.nix` | the QEMU host: autologin, `startx`, Ly off, `grab-on-hover` | — |
| `templates/laptop/` | a teaching copy of the host with the disks removed, for `nix flake init -t .#laptop` | UUIDs |

When the host and the template drift, the host is right.

## Decisions

1. **Doom Emacs, with `$DOOMDIR` in the store** (`environment.variables.DOOMDIR`
   → `doom/`). No first-run copy, no drift, no re-seeding; the cost is a
   read-only `~/.config/doom` — edit `doom/` and rebuild. Two things `doom
   doctor` turned up: `doom install` writes `~/.config/doom` from Doom's
   example templates regardless of `$DOOMDIR`, and the doctor then reports
   "two private configs", naming them in a fixed order and calling the
   *second* ignored — backwards here, because `doom-user-dir` short-circuits
   on `$DOOMDIR`. `doom info` is the truth; the shadow directory is
   byte-identical to `static/*.example.el` and safe to delete. And
   `nerd-icons.el` asks for the family "Symbols Nerd Font Mono" by name, which
   a patched Iosevka does not answer to: `nerd-fonts.symbols-only` is in
   `fonts.packages` or every icon is tofu.
2. **Modules describe a desktop and a chipset, never a disk; the repository
   also carries one real host.** `nixosModules.{default,laptop}` have no
   `fileSystems`, `swapDevices`, `boot.loader`, `users.users` or
   `stateVersion`, because other people import them. `hosts/nixos-btw/` is
   the exception, and nobody imports a host. This reversed two earlier
   positions, each right about something: "a repository that ships a disk
   hands its UUIDs to importers" (true — answered by keeping the *modules*
   diskless) and "the machine is about to be reinstalled and a stale UUID is
   a trap that looks like documentation" (true, and spent on 2026-09-05).
3. **`hosts/minimal.nix` and `default.nix` are gone.** One template of the
   machine, one interface for non-flake users.
4. **Toolchains stay out of the system.** `nix shell nixpkgs#rust-analyzer`.
   The user's home-manager list (rustc, zig, gcc, python3, nodejs…) is the
   user's, not the machine's.
5. **Ly is the display manager, `mkDefault true` in the module**, Tokyo
   Night themed. It was only ever *detected* before. Ly's colours are
   `0xAARRGGBB` where the top byte is an *attribute*, not alpha (`0x01` =
   bold, as in upstream's `error_fg = 0x01FF0000`). Its clock is ASCII on
   purpose — the console font has no CJK — and its password prompt uses the
   **console** keymap, hence `console.keyMap = "br-abnt2"`. `hosts/vm.nix`
   turns it off; the module hands `services.xserver.autorun` and the `startx`
   pseudo-DM back when it goes off.
6. **The installation is a flake template**, `templates/laptop/`: the
   host's `/etc/nixos` with the disks removed — `flake.nix`,
   `configuration.nix` (four `EDIT` markers), `home.nix`, `autostart.sh`.
   `checks.install-template` builds it on `nixosModules.laptop` against a
   throwaway root so it cannot rot unnoticed. It does not reopen decision 2:
   nothing in it is *declared* by the repository; it is copied once and
   owned by whoever copied it.
7. **`/etc/nixos` is a symlink, not a flake that imports this one.** A
   `git+file:` input sees committed work only and moves only on `nix flake
   update`; that design ran the machine nine days behind the repository in
   silence (see 2026-09-16 below). A symlink has no lock file to go stale.
8. **No compositor.** picom was here for vsync and open/close animations,
   and it cost the external monitor two thirds of its refresh rate: the
   overlay is one root-sized swap, the server syncs that drawable to one
   CRTC, and with two 1920×1080 outputs the choice fell on the 60 Hz panel
   (measured: a root-sized GL window synced at 60; one on DP-1 alone at
   180). No `compositor.enable` option remains — an option that defaults
   to the wrong thing is how it came back. Without a compositor each
   window presents to its own CRTC; the cost is the animations and a
   global tear-free guarantee that modesetting 21.1 cannot give anyway
   (`TearFree` arrived in xserver 22).

## Findings

Each entry: what was seen, what it was, what fixed it and where. Grouped by
the method that found it, because none of them was visible by reading.

### By evaluating — `nix flake check`

Nix was runnable before the system existed, from `~/.nix-portable`; that is
how these came out.

- **`hosts/laptop.nix` could not build.** `services.flatpak.enable` with no
  portal; NixOS asserts *"To use Flatpak you must enable XDG Desktop
  Portals"*. It was never in `nixosConfigurations`, so nothing evaluated it.
  Now a complete host, wired into the check.
- **Three runtime dependencies had no provider**, found by listing what the
  session invokes against the *effective* `systemPackages` (189 entries):
  `pamixer` (`slstatus/config.h:76`; the volume segment was dead),
  `libnotify` (`notify-send` for battery/brightness-notify; not part of
  dunst), `gtk3` (`gtk-launch` for `dmenu_run_desktop`; `Super+d` listed and
  launched nothing). `xrandr` and `procps`, also suspected, come from
  `services.xserver`.
- **Thunar was a bare package**: no thumbnails, trash or removable media.
  Now `programs.thunar` + `services.gvfs` + `services.tumbler`, which is
  what registers its D-Bus services.
- **nixpkgs was 239 days stale and end-of-life.** Moving to `nixos-26.05`
  surfaced: `noto-fonts-emoji` → `noto-fonts-color-emoji`, `poppler_utils`
  → `poppler-utils`, `neofetch` removed, `xorg.*` → top-level `libx11` &c.,
  `xfce.thunar-{archive-plugin,volman}` and `xfce.exo` → top level,
  `pkgs.system` → `pkgs.stdenv.hostPlatform.system`. Zero warnings now.

### By booting — `pkgs.testers.runNixOSTest`

A headless VM that logs in on a TTY, runs `startx`, and asserts on the live
session. Building proves evaluation; only booting proves it runs.

- **The store shipped binaries compiled on Artix.** `src = ../dwm` copies
  the working tree; every vendored Makefile builds in place; a leftover
  `dwm` was newer than its sources, so `make` skipped the compile and
  installed the foreign binary, which asked for `/lib64/ld-linux-x86-64.so.2`
  and died at `exec dwm`. `brightness-notify` was even committed. Three
  layers now: `preBuild = "make clean"` in `nix/lib.nix` (every Makefile
  has `clean`; none touches `config.h`), a `postFixup` that fails on any
  interpreter outside the store, `.gitignore` for all eleven build products.
- **fcitx5 and mozc had never worked.** `i18n.inputMethod.type` without
  `enable` installs nothing and exports no `GTK_IM_MODULE` /
  `QT_IM_MODULE` / `XMODIFIERS`; the launcher called bare `${pkgs.fcitx5}`
  instead of `config.i18n.inputMethod.package`. `mozc_server` runs now.
- **The launcher's idempotency guard was a no-op.** `pgrep -x "${1##*/}"`
  matches a process *name*; makeWrapper'd packages run as `.dunst-wrapped`,
  and `comm` caps at 15 chars (`.flameshot-wrap`). Four of six daemons are
  wrapped. It matches the full store path now — the wrapper keeps `argv[0]`.
- **No firmware at all.** A hand-written hardware block does not import
  `installer/scan/not-detected.nix`, where `nixos-generate-config` turns
  `enableRedistributableFirmware` on. The `firmware` derivation was 5.2 KiB;
  808.6 MiB now, with `iwlwifi-QuZ-a0-*.ucode`.
- Smaller: TTYs had no keymap (`console.keyMap = "br-abnt2"` — the
  password prompt is a TTY); `blueman` without `services.blueman` could not
  pair; udisks2 calls a fixed second drive *system internal*
  (`auth_admin_keep`), so a polkit rule lets `wheel` mount it silently.
- **Two things made a working VM look broken.** No wallpaper anywhere:
  `nix/module.nix` left it to `autostart.sh`, which nothing ever created —
  it is `wallpapers/sushi_original.png` and
  `programs.suckless-environment.wallpaper` now, painted before the hook so
  a hook can override. And every keybinding went to the host: QEMU's GTK
  display does not grab the keyboard by default — `-display
  gtk,grab-on-hover=on`. The VM boots straight into dwm (autologin +
  `startx` from `loginShellInit`; `/etc/profile` sources `set-environment`
  first, so PATH is right when X starts).

### By driving the session — `xdotool` into live dwm

- **`loginctl poweroff` / `reboot` do not exist on systemd.** They are
  elogind verbs (real on `origin/artix`). `exec_detach` sends stderr
  nowhere, so "Unknown command verb" never printed and the menu looked
  inert. `dmenu-session` calls `systemctl`; logind answers `CanPowerOff` /
  `CanReboot` yes for an active local session, no password either way.
- **`exec_wait` raced its own SIGCHLD handler.** `sigchld_handler` reaps
  every child with `waitpid(-1, WNOHANG)`, wins against anything as fast as
  `pgrep`, and `exec_wait`'s `waitpid` then fails with ECHILD leaving
  `status` uninitialised — the "is a lock screen up?" guard in
  `action_lock` skipped locking on stack garbage. SIGCHLD is blocked around
  fork/wait and restored in the child.
- **Thunar could not run anything in a terminal.** exo 4.20 hands it to
  `xfce4-mime-helper`, which ships only in `xfce4-settings` (1.5 GiB,
  deliberately absent). The fallback spawns `<binary> "<whole command line
  as one argv>"`; st read it as argv[0] and died with *"child exited with
  status 1"*. `st-exo-helper` in `nix/module.nix` turns that one argument
  back into `st -e sh -c`. Same fallback, two dead `helpers.rc` entries:
  values are *binary names* via `g_find_program_in_path`
  (`WebBrowser=brave-browser` never matched; the binary is `brave`), and it
  reads `g_get_user_config_dir()` only — not `XDG_CONFIG_DIRS`, so the
  `/etc/xdg` copy was never opened. A `systemd.user.tmpfiles` `L` rule
  (not `L+`) links `~/.config/xfce4/helpers.rc`; a real file wins.
- **Not broken, though suspected:** `Ctrl+Alt+Delete` itself, and the `-m`
  argument shared by the four dmenu commands — `spawn()` rewrites `dmenumon`
  for all of them, so menus follow the focused monitor.

### By running binaries this repository did not build

`programs.nix-ld` was already on and answering `/lib64/ld-linux-x86-64.so.2`
(`~/.opencode/bin/opencode`, libc-only, always worked). nix-ld hands a
program only the libraries it is told to; the stock list is libc, libstdc++,
zlib, openssl, curl, systemd.

| Program | Died on | Really needed | Where |
|---|---|---|---|
| a Tauri app (old Artix build) | `libgdk-3.so.0` | gtk3, webkitgtk_4_1, libsoup_3 | `programs.nix-ld.libraries` |
| UPBGE | `libX11.so.6`, `libSM.so.6` | the X11 set, GL, pulse, wayland | same |
| a Flutter AppImage | `libepoxy.so.0` | libepoxy | `programs.appimage.package` — **not** nix-ld: `appimage-run` has its own FHS sandbox |

Both lists live in `nix/module.nix` and cost **238 KiB** of closure; the
desktop already drags in the same GTK/X11/webkit. Listing *direct*
dependencies is enough — anything reached through nix-ld carries its own
RUNPATH. None of this reverses decision 4: nothing here compiles.

### By looking in `$HOME` — configuration that existed nowhere else

The pattern to watch: anything the reference machine has in `~/.config`
and the repository does not.

- `tmux/tmux.conf` — Tokyo Night Moon, `C-Space`, vi copy-mode via xclip,
  Alt navigation — existed in **no branch**. `programs.tmux` now.
- `thunar/uca.xml` — **Thunar ships no "Open Terminal Here"**; it is a custom
  action, and the only copy was in `~/.config/Thunar/`. Now
  `/etc/xdg/Thunar/uca.xml`: Thunar uses `xfce_resource_lookup`, which walks
  `XDG_CONFIG_DIRS`, so unlike exo's `helpers.rc` it needs no tmpfiles rule.
  Editing in Thunar's dialog writes the `~/.config` copy, which shadows it.
- The neofetch config was stock; nothing lost.
- Two things went the other way, from the installation into the module as
  defaults: `console.font = "Lat2-Terminus16"` (the built-in console font is
  ASCII, wrong at the first "ç" in Ly) and `autoRepeatDelay/Interval`
  200/35 (a tiling WM is held keys; X's 660 ms default is felt).
- **Drift that will recur:** fcitx5 rewrites `~/.config/fcitx5/profile` at
  runtime; the shipped copy is a seed. It drifts to `DefaultIM=mozc`, which
  routes ABNT2 through the Japanese engine ("keyboard went English").
  Delete the user copy and re-login. No declarative fix short of a read-only
  file and no configtool.

### By asking the machine — 2026-09-16

Every claim above had been checked against the repository. The machine had
stopped being what the repository described.

- **`/etc/nixos` was not a pointer.** A complete flake of its own, pulling
  this repository as `git+file:///home/void/…` locked at `751624e` — three
  commits before the one that moved the host in here — with a nixpkgs three
  days older. Generations 22–24 came from it, and the owner kept editing
  `/etc/nixos/{configuration,home}.nix` directly, because that was the file
  the machine read. Only there: VRR, `nix.gc`, `nix.optimise`, and `gcc
  gnumake pkg-config libpcap python3 vim gh btop`. Ported into the host;
  `nix store diff-closures` against the running system proved two additions
  (`vpl-gpu-rt`, `vrr`) and no removal; `/etc/nixos` is a symlink (decision 7).
- **OBS: "Starting the output failed".** The auto-config wizard picked
  QuickSync H.264; every recording died with `MFX_ERR_NOT_FOUND`.
  `intel-media-driver` is VA-API; QuickSync is a second stack whose GPU
  runtime, `vpl-gpu-rt`, was not installed. The plugin loads and lists the
  encoder regardless. nixpkgs patches `libvpl` to search
  `/run/opengl-driver/lib`, so the package in
  `hardware.graphics.extraPackages` (`nix/laptop.nix`) is the whole fix —
  proven before the switch with `ffmpeg -c:v h264_qsv` and
  `ONEVPL_SEARCH_PATH`: encodes with the runtime, `Device creation failed`
  without.
- **The 180 Hz monitor was showing 60 fps.** Not the mode — X and KMS
  both had DP-1 at 180 — but picom's overlay: a 3840×1080 drawable is
  vsynced to whichever CRTC the server picks, and it picked the panel. A
  root-sized GL window measured 60 swaps/s, a DP-1-sized one 180, and with
  the panel shrunk by one pixel (`--scale-from 1919x1079`) the root-sized
  one jumped to 180 — proof of the tie, and a hack not taken. Decision 8.
- **"The battery says charging and goes down."** True, and not software:
  see the battery paragraph under the reference machine. Ruled out in
  order — the 80 % EC cap (raised to 100, same 50–550 mA), the bar (it
  prints the kernel's `status`), `battery-notify` (it only speaks at Low
  and Critical). Left standing: a 65 % battery in CV taper from 84 %, and
  a charger budget shared with whatever `port0` is powering.
- **FreeSync on DP-1 could not engage, and no option would have made it.**
  `VariableRefresh` on, `_VARIABLE_REFRESH` on the window, nothing
  redirecting it — `VRR_ENABLED = 0` anyway. Xorg's Present page-flips only a
  window covering the **whole root**; with eDP-1 lit that is 3840×1080. Panel
  off, same window: `VRR_ENABLED = 1`. The host ships `vrr on|off`, the only
  lever X11 has. HDR10 is impossible on X11; the link's bpc needs root to
  read (`/sys/kernel/debug/dri/1/i915_display_info`).

### By asking the machine — 2026-09-17

- **"`Super+p` does not work."** It did: driven through dwm itself
  (`xdotool key super+p`, type, Return), `powerprofilesctl get` followed
  every choice, and each one landed in
  `/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference`
  (`power` / `balance_performance` / `performance`). What it lacked was any
  sign of having done it: the profile's only visible trace is the prompt of
  the *next* menu, and a failed `set` went to a stderr dwm sends nowhere —
  the same silence that hid `loginctl` in `dmenu-session`. It says the
  outcome through dunst now (replace-id 9003; battery-notify holds 9001–2),
  the failure at critical urgency. Verified both ways, the second with a
  refusing stub on `PATH`.
- **power-profiles-daemon 0.30 was blind to the battery.** Its
  `state.ini` said `battery_aware=true`, and since 0.20 that is supposed to
  make `balanced` mean `balance_power` on battery. The daemon takes
  `OnBattery` from `org.freedesktop.UPower` — a proxy opened with
  `DO_NOT_AUTO_START`, no `/sys` fallback, and no other path that ever sets
  the intel_pstate driver's `on_battery` (`power-profiles-daemon.c`,
  `upower_source_update`) — and UPower was not installed: the name was not
  even activatable, which is what wireplumber and the browser logged in
  this boot's journal. So `balanced` was `balance_performance` on AC
  (measured) and could not be anything else unplugged.
  `services.upower.enable` in `nix/module.nix`, next to the daemon;
  `diff-closures` against the running system: 45 KiB, the package was
  already in the closure. What UPower adds of its own: a critical action
  20 s after 2 % on battery, `HybridSleep` → `Hibernate` → `PowerOff` in
  order of what logind answers, and this host answers `na` to the first
  two. Its 20/5 % levels are battery-notify's.
- **What the profile can do here.** `PlatformDriver: placeholder`:
  `samsung_galaxybook` is loaded but registers no platform profile on this
  model (`/sys/class/platform-profile/` is empty), so a profile is the EPP
  hint and nothing else — no fan curve, no power limit. `performance` is
  never `Degraded`.

## Locale, fonts, theme

- **Japanese**, `LANGUAGE=ja:en` (so untranslated programs fall to English,
  not the C locale). `ja_JP`, `en_US`, `pt_BR`, `C` generated.
  `specialisation.english` in the module is a whole second system; the
  reference host inverts it (English + `japanese`). No GUI for the locale on
  purpose: `/etc/locale.conf` is a store symlink.
- Interface font **Noto Sans CJK JP**; `noto-fonts` added for a Latin sans;
  `nerd-fonts.symbols-only` for Doom's icons.
- Theme GUI: `lxappearance` (GTK) and `qt6Packages.fcitx5-configtool`. The
  module ships `/etc/xdg/gtk-3.0/settings.ini` — Arc-Dark, Papirus-Dark,
  Adwaita cursors, Noto Sans 11; `~/.config/gtk-3.0/settings.ini` overrides.
  The machine's `TokyoNight-SE` icons and `DeppinWhite-cursors` are personal
  downloads in `~/.local/share/icons`, user state, not packaged.
- Timezone `America/Sao_Paulo`, set by the host.

## The flake's interface

| Output | Use |
|---|---|
| `nixosConfigurations.nixos-btw` | this machine; `sudo nixos-rebuild switch` through the `/etc/nixos` symlink |
| `nixosConfigurations.vm`, `nix run .#vm` | the QEMU host, no disk, no result symlink |
| `packages.{dwm,st,dmenu,slstatus,utils,vm}` | each vendored tool as a derivation; `nix build .#dwm` |
| `checks.*` | those five, the VM, `nixos-btw`, `laptop-module`, `install-template` — the gate |
| `nixosModules.default` / `.laptop` | the desktop / the desktop plus this chipset |
| `templates.laptop` | `nix flake init -t .#laptop`: a complete `/etc/nixos` for another machine |
| `formatter` | `nixfmt-tree`; prefer `nixfmt` on the tracked files |
