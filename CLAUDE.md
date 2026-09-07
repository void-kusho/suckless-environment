# CLAUDE.md — project context

Context for the **`nixos`** branch. `README.md` is the manual; this is the *why*.

## What this is

The X11 suckless desktop — dwm, st, dmenu, slstatus and a C utility suite —
**for NixOS**, declaratively. Sibling branches: `guix` (the same desktop on
GNU Guix), `origin/artix` (the imperative Arch/Artix build, and the machine
this all targets). `guix-wayland` is an abandoned dwl port.

Two standing constraints:

* **Emacs (Doom) is the editor.** No Neovim, no Helix, no Yazi.
* **Minimal.** One entry point per concern, nothing in the system
  configuration that `nix shell` can provide per project.

## The reference machine

Read live, 2026-09-05. Every parity claim is checked against **this**.

```
Intel i5-1135G7 (TigerLake-LP), 8 threads, 16 GiB, NVMe
Iris Xe Graphics                          [8086:9a49]
Intel Wi-Fi 6 AX201                       [8086:a0f0]
Intel Bluetooth 9460/9560 Jefferson Peak  [8087:0aaa]
Intel HD Audio, 500 series                [8086:a0c8]
BAT1 · intel_backlight · keyboard br/abnt2
eDP-1 1920x1080@60 at 0x0 ; DP-1 1920x1080@180 at 1920x0 (primary)
```

The partition table used to be recorded here too. It is not any more, and
neither is it in the flake: the machine is being reinstalled, every UUID
changes with the format, and a stale UUID in a repository is a trap that
looks like documentation. Partitions belong to the `hardware-configuration.nix`
that `nixos-generate-config` writes on the installed system.

The three PCI IDs above are the reason `hardware.enableRedistributableFirmware`
is not optional here -- see below.

**Parity is byte-identical**: `dwm/config.h`, `st/config.h`,
`dmenu/config.h`, `slstatus/config.h`, `dunst/dunstrc`, `fcitx5/profile` and
`fcitx5/config` all match `origin/artix` exactly. Unlike the `guix` branch,
nothing here had to diverge — nixpkgs carries every font and tool the Arch
build uses.

## What was broken, and how it was found

Nix is runnable here even without a system install: there is a working
`nix` inside `~/.nix-portable/store`, and it runs under that bundle's own
`bwrap`. That makes `nix eval`, `nix build` and `nix flake check` available,
which is how all of the following came out — none of it is visible by
reading.

* **`hosts/laptop.nix` could not build at all.** It set
  `services.flatpak.enable` with no portal, and NixOS asserts on exactly
  that: *"To use Flatpak you must enable XDG Desktop Portals"*. The host was
  never in `nixosConfigurations`, so nothing ever evaluated it. It is now a
  complete host — real UUIDs, systemd-boot on the existing ESP, the Intel
  platform bits — and it is wired into the flake, so `nix flake check`
  covers it.
* **Three runtime dependencies had no provider.** Extracted from what the
  session actually invokes, then matched against the *effective*
  `systemPackages` (189 entries, including everything NixOS's own modules
  add) rather than the list in `module.nix`:
  - `pamixer` — `slstatus/config.h:76` shells out to it; the volume segment
    of the bar was dead.
  - `libnotify` — `battery-notify` and `brightness-notify` call
    `notify-send`, which is not part of the `dunst` daemon.
  - `gtk3` — `dmenu_run_desktop` pipes into `gtk-launch`, so `Super+d`
    listed applications and launched none.
  `xrandr` and `procps`, also suspected, turned out to come from NixOS's own
  `services.xserver` module.
* **Thunar was half-configured.** It was a bare package in `systemPackages`,
  which gives a Thunar with no thumbnails, no trash and no removable media.
  It now goes through `programs.thunar` with `services.gvfs` and
  `services.tumbler` — the module is what registers its D-Bus services.
* **nixpkgs was pinned 239 days back**, on a release that had gone end of
  life. Moving to `nixos-26.05` surfaced six renames and removals that the
  stale pin was hiding: `noto-fonts-emoji` → `noto-fonts-color-emoji`,
  `poppler_utils` → `poppler-utils`, `neofetch` removed entirely, the whole
  `xorg.*` set deprecated in favour of top-level `libx11` &c.,
  `xfce.thunar-{archive-plugin,volman}` and `xfce.exo` moved to top level,
  and `pkgs.system` → `pkgs.stdenv.hostPlatform.system`. Both hosts now
  evaluate with zero warnings.

