# suckless-environment

My personal suckless desktop: **dwm** (patched), **dmenu**, **st**, **slstatus** —
packaged for NixOS with declarative, reproducible builds.

| Tool | Version | Customization |
|------|---------|---------------|
| dwm | 6.8 | alwayscenter, attachaside, restartsig, status2d+systray patches; Tokyo Night colors; Japanese tags |
| dmenu | 5.4 | stock config |
| st | 0.9.3 | stock config |
| slstatus | 1.1 | CPU / RAM / battery / volume (pamixer) / Japanese datetime status line |

The tools are built **from the sources in this repo** with their own
Makefiles — the classic suckless workflow. Nix only redirects `PREFIX` and
supplies dependencies.

## Repository layout

```
dwm/ dmenu/ st/ slstatus/   vendored sources + your config.h (edit these!)
nix/lib.nix                 tiny wrapper: runs each Makefile with PREFIX set
nix/packages.nix            one derivation per tool
nix/module.nix              NixOS module: programs.suckless-environment.enable
default.nix                 entrypoint for classic configuration.nix users
flake.nix                   entrypoint for flake users (same module + packages)
hosts/minimal.nix           template configuration.nix for a minimal install
```

## Full install guide (minimal NixOS + git)

Assumes: NixOS minimal is already installed and booting to a TTY login,
and you have root access (`sudo` or direct root login). Git must be
available — if it isn't yet, install it first:

```sh
nix-env -iA nixos.git        # temporary, without editing configuration.nix
```

### 1. Get this repo into /etc/nixos

```sh
cd /etc/nixos
sudo git clone https://github.com/void-kusho/suckless-environment.git
```

You now have `/etc/nixos/suckless-environment` next to your
`configuration.nix`.

### 2. Enable it in /etc/nixos/configuration.nix

Open `/etc/nixos/configuration.nix` (nano/vim are on a minimal system)
and make two changes:

**a)** Add the repo to your `imports` list:

```nix
imports =
  [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./suckless-environment          # <- add this line
  ];
```

**b)** Add the toggle anywhere at option level (end of file is fine):

```nix
programs.suckless-environment.enable = true;
```

Optionally, put your user in the `networkmanager` group so `nmcli` /
`nmtui` work without extra setup:

```nix
users.users.myuser = {
  isNormalUser = true;
  extraGroups = [ "wheel" "networkmanager" ];   # <- add networkmanager
};
```

(See `hosts/minimal.nix` in this repo for a complete reference file.)

### 3. Apply

```sh
sudo nixos-rebuild switch
```

First run compiles all four tools from source — a couple of minutes.
This single toggle sets up everything:

* X11 server (started manually — no display manager runs at boot)
* dwm as the default `startx` session
* dwm, dmenu, st, slstatus + pamixer, xprop, xrandr
* JetBrains Mono + Noto CJK fonts (Japanese tags and status text)
* PipeWire audio so pamixer volume control works
* NetworkManager

### 4. Start using it

Log in on any TTY and run:

```sh
startx
```

dwm comes up with slstatus in the bar. That's the whole session: no
display manager, nothing autostarts X until you ask for it.

**Optional** — start X automatically when logging in on TTY 1 by adding
this to `/etc/profile` (or your shell profile):

```sh
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$DISPLAY" ]; then
  exec startx
fi
```

TTYs 2–6 stay plain shells.

### Troubleshooting

* `startx` fails with a black screen: check `~/.local/share/xorg/Xorg.0.log`
  (or `/var/log/Xorg.0.log`) for driver errors; most hardware works with
  the default modesetting driver.
* Japanese tags render as boxes: confirm the toggle is actually enabled
  (`nixos-option programs.suckless-environment.enable` should print true).
* Volume shows `n/a`: PipeWire needs your user session; make sure you ran
  `startx` after a normal login (not via `su`).

### Flakes variant

Prefer flakes? Skip steps 2a–2b and wire the module from your own flake
instead — the module and packages are identical:

```nix
{
  inputs.suckless-env.url = "github:void-kusho/suckless-environment";

  outputs = { self, nixpkgs, suckless-env }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        suckless-env.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

…then set `programs.suckless-environment.enable = true;` in
`configuration.nix`. Build with `sudo nixos-rebuild switch --flake .#myhost`.

## Daily use

| Key | Action |
|-----|--------|
| `Mod+p` | dmenu launcher |
| `Mod+Shift+Enter` | open st |
| `Mod+j/k` | focus next/prev window |
| `Mod+Shift+c` | kill window |
| `Mod+1..9` | switch tag |
| `Mod+Shift+q` | quit dwm |

`Mod` = Alt. Volume: use `pamixer -d/-i`, or any client through PipeWire.
Network: `nmcli` / `nmtui`.

## Customizing

Everything visual/behavioral lives in the per-tool `config.h` files:

```sh
$EDITOR dwm/config.h
sudo nixos-rebuild switch     # channels
nixos-rebuild switch --flake .#myhost   # flakes
```

Then restart dwm (`Mod+Shift+q`, `startx`) or just relaunch slstatus/st.
No other file needs to change — the derivations always build what is in
the source tree.

## Maintenance

* **Update a tool**: replace its vendored source with the new release
  (`git clone https://git.suckless.org/dwm && ...` or download the tarball),
  re-apply your `config.h` (and patches for dwm), bump the `version = "..."`
  in `nix/packages.nix`.
* **Patch dwm**: apply the `.diff` to the sources by hand, keep the patch
  file in `dwm/patches/` for reference, commit both together.
* **Format Nix code**: `nix develop -c nixfmt nix/ hosts/ *.nix`
* Build artifacts (`*.o`, binaries, `*.orig`, `*.rej`) are gitignored.

## Building packages standalone

Without NixOS at all:

```sh
nix-build nix/packages.nix -A st      # result/bin/st
nix build .#dwm                       # in a flake-enabled checkout
```
