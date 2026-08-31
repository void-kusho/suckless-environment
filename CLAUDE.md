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

Read live, 2026-08-29. Every parity claim is checked against **this**.

```
artix-btw — Intel i5-1135G7 (TigerLake), Iris Xe, 16 GiB
nvme0n1  p1 vfat ESP  D5A8-D954                            -> /boot/efi
         p2 swap SWAP 4697d7c2-e298-4e46-b97d-197fd4a96039
         p3 ext4 ROOT 6852d602-61ce-43fb-9c28-91ecf89adccc -> /
BAT1 · intel_backlight · Intel WiFi · keyboard br/abnt2
eDP-1 1920x1080@60 at 0x0 ; DP-1 1920x1080@180 at 1920x0 (primary)
```

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
2. **`hosts/laptop.nix` is a real host, not a template.** A template that
   cannot be evaluated is a template nobody checks; that is precisely how the
   Flatpak assertion survived.
3. **`hosts/minimal.nix` and `default.nix` are gone.** With laptop.nix real,
   minimal.nix was a second template of the same thing, and `default.nix`
   duplicated `nixosModules.default` for non-flake users. One interface.
4. **Toolchains stay out of the system**: `nix shell nixpkgs#rust-analyzer`.

## Using the flake as the interface

`flake.nix` is the whole API, and every one of these is meant to be used:

* `nix run .#vm` — boot the test host in QEMU, no disk, no result symlink.
* `nix flake check` — builds both hosts and all five tools. The gate.
* `nix fmt` — `nixfmt-tree`.
* `nixosModules.default`, `overlays.default` — for other machines.
* `sudo nixos-rebuild switch --flake .#laptop`.

## Conventions

* Comments and docs in **English**; conversation with the owner in
  **Portuguese**.
* Tokyo Night: `#1a1b26` `#a9b1d6` `#414868` `#7aa2f7` `#565f89` `#f7768e`
  `#9ece6a` `#e0af68` `#bb9af7` `#7dcfff`.
* Machine-specific session state lives in `~/.config/suckless/autostart.sh`,
  never in the flake.
* `utils/` on this branch carries **no** `config.h` — the backends
  (`powerprofilesctl`, `betterlockscreen`, `loginctl`) are in the `.c` files,
  which is why `services.power-profiles-daemon` is enabled. Do not copy the
  `guix` branch's generated `config.h` here; `.gitignore` blocks it.
* Nothing that fails `nix flake check` reaches `nixos-rebuild switch`.