## What booting it found that reading it could not

`nix flake check` was green through every one of the following. All four
came out of `pkgs.testers.runNixOSTest`: a headless VM that logs in on a
TTY, runs `startx`, and then asserts on the live session. Building a
configuration proves it evaluates; only booting proves it runs.

* **The store shipped binaries compiled on Artix.** `src = ../dwm` copies the
  *working tree*, and every vendored Makefile builds in place, so a `dwm`
  left over from a `make` on this machine was copied into the store beside
  its sources. GNU make then found the target newer than its prerequisites,
  skipped the compile, and `make install` installed the foreign binary. It
  asks for `/lib64/ld-linux-x86-64.so.2`; NixOS answers with a stub that
  refuses. The session died at `exec dwm` with *"Could not start dynamically
  linked executable"* — dwm, slstatus and battery-notify all of them, and
  `utils/brightness-notify/brightness-notify` was committed to git, so a
  clean clone was poisoned too.

  Three layers now: `preBuild = "make clean"` in `nix/lib.nix` (every
  vendored Makefile has a `clean`, and none of them touches `config.h`), a
  `postFixup` that fails the build if any installed binary asks for an
  interpreter outside the store, and `.gitignore` entries for all eleven
  build products. The committed binary is gone.
* **fcitx5 and mozc had never worked.** `i18n.inputMethod.type` was set
  without `enable`, and the pair replaced the old `enabled = "fcitx5"`
  string: `type` alone installs nothing and exports none of
  `GTK_IM_MODULE` / `QT_IM_MODULE` / `XMODIFIERS`. There was no `fcitx5`
  binary on the system at all, and the launcher called `${pkgs.fcitx5}` —
  the bare package, without mozc — rather than
  `config.i18n.inputMethod.package`. `mozc_server` runs in the session now.
* **The launcher's idempotency guard was a no-op for most of it.**
  `pgrep -x "${1##*/}"` matches a process *name*, and a package built with
  makeWrapper runs as `.dunst-wrapped` — with `comm` capped at 15 characters,
  flameshot is `.flameshot-wrap`. Four of the six daemons are wrapped, so the
  guard never matched any of them. It matches the full store path now; the
  wrapper keeps `argv[0]`, so the path is still in the cmdline. This was
  only visible in a `ps` taken inside a running session.
* **No firmware at all.** A hand-written hardware block does not import
  `installer/scan/not-detected.nix`, which is where `nixos-generate-config`
  turns `hardware.enableRedistributableFirmware` on. The `firmware`
  derivation in the closure measured **5.2 KiB** — an empty merge directory.
  On this machine that is no WiFi (AX201 iwlwifi), no bluetooth (Jefferson
  Peak `ibt-*`) and no Iris Xe GuC/HuC. It is 808.6 MiB now, with the
  `iwlwifi-QuZ-a0-*.ucode` this adapter loads.

Smaller, from the same session: the TTYs had no keymap and stayed on US
while X had br/abnt2 — and with `startx` as the login flow, the password
prompt is a TTY (`console.keyMap = "br-abnt2"`). `blueman` was a bare
package with no `services.blueman`, so it could not pair or trust anything.
udisks2 classifies a fixed second drive as *system internal*, whose polkit
action is `auth_admin_keep`, so mounting the HD from Thunar asked for a
password on every login; a polkit rule now lets `wheel` do it silently.

## Two things that made a working VM look broken

Both were reported as "the flake did not work", and neither is a flake
problem:

* **No wallpaper, anywhere.** `nix/module.nix` delegated it to
  `~/.config/suckless/autostart.sh` — a file nothing in this repository ever
  created, and which does not exist on the reference machine either (its
  `dwm-start` hardcodes `feh`). Every fresh install came up on a bare root
  window. The image is vendored in `wallpapers/` now and painted by
  `programs.suckless-environment.wallpaper`, before the autostart hook runs
  so a hook can still override it.
* **Every keybinding was swallowed by the host.** The guest's MODKEY is Super
  and so is the host's dwm, and QEMU's GTK display does not grab the keyboard
  by default: `Super+Return` opened a terminal on the *host*. The VM was
  fine; nothing in it could be reached. `hosts/vm.nix` now passes
  `-display gtk,grab-on-hover=on`.

