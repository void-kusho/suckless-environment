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

`nix flake check` is the gate: it builds every package, `hosts/vm.nix`, and
`nixosModules.laptop` against a throwaway root. Nothing that fails it should
reach `nixos-rebuild switch`.

## Use it

**This repository describes a desktop and a chipset. It never describes a
disk.** There is no partition, no filesystem, no bootloader, no user and no
`stateVersion` anywhere in it — install NixOS however you like, and keep the
`hardware-configuration.nix` that `nixos-generate-config` writes for you in
`/etc/nixos`, where it belongs. Two modules are offered instead:

| | |
|---|---|
| `nixosModules.default` | the desktop, behind `programs.suckless-environment.enable` |
| `nixosModules.laptop` | that, plus the Intel TigerLake hardware this was written on |

### On this machine

`nixosModules.laptop` carries the hardware facts — redistributable firmware
(the AX201 WiFi, the Jefferson Peak bluetooth and the Iris Xe GuC all load
microcode at runtime and are dead without it), Intel microcode, `modesetting`,
the iHD VA-API driver, thermald, fstrim and fwupd. Combine it with your
generated hardware block:

```nix
# /etc/nixos/flake.nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.suckless-env.url = "github:void-kusho/suckless-environment/nixos";
  # Without this, suckless-env drags in its own pinned nixpkgs and you
  # evaluate (and download) two of them.
  inputs.suckless-env.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, suckless-env, ... }: {
    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix   # generated; disks live here, only here
        suckless-env.nixosModules.laptop
        {
          networking.hostName = "kusho";   # letters, digits, - and _ only

          users.users.void = {
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" "video" "input" ];
            # Ly asks for a password and a user without one cannot log in at
            # all. Set it here for the first boot and change it with
            # `passwd`, or drop this line and run `passwd void` as root from
            # a TTY before you ever reach the greeter.
            initialPassword = "change-me";
          };

          system.stateVersion = "26.05";   # the release you installed
        }
      ];
    };
  };
}
```

```bash
# The FIRST rebuild only. A freshly installed NixOS has no flake support
# yet -- nixosModules.laptop turns it on, but that option does not exist
# until the switch it is part of has already happened.
sudo nixos-rebuild switch --flake /etc/nixos#laptop \
  --option extra-experimental-features "nix-command flakes"

# Every rebuild after that:
sudo nixos-rebuild switch --flake /etc/nixos#laptop
```

`video` and `input` are what the backlight udev rules grant brightness
writes to; `wheel` is what the disk-mounting polkit rule keys on.

### On another machine

Take the desktop without the Intel bits:

```nix
imports = [ inputs.suckless-env.nixosModules.default ];
programs.suckless-environment.enable = true;
programs.suckless-environment.extraPackages = with pkgs; [ discord steam ];
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
editing `~/.config/doom`. A rebuild that touches `doom/` gives `$DOOMDIR` a new
store path, so run `doom sync` afterwards whenever `init.el` or `packages.el`
changed — `config.el` alone needs nothing but a restart.

`doom install` creates `~/.config/doom` regardless, filled with Doom's own
example templates. It is dead weight here and worth deleting: `doom-user-dir`
takes `$DOOMDIR` whenever it is set and never looks at `~/.config/doom`.
`doom doctor` does flag the two directories, but its warning prints them in a
fixed order and calls the *second* one ignored, which is backwards for this
setup — `doom info` prints the directory actually in use, and that is the
answer to trust.

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
| Disks | Thunar | click it in the sidebar; udisks2 mounts it |

Secondary drives are **not** declared anywhere here — a second disk is not
part of the desktop. udisks2 mounts them on demand under
`/run/media/$USER/<label>`, and a polkit rule lets `wheel` do it without a
password prompt. udisks2 treats a fixed internal drive as "system internal",
whose polkit action would otherwise ask for authentication on every single
login, unlike a USB stick.

**AppImages run the way they do on any other distribution.**
`programs.appimage` installs `appimage-run` — an FHS sandbox carrying the
`/usr/lib` an AppImage expects to find and NixOS does not have — and `binfmt`
registers it with the kernel. So `chmod +x Foo.AppImage && ./Foo.AppImage`
works from a shell, and double-clicking one in Thunar works too; there is no
`appimage-run` prefix to remember. Its stock library set is extended with
`libepoxy`, which a GTK or Flutter AppImage needs before it draws anything.

**So do plain binaries you compiled somewhere else.** `programs.nix-ld`
answers the `/lib64/ld-linux-x86-64.so.2` that a foreign ELF asks for and
NixOS does not otherwise have, and `programs.nix-ld.libraries` hands it the
GTK, webkit, X11, OpenGL, audio, font and terminal libraries such a program
expects — so a GTK or Tauri app built on another distribution, or on this
machine before it was reinstalled, starts by double-clicking it. Nothing is
patched and nothing is copied. A program that needs a library outside that
list says so plainly:

```
error while loading shared libraries: libfoo.so.1: cannot open shared object file
```

Add the package that provides it to `programs.nix-ld.libraries` and rebuild.

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
flake.nix           the interface: modules, packages, checks, the VM
nix/module.nix      the whole desktop behind programs.suckless-environment
nix/laptop.nix      nixosModules.laptop — Intel TigerLake facts, no disks
nix/packages.nix    one derivation per vendored tool
nix/lib.nix         the shared builder they all use
hosts/vm.nix        the disposable QEMU host — the only complete system here
dwm/ st/ dmenu/ slstatus/   vendored sources, patches and config.h
utils/              the C utilities
doom/               $DOOMDIR: init.el, config.el, packages.el
bash/ dunst/ fcitx5/ picom/ tmux/   deployed by the module
```

Machine-specific session setup — monitor layout, wallpaper, pointer warp —
goes in `~/.config/suckless/autostart.sh`, which the dwm launcher sources.
It is deliberately not in the flake: it is state, not configuration.

## Login

**Ly is the display manager**, on tty1, coloured with the same Tokyo Night
palette as the rest of the desktop. dwm is registered as `none+dwm` and set
as the default session, so Ly lists it and starts it — the `.desktop` it
reads execs NixOS's xsession wrapper, which runs the launcher that brings up
the session daemons.

Ly is a TUI on the Linux console, which has two consequences worth knowing:
the password is typed on the **console** keymap (`br-abnt2`, which the module
sets) rather than on X's layout, and the clock is ASCII — the console font
has no CJK, so the `年月日` the status bar prints would be tofu here.

For a TTY login and `startx` instead, turn it off and the module wires up the
other flow on its own — `services.xserver.autorun` follows it down and the
`startx` pseudo-DM comes back:

```nix
services.displayManager.ly.enable = false;
```

`hosts/vm.nix` does exactly that, which is how the test VM still boots
straight into dwm with no password. Another greeter (greetd, SDDM) also
works; the module detects those too.

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
  `betterlockscreen` and `systemctl`

## Contributing

`CLAUDE.md` holds the project context: the reference machine, the parity
matrix, and the reasoning behind these decisions.

## License

See the LICENSE files in each subdirectory (dwm/, st/, dmenu/, slstatus/,
utils/).
