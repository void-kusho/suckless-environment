# suckless-environment

A minimal X11 desktop for **NixOS**: dwm, st, dmenu and slstatus built from
the sources in this repository, a small suite of C utilities, and Doom Emacs.

The whole desktop sits behind one toggle:

```nix
programs.suckless-environment.enable = true;
```

## Try it in QEMU

No installation, no disk, nothing to clean up afterwards:

```bash
nix run .#vm
```

That builds `hosts/vm.nix` and boots it in QEMU **straight into dwm** — no
login prompt, no `startx`. The wallpaper, the bar, the keybindings and the
session daemons are all there; it is the desktop, not a shell.

**Move the pointer onto the window before pressing anything.** The guest's
MODKEY is Super and so is the host's, so without an input grab every
`Super+…` is taken by the host window manager and the guest looks like it has
no keybindings. `hosts/vm.nix` passes `-display gtk,grab-on-hover=on`, which
grabs as soon as the pointer is over the window; **Ctrl+Alt+G** toggles it by
hand and **Ctrl+Alt+F** goes full screen.

The VM is disposable and shares the host's `/nix/store`, so it costs a build,
not a download of a disk image. What it cannot tell you: backlight, WiFi
firmware, VA-API, and the dual-monitor layout — those need real hardware.

Two knobs, in `hosts/vm.nix`: `virtualisation.memorySize` and
`virtualisation.graphics` (set it to `false` for a serial-only console).

The wallpaper comes from `programs.suckless-environment.wallpaper`, which
defaults to `wallpapers/sushi_original.png` in this repository. It used to be
left to `~/.config/suckless/autostart.sh` — a file nothing ever created, so
every fresh install came up on a bare root window.

## Check it

```bash
nix flake check     # both hosts evaluate and build, all five tools compile
nix fmt             # format the Nix
```

`nix flake check` is the gate: it builds `hosts/laptop.nix`,
`hosts/vm.nix` and every package. Nothing that fails it should reach
`nixos-rebuild switch`.

## Install it

### On this machine

`hosts/laptop.nix` is a complete, evaluable host — the real UUIDs, the EFI
loader, the Intel platform bits:

```bash
sudo nixos-rebuild switch --flake .#laptop
```

Run `nixos-generate-config` on the real install first and reconcile its
hardware block with the one in `hosts/laptop.nix`: the kernel-module list
there is the usual Intel/NVMe set, not a reading of your machine.

### On another machine

Import the module from your own configuration:

```nix
{
  inputs.suckless-env.url = "github:void-kusho/suckless-environment/nixos";

  # in your nixosSystem modules:
  imports = [ inputs.suckless-env.nixosModules.default ];
  programs.suckless-environment.enable = true;
  programs.suckless-environment.extraPackages = with pkgs; [ discord steam ];
}
```

### Doom Emacs

`$DOOMDIR` points into the Nix store — `doom/` in this repository is the
configuration, deployed by `environment.variables.DOOMDIR`, so there is
nothing to seed and nothing to drift. Doom's own mutable state stays in
`~/.config/emacs` and `~/.local/share/doom`.

The framework is a git checkout and stays imperative:

```bash
git clone https://github.com/doomemacs/core ~/.config/emacs
~/.config/emacs/bin/doom install
```

Because `$DOOMDIR` is read-only, edit `doom/` here and rebuild rather than
editing `~/.config/doom`.

The module installs what `doom doctor` asks for. Language servers and
compilers are deliberately **not** in the system configuration — use
`nix shell nixpkgs#rust-analyzer` in the project that needs one.

## Language, timezone and configuring things

The timezone is `America/Sao_Paulo`. **The system is in Japanese**, falling
back to English wherever a program has no Japanese translation — that is
`LANGUAGE=ja:en`, gettext's priority list. `LANG` alone would leave
untranslated programs in the C locale rather than in English.

`LC_TIME` follows, which also matches the bar: slstatus already prints 年月日.

### Switching between Japanese and English

Three different things, and only the last needs a rebuild:

**Typing Japanese** is the input method, not the system language. fcitx5 +
mozc is configured and toggles with a hotkey — nothing to switch, nothing to
rebuild. `fcitx5-configtool` is the GUI for its keys and engines.

**One session in English** — no rebuild, no configuration change:

```bash
LANG=en_US.UTF-8 startx
```

`ja_JP.UTF-8`, `en_US.UTF-8`, `pt_BR.UTF-8` and `C.UTF-8` are all generated up
front, so the locale is simply there.

**The whole system in English**, switchable without a rebuild. The module
builds a second complete system as a *specialisation*; both sit in the store
at the same time:

```bash
# pick "english" in the boot menu, or, from a running system:
sudo /run/current-system/specialisation/english/bin/switch-to-configuration switch
```

Then log out and back in — a running session keeps the environment it started
with. To make English the default instead, set `i18n.defaultLocale` in your
host and rebuild.