The VM also boots straight into dwm (autologin + `startx` from
`loginShellInit`): a throwaway host that makes you type a password proves
nothing, and `/etc/profile` sources `set-environment` before that hook, so
PATH is already correct when X starts.

## What driving the installed session found

Three failures reported from the reference machine — the session menu did
nothing, and Thunar could not open a terminal. All three were found by
sending synthetic keys into the live dwm with `xdotool` and reading what
the session actually spawned; none of them is visible in a build.

* **`loginctl poweroff` and `loginctl reboot` do not exist.** They are
  *elogind* verbs — real on `origin/artix`, where these `.c` files come
  from, and absent from systemd's loginctl, which knows only session, user
  and seat commands. `exec_detach` runs them in a detached child whose
  stderr goes nowhere, so "Unknown command verb" was never printed and the
  menu entry looked inert. `dmenu-session` calls `systemctl` now; logind
  answers `CanPowerOff` and `CanReboot` with "yes" for an active local
  session, so no password is involved either way.
* **`exec_wait` raced the SIGCHLD handler it installs.** `sigchld_handler`
  reaps *every* child with `waitpid(-1, WNOHANG)`, so for anything that
  exits as fast as a `pgrep` it won the race, and `exec_wait`'s own
  `waitpid` then failed with ECHILD leaving `status` uninitialized. The one
  caller that reads the value is the "is a lock screen already up?" guard
  in `action_lock`, which therefore skipped locking whenever the stack
  garbage happened to be zero. SIGCHLD is blocked around the fork/wait now,
  and restored in the child before exec.
* **Thunar could not run anything in a terminal, ever.** exo 4.20 hands
  "run this in the preferred terminal" to `xfce4-mime-helper`, which ships
  only in `xfce4-settings` — a 1.5 GiB closure, so it is deliberately not
  installed. Without it exo takes a fallback path that spawns
  `<binary> "<the entire command line as one argv entry>"`: st reads that
  string as argv[0] and dies with *"child exited with status 1"*, which is
  what the error dialog was reporting. `st-exo-helper` in `nix/module.nix`
  turns that one argument back into `st -e sh -c`.

  The same fallback explains two dead entries in the old `helpers.rc`. It
  resolves values with `g_find_program_in_path`, so they are *binary
  names*, not desktop-file ids: `WebBrowser=brave-browser` never matched
  anything (the binary is `brave`). And it reads `g_get_user_config_dir()`
  and nothing else — not `XDG_CONFIG_DIRS`, so the `/etc/xdg` copy the
  module installed was never opened by anyone. A `systemd.user.tmpfiles`
  rule links `~/.config/xfce4/helpers.rc` at it; `L` (not `L+`) leaves a
  real file alone, which is how a user still overrides it.

What was *not* broken, having been suspected: the `Ctrl+Alt+Delete` binding
itself, which spawns `dmenu-session` reliably, and the `-m` argument shared
by the four dmenu commands — `spawn()` rewrites `dmenumon` for all of them,
so the menus do follow the focused monitor.

## Running software this repository did not build

Three of the owner's own programs would not start — a Tauri app built on the
old Artix install, an UPBGE build, and a Flutter AppImage. None of it was a
loader problem. `programs.nix-ld` was already on and already answering
`/lib64/ld-linux-x86-64.so.2`, which is why `~/.opencode/bin/opencode` — a
foreign ELF that needs nothing past libc — ran fine all along.

nix-ld hands a program only the libraries it is *told* to, and the stock list
is libc, libstdc++, zlib, openssl, curl and systemd. So all three stopped one
step past the loader, each naming the first thing it wanted:

| program        | died on                    | really needed                     |
| -------------- | -------------------------- | --------------------------------- |
| the Tauri app  | `libgdk-3.so.0`            | gtk3, webkitgtk_4_1, libsoup_3     |
| UPBGE          | `libX11.so.6`, `libSM.so.6`| the X11 set, GL, pulse, wayland   |
| the AppImage   | `libepoxy.so.0`            | libepoxy                          |

The AppImage is a *different mechanism with the same shape*, and that is the
part worth remembering: `appimage-run` runs inside its own FHS sandbox whose
library set has nothing to do with nix-ld's. The fix for it is
`programs.appimage.package`, not `programs.nix-ld.libraries` — putting
libepoxy in the latter would have changed nothing.

