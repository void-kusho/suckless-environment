# CLAUDE.md — project context

Context for the **`guix`** branch. `README.md` is the manual; this is the *why*.

## What this is

The X11 suckless desktop — dwm, st, dmenu, slstatus and a C utility suite —
**for GNU Guix**, declaratively. The Arch/Artix build lives on the `artix`
branch; this branch carries no install script, because on Guix
`guix system reconfigure` is the installer. The Wayland attempt lives on
`guix-wayland` and is abandoned:
dwl ships no status bar, wlroots needs a DRM stack VirtualBox will not give,
and reaching parity meant carrying three compositor patches.

Two standing constraints:

* **Emacs (Doom) is the editor.** No Neovim, no Helix, no Yazi.
* **Minimal.** One list, one entry point per concern, nothing in the system
  configuration that `guix shell` can provide per project.

## The reference machine

Read live, 2026-08-29. Every parity claim is checked against **this**.

```
artix-btw — Artix Linux, OpenRC, kernel 6.18-lts, display manager Ly
Intel i5-1135G7 (TigerLake), Iris Xe, 16 GiB
nvme0n1  p1 vfat ESP  D5A8-D954                            -> /boot/efi
         p2 swap SWAP 4697d7c2-e298-4e46-b97d-197fd4a96039
         p3 ext4 ROOT 6852d602-61ce-43fb-9c28-91ecf89adccc -> /
BAT1 · intel_backlight · Intel WiFi · keyboard br/abnt2
eDP-1 1920x1080@60 at 0x0 ; DP-1 1920x1080@180 at 1920x0 (primary)
Fonts: st Iosevka Nerd Font Mono:16 · bar/dmenu Iosevka Nerd Font:14 · dunst 11
```

**Parity status: the desktop is already there.** `st/config.h`,
`dmenu/config.h`, `slstatus/config.h`, `dunst/dunstrc` and
`fcitx5/*` are byte-identical to what runs; `dwm/config.h` differs only by
the Flatpak browser command and an added `Super+Shift+e` for Emacs. What was
broken was the Guix plumbing, not the desktop.

## Guix facts worth not re-deriving

Each of these cost real effort, and several already cost this repo a commit.

* **Package names, verified against the full index**
  (`guix.gnu.org/packages.json`, 32 076 packages — far cheaper than one
  search per name). Absent from Guix: `betterlockscreen` (hence `slock`),
  `ly` (hence SLiM), `power-profiles-daemon` and `linux-tools` (hence
  `cpupower`), `mozc` (hence `fcitx5-anthy`), `resvg`, `p7zip` (it is
  `7zip`), and any Nerd-patched Iosevka (hence `font-iosevka` +
  `font-nerd-symbols`).
* **Variable names drift, package names do not.** `make` is the variable
  `gnu-make`, `pkg-config` is `%pkg-config`, `gcc-toolchain` is
  `gcc-toolchain-15`, `(gnu packages wm)` became `window-management`. Hence
  `specification->package` by string everywhere — and never wrapped in a
  `catch`, which silently produced a desktop with no terminal.
* **`home-environment` has no `shell` and no `files` field**, and
  `%base-packages` is system-only. Files go through
  `home-xdg-configuration-files-service-type`; the module is
  `(gnu home services shells)`, plural.
* **`%desktop-services` already provides** elogind, dbus, polkit, udisks,
  upower, NetworkManager and udev. Declaring any of them again is a duplicate
  service error. Only GDM has to be deleted, because SLiM replaces it.
* **udev rules must extend the existing service** (`udev-rules-service`).
  Writing to `/etc/udev/rules.d` via `special-files-service-type` does
  nothing — Guix's udev does not read that path — and setting
  `(rules ...)` wholesale discards every default rule.
* **`realtime` is not in `%base-groups`**; naming it fails activation. The
  machine's `uucp` group (serial, for the Arduino toolchain) is `dialout`.
* **`abnt2` is an xkb MODEL**, not a variant and not an option — it is under
  `! model` in `xkb/rules/base.lst`, and `br` has no `abnt2` variant.
* **SLiM finds sessions from `.desktop` files** in `share/xsessions`; nothing
  in this repo provided one until `suckless-session`.
* **Guix's SLiM does not source `~/.xprofile`** — that is an Arch/Debian
  display-manager convention. On this branch the file is gone and its three
  input-method exports live in `dwm-start`, which is the only thing certain to
  run for a graphical login.
* **slock needs `screen-locker-service-type`** to be setuid, or it cannot
  authenticate.
* **nonguix substitutes must be authorised on the building machine**
  (`guix archive --authorize`), or reconfigure compiles the kernel and
  `linux-firmware` from source.

## Decisions

1. **`guix/system.scm` is one self-contained file.** A module split needs
   `-L .` on every call and already broke `reconfigure` once; it was
   reverted. One file that works beats a tidy tree.
2. **No install script.** `guix system reconfigure` *is* the install, and it
   covers every step the old `install.sh` did: packages, the backlight udev
   rule (`udev-rules-service`), the keyboard (`xorg-configuration`), services,
   groups, building the five tools, and the dotfiles (`guix home`). Removing
   it also removed `udev/`, `xorg/` and `.xprofile`, which existed only to
   feed it.