**There is no GUI or TUI that changes the system locale on NixOS, and that is
not an omission**: `/etc/locale.conf` is a symlink into the store, so
`localectl set-locale` cannot write to it. The specialisation is the
NixOS-shaped answer.

The interface font is **Noto Sans CJK JP**, which covers Latin and Japanese in
one family — a Japanese-first desktop needs that everywhere, not only in the
tag names.

### Configuring the rest

TUI where one exists, GUI only where it does not:

| | Tool | |
|---|---|---|
| Wifi | `wifitui` | TUI, the same version as the reference machine |
| Network (wired, VPN) | `nmtui` | TUI, ships with NetworkManager |
| Audio | `pulsemixer` | TUI: devices, volume, default sink |
| Bluetooth | `bluetuith` | TUI: pairing (`blueman-manager` is the GUI) |
| Input methods | `fcitx5-configtool` | GUI: engines and switch keys |
| Theme | `lxappearance` | GUI: GTK theme, icons, cursor, UI font |
| Monitors | `arandr` | GUI: writes an `xrandr` line for `autostart.sh` |
| CPU profile | `Super+p` | `dmenu-cpupower` |

tmux comes with the reference machine's configuration — Tokyo Night Moon,
`C-Space` as the prefix, vi copy-mode piping through `xclip`, `Alt+hjkl` for
panes and `Alt+1..9` for windows. It is deployed as `/etc/tmux.conf`, so its
own `bind r` (which reloads `$HOME/.config/tmux/tmux.conf`) does nothing here:
like `$DOOMDIR`, the config is read-only and changes come from a rebuild.

`lxappearance` writes `~/.config/gtk-3.0/settings.ini`, which overrides the
system defaults the module ships (Arc-Dark, Papirus-Dark, Adwaita cursors,
Noto Sans 11). Personal icon and cursor sets in `~/.local/share/icons` keep
working untouched — that is user state, not system configuration.

Mouse and touchpad behaviour has no TUI worth the name; it is
`services.libinput` in your host, or `xinput` at runtime.

## Layout

```
flake.nix           the interface: module, packages, both hosts, checks, the VM
nix/module.nix      the whole desktop behind programs.suckless-environment
nix/packages.nix    one derivation per vendored tool
nix/lib.nix         the shared builder they all use
hosts/laptop.nix    the real machine — hardware facts only
hosts/vm.nix        the disposable QEMU host
dwm/ st/ dmenu/ slstatus/   vendored sources, patches and config.h
utils/              the C utilities
doom/               $DOOMDIR: init.el, config.el, packages.el
bash/ dunst/ fcitx5/ picom/ tmux/   deployed by the module
```

Machine-specific session setup — monitor layout, wallpaper, pointer warp —
goes in `~/.config/suckless/autostart.sh`, which the dwm launcher sources.
It is deliberately not in the flake: it is state, not configuration.

## Both login flows

* **A display manager** (Ly, SDDM, greetd, …) sees dwm as `none+dwm`, which
  the module sets as the default session.
* **No display manager**: the module turns on NixOS's `startx` pseudo-DM, so
  you log into a TTY and run `startx`. This is the default.

## Keybindings

MODKEY is **Super**.

| Key | Action |
|-----|--------|
| `Super+d` / `Super+Return` | dmenu / st |
| `Super+e` / `Super+Shift+b` | Thunar / Brave |
| `Super+v` / `Super+p` | clipboard history / power profile |
| `Super+j` `Super+k` | focus down / up the stack |
| `Super+i` | grow the master area |
| `Super+h` `Super+l` | shrink / widen master |
| `Super+z` | zoom to master |
| `Super+b` | toggle the bar |
| `Super+q` | close window |
| `Super+t` `Super+f` `Super+m` `Super+r` `Super+Shift+r` | Spiral / Title / Float / Monocle / Dwindle |
| `Super+space` / `Super+Shift+space` | cycle layout / toggle floating |
| `Super+[1-9]` | view tag (`Ctrl` toggles, `Shift` sends the window) |
| `Super+0` / `Super+Shift+0` | view / tag all |
| `Super+,` `Super+.` | focus the monitor left / right (`Shift` sends) |
| `Super+Tab` | last tag |
| `Print` | flameshot |
| `Ctrl+Alt+Delete` | session menu (lock / logout / reboot / shutdown) |
| `Super+Shift+q` | quit dwm |

## Utilities (`utils/`)

Plain POSIX C, no configuration file — the backends are in the sources.

- **battery-notify** — low/critical notifications, 30 s tick
- **brightness-notify** — brightnessctl plus an OSD notification
- **dmenu-clipd** / **dmenu-clip** — clipboard daemon and history browser
- **dmenu-cpupower** — power profile selector, through `powerprofilesctl`
- **dmenu-session** — lock / logout / reboot / shutdown, through
  `betterlockscreen` and `loginctl`

## Contributing

`CLAUDE.md` holds the project context: the reference machine, the parity
matrix, and the reasoning behind these decisions.

## License

See the LICENSE files in each subdirectory (dwm/, st/, dmenu/, slstatus/,
utils/).