Both lists live in `nix/module.nix` now, and together they cost **238 KiB**
of closure, measured against the same system without them. The desktop is
already GTK and X11 — Thunar, Brave, dunst and lxappearance drag in the same
gtk3, cairo, pango, fontconfig, Xlib, and webkitgtk was in the store too — so
the libraries were paid for either way. Only nix-ld itself is new.

Listing a *direct* dependency is enough. Anything reached through nix-ld
carries its own RUNPATH into the store, so the transitive half resolves
without being named — which is why a list this short covers a 300 MB Blender.

This does not reverse decision 4. Nothing here compiles anything; it lets a
binary that already exists run. `nix shell nixpkgs#gcc` is still how you
build one.

## Timezone, language and theme

None of the three were configured at all, so the system ran in UTC, with
NixOS's stock `en_US.UTF-8` and no GTK theme.

* **The system is Japanese**, with `LANGUAGE=ja:en` so anything without a
  Japanese translation falls back to English rather than to the C locale —
  `LANG` alone does not do that. `ja_JP`, `en_US`, `pt_BR` and `C` are all
  generated, and `specialisation.english` is a whole second system built
  alongside, so switching needs no rebuild.
* The interface font is Noto Sans CJK JP: `noto-fonts` (Latin only) was not
  enough once the UI stopped being English.
* **There is deliberately no GUI for the language.** `/etc/locale.conf` is a
  store symlink, so `localectl set-locale` cannot write to it; on NixOS the
  declarative option is the only honest answer, and pre-generating the
  locales is what makes it cheap.
* The **theme** does get a GUI: `lxappearance` (GTK theme, icons, cursor, UI
  font) and `qt6Packages.fcitx5-configtool` (input methods). The module ships
  `/etc/xdg/gtk-3.0/settings.ini` with Arc-Dark, Papirus-Dark, Adwaita
  cursors and Noto Sans 11 — a user `~/.config/gtk-3.0/settings.ini`, which
  is exactly what lxappearance writes, overrides it.
* `noto-fonts` was added for that interface font: the module previously
  installed only Iosevka, CJK and emoji, so GTK apps had no sans to fall back
  to.
* The reference machine's icon set (`TokyoNight-SE`) and cursors
  (`DeppinWhite-cursors`) are personal downloads in `~/.local/share/icons`.
  They are user state and are not packaged here; they keep working if that
  directory comes along.

## Configuration that was in $HOME and nowhere else

Two of these were only found because they were reported missing, which is the
pattern to watch: anything the reference machine has in `~/.config` and the
repository does not.

* `tmux/tmux.conf` — a substantial config (Tokyo Night Moon, `C-Space`
  prefix, vi copy-mode through xclip, Alt navigation) that existed in **no
  branch**. Now deployed by `programs.tmux`. The `guix` and `artix` branches
  still lack it.
* `wallpapers/sushi_original.png` — see above.
* The neofetch config turned out to be the stock file, with every value at
  its default; nothing had been lost.

## Decisions

1. **Doom Emacs replaces Helix**, and `$DOOMDIR` points into the store via
   `environment.variables.DOOMDIR`. That is strictly better than the seed
   wrapper Helix used: no first-run copy, no drift, nothing to re-seed. The
   cost is that `~/.config/doom` is read-only — edit `doom/` and rebuild.

   Two things `doom doctor` turned up once the config was actually running.
   `doom install` writes `~/.config/doom` from Doom's example templates
   whether or not `$DOOMDIR` is set, and the doctor then reports "two private
   configs" with a message that names the paths in a fixed order and calls the
   *second* ignored — backwards here, because `doom-user-dir` in `lisp/doom.el`
   short-circuits on `$DOOMDIR` and never consults `~/.config/doom`. `doom
   info` prints the directory really in use; that is the one to believe. The
   shadow directory is byte-identical to `static/*.example.el`, so removing it
   loses nothing — it is user state, deleted by hand, never by a rebuild.

   And `nerd-icons.el` asks for the family **"Symbols Nerd Font Mono"** by
   name, which a patched Iosevka does not answer to — `nerd-fonts.iosevka`
   installs "Iosevka Nerd Font". Every icon in the modeline, dashboard and
   dired was tofu until `nerd-fonts.symbols-only` joined `fonts.packages`.
   The remaining doctor warnings are decision 4 working as intended: no
   `rustc`, no `zig`, no `python` on the system.
