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

## Install on minimal NixOS

### Channels way (what a fresh minimal install gives you)

1. Boot the NixOS minimal ISO, partition/mount, then:

   ```sh
   nixos-generate-config --root /mnt
   ```

2. Copy this repo to `/mnt/etc/nixos/suckless-environment`.

3. Merge into `/mnt/etc/nixos/configuration.nix`:

   ```nix
   imports = [ ./suckless-environment ];  # merge with existing imports list
   programs.suckless-environment.enable = true;
   ```

4. Install and reboot:

   ```sh
   nixos-install
   reboot
   ```

5. Log in on the TTY and start the session:

   ```sh
   startx
   ```

That's it. The toggle brings X11, dwm as the xinit default session, all four
tools, JetBrains Mono + Noto CJK fonts (Japanese tags/status), PipeWire
(volume via pamixer) and NetworkManager.

### Flakes way

Add this repo as an input to your system flake:

```nix
{
  inputs.suckless-env.url = "git+https://your-remote/suckless-environment";

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
`configuration.nix`. Build with `nixos-rebuild switch --flake .#myhost`.

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