3. **SLiM**, since Guix has no Ly.
4. **Toolchains stay out of the system**: `guix shell rust rust-analyzer`.

## Conventions

* Comments and docs in **English**; conversation with the owner in
  **Portuguese**.
* Tokyo Night: `#1a1b26` `#a9b1d6` `#414868` `#7aa2f7` `#565f89` `#f7768e`
  `#9ece6a` `#e0af68` `#bb9af7` `#7dcfff`.
* `utils/` stays plain POSIX C with a per-tool `config.h`.
* Test in `guix system vm` before `guix system reconfigure` on the laptop.

## Runtime dependencies, checked rather than assumed

Every command `dwm-start`, `dwm/config.h` and the utils actually invoke was
extracted and matched against the package list. Three gaps came out of it:

* **`notify-send` had no provider.** `battery-notify` and `brightness-notify`
  call it directly; `libnotify` was missing, so both would have failed
  silently. Added.
* **PipeWire was started twice.** `dwm-start` launched `pipewire`,
  `pipewire-pulse` and `wireplumber` by hand while `home-pipewire-service-type`
  ran them under Shepherd. The manual lines are gone; Shepherd owns audio.
* **The font family did not exist.** The configs asked for
  `Iosevka Nerd Font` / `Iosevka Nerd Font Mono`, which Guix does not package,
  so the whole desktop would have rendered in the fontconfig default with the
  status glyphs as tofu. They now ask for `Iosevka`. A fontconfig alias was
  written first and then thrown away: dwm (`drw.c`'s nomatches cache), st
  (`x.c`'s frc cache) and Pango each fall back per glyph already, so the file
  bought an indirection and nothing else.

A second pass over the `dmenu/` shell scripts — which the first scan missed,
because it only read `dwm-start`, `config.h` and `utils/*.c` — found two more:

* **`gtk-launch` had no provider.** `dmenu_run_desktop` pipes the selection
  into it, so `Super+d` would have listed applications and launched nothing.
  It comes from `gtk+`. Added.
* **`XDG_DATA_DIRS` was never set for the session.** `dmenu_path_desktop`
  scans `$XDG_DATA_DIRS/applications`, and its built-in default
  (`/usr/local/share:/usr/share`) does not exist on Guix, so the launcher
  would have been empty. `dwm-start` now points it at the Guix profiles.

Verified as already covered: `pgrep`/`pkill` (procps is in
`%base-packages-utils` — checked in the Guix source, not assumed), `loginctl`
(elogind extends the system profile), `stest` (dmenu's own Makefile installs
it), and `powerprofilesctl`, which is never reached because the package forces
`USE_CPUPOWER 1`.

Every patch claimed in the README was checked against the vendored sources by
looking for its signature, not by trusting the filename in `patches/`: all six
dwm, all five dmenu and all six st patches are in fact applied. Two looked
absent at first — `alwayscenter` centres in `manage()` rather than adding a
named symbol, and `desktoponly` ships scripts instead of touching `dmenu.c`.

## The test suite hangs, and it was nearly wired into the build

`make -C utils test` runs `test-util` (10 cases, pure) and then `test-dmenu`,
which calls `dmenu_open()` — that spawns a **real** dmenu and blocks waiting
for a selection. It does not fail; it hangs. An earlier run happened to come
back, which is exactly how this kind of thing hides.

`#:tests? #t` on `suckless-utils` would therefore have hung `guix system
reconfigure` forever instead of failing. The check phase now runs only
`test-util`.

## Two bugs found by actually compiling

Worth remembering, because neither shows up in any syntax check:

* **dwm and dmenu did not build.** This branch replaced the hardcoded
  `FREETYPEINC = /usr/include/freetype2` with
  `pkg-config --variable=includedir freetype2`, which returns `/usr/include`
  — the *parent* of the directory holding `ft2build.h`. Only
  `pkg-config --cflags freetype2` is right, and it is right on Arch and in
  the Guix store alike. st was unaffected because its `config.mk` already
  used `--cflags`. `origin/artix` never had the bug; the running dwm binary
  predates it. All five now compile.
* **`local-file #:recursive?` copied build artefacts into the store.** A
  `make` left in the working tree would have put `dwm/dwm`, the `*.o` files
  and the *generated* `utils/dmenu-*/config.h` into the source derivation,
  so the build would depend on whatever was last compiled by hand.
  `#:select? (git-predicate ...)` fixes it — `.gitignore` already names
  exactly those files, so git is the right authority.

## Open items

Only a real Guix can settle these:

1. **st's terminfo wrap** — `tic` must write into the output, and the binary
   is wrapped so `TERM=st-256color` resolves at runtime.
2. **`slim-configuration` field names**, and whether SLiM lists the dwm
   session from `suckless-session`.
3. **Audio**: `%desktop-services` may carry a system PulseAudio racing
   `home-pipewire-service-type`.
4. **Font family name** — `fc-list | grep -i nerd` should show
   `Symbols Nerd Font`.
5. **`git-predicate` in the VM** — it returns #f outside a git checkout, and
   the fallback then copies everything. Clone the repo rather than copying
   the directory.