2. **The repository describes a desktop and a chipset, never a disk.**
   `hosts/laptop.nix` used to be a complete host carrying the machine's real
   UUIDs, systemd-boot and the user account. It is now `nix/laptop.nix`,
   exported as `nixosModules.laptop`: Intel platform facts and the desktop
   toggle, with no `fileSystems`, no `swapDevices`, no `boot.loader`, no
   `users.users` and no `stateVersion`. Those are the installation's, and the
   installation is done by hand.

   This reverses the previous decision, whose reasoning was sound: a template
   that cannot be evaluated is a template nobody checks, and that is how the
   Flatpak assertion survived. The concern is met a different way now --
   `checks.laptop-module` builds the module against a throwaway root declared
   inside the check, so the fake disk lives in the gate and never in the
   module. `nix flake check` still fails if the module stops evaluating.
3. **`hosts/minimal.nix` and `default.nix` are gone.** Once laptop.nix
   covered the machine, minimal.nix was a second template of the same thing, and `default.nix`
   duplicated `nixosModules.default` for non-flake users. One interface.
4. **Toolchains stay out of the system**: `nix shell nixpkgs#rust-analyzer`.
5. **Ly is the display manager, and the module turns it on.** It was only
   ever *detected* before -- `displayManagerEnabled` knew how to react to it,
   but nothing enabled it, and the one line that would have was commented out
   in `hosts/laptop.nix`. It is `mkDefault true` in `nix/module.nix` now,
   themed with the Tokyo Night palette. Ly takes `0xAARRGGBB` where the top
   byte is an *attribute*, not alpha: `0x01` is bold, which is what the
   upstream `error_fg = 0x01FF0000` means.

   Its clock is deliberately ASCII. Ly draws on the Linux console, whose font
   has no CJK, so matching slstatus' `年月日` would render as tofu. For the
   same reason the greeter is the one place where the **console** keymap
   matters rather than X's -- see `console.keyMap` above.

   `hosts/vm.nix` sets it to `false`: the test VM's whole point is booting
   straight into dwm, and the module hands `services.xserver.autorun` and the
   startx pseudo-DM back when it goes off.

## Using the flake as the interface

`flake.nix` is the whole API, and every one of these is meant to be used:

* `nix run .#vm` — boot the test host in QEMU, no disk, no result symlink.
  `hosts/vm.nix` is the only complete system left here; a VM owns its virtual
  disk, so declaring one costs nothing and strands nobody.
* `nix flake check` — builds all five tools, the VM, and `nixosModules.laptop`
  against a throwaway root. The gate.
* `nix fmt` — `nixfmt-tree`. It walks far more than this repository and exits
  non-zero on unrelated trees; `nixfmt` on the six `.nix` files is the honest
  check.
* `nixosModules.default` — the desktop alone, for another machine.
* `nixosModules.laptop` — the desktop plus this chipset. Combine it with the
  generated `hardware-configuration.nix` in `/etc/nixos` and rebuild with
  `sudo nixos-rebuild switch --flake /etc/nixos#laptop`. README has the
  twelve-line `flake.nix` that joins them.

## Conventions

* Comments and docs in **English**; conversation with the owner in
  **Portuguese**.
* Tokyo Night: `#1a1b26` `#a9b1d6` `#414868` `#7aa2f7` `#565f89` `#f7768e`
  `#9ece6a` `#e0af68` `#bb9af7` `#7dcfff`.
* Machine-specific session state lives in `~/.config/suckless/autostart.sh`,
  never in the flake.
* `utils/` on this branch carries **no** `config.h` — the backends
  (`powerprofilesctl`, `betterlockscreen`, `systemctl`) are in the `.c`
  files, which is why `services.power-profiles-daemon` is enabled. Do not
  copy the `guix` branch's generated `config.h` here; `.gitignore` blocks
  it. Those hardcoded backends are also where this branch diverges from
  `origin/artix`: the same line that reads `systemctl` here reads
  `loginctl` there, because elogind and systemd disagree about which of
  them owns the power verbs.
* Nothing that fails `nix flake check` reaches `nixos-rebuild switch`.
