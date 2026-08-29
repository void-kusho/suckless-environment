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

That builds `hosts/vm.nix` and boots it in QEMU. Log in as **`you`** with the
password **`test`**, then run `startx`.

The VM is disposable and shares the host's `/nix/store`, so it costs a build,
not a download of a disk image. What it cannot tell you: backlight, WiFi
firmware, VA-API, and the dual-monitor layout — those need real hardware.

Two knobs, in `hosts/vm.nix`: `virtualisation.memorySize` and
`virtualisation.graphics` (set it to `false` for a serial-only console).

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
bash/ dunst/ fcitx5/ picom/  deployed by the module
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
