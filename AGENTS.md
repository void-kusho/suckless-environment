# AGENTS.md — working in this repository

This file is the working context: what the project is, how to verify a
change, and the traps that cost time before. `README.md` is the manual.
There is no second context file — the reasoning behind a decision lives in
the commit that made it, so `git log` is the record.

## What this is

An X11 suckless desktop — dwm 6.8, st 0.9.3, dmenu 5.4, slstatus 1.1, a C
utility suite, Doom Emacs — declared for **NixOS** as a flake. No
compositor. The editor is Doom Emacs; there is no Neovim, no Helix, no
Yazi. Sibling branches: `guix`, `origin/artix` (the imperative build this
one targets, and the machine), `guix-wayland` (abandoned).

## The gate — run both before saying you are done

```bash
nix flake check
nixfmt $(git ls-files '*.nix')
```

`nix flake check` builds the five tools, the utils test suite, the QEMU
host, the entire `nixos-btw` machine (home-manager and disks included), and
— against a throwaway root — `nixosModules.laptop` and the install
template. Nothing that fails it reaches `nixos-rebuild switch`.

`nix fmt` is `nixfmt-tree`, walks out of this tree and exits non-zero on
files that are not ours. Use `nixfmt` on the tracked files.

Faster loops while iterating on one tool:

```bash
nix build .#dwm .#dmenu .#st .#slstatus .#utils
nix run .#vm          # boots to dwm, grabs the keyboard via -display gtk,grab-on-hover=on
```

Only a booted session proves runtime behaviour. Every finding this file
warns about was found by booting or driving the session, not by reading.

## Where things live

| Path | Owns | Never contains |
|---|---|---|
| `nix/module.nix` | the desktop: `programs.suckless-environment`, session daemons, fonts, fcitx5/mozc, Ly, nix-ld, `/etc/xdg` files | a disk, a user, a hostname |
| `nix/laptop.nix` | the chipset: firmware, microcode, modesetting, VA-API, QuickSync, flatpak portal | same |
| `nix/lib.nix` | the shared builder for the five vendored Makefiles | tool-specific flags |
| `nix/packages.nix` | the derivations themselves | host or user config |
| `hosts/nixos-btw/` | the reference machine, whole — disks, user, bootloader, monitor layout | anything anyone imports |
| `hosts/vm.nix` | the disposable QEMU host | real disks |
| `templates/laptop/` | a teaching copy of the host with the disks removed, for `nix flake init -t .#laptop` | UUIDs |

When the host and the template drift, the host is right.

## Traps

- **`src` is the working tree.** A binary you built by hand is newer than
  its sources, `make` skips the compile, and the store gets a foreign
  binary that asks for `/lib64/ld-linux-x86-64.so.2`. Three layers guard
  it: `preBuild = "make clean"` in `nix/lib.nix`, a `postFixup` that fails
  on any interpreter outside the store, and `.gitignore` for all eleven
  build products. If you add a tool, add its products to `.gitignore`.
- **Vendored tools keep their upstream Makefiles and `config.h`.** Fix
  behaviour in `config.h` or in `patches/*.diff`; do not restructure the
  C. A `config.def.h` is upstream's and stays untouched.
- **`utils/` carries no `config.h` on this branch** — the backends are in
  the `.c` files. `.gitignore` blocks a `config.h` there. This branch
  speaks `systemctl` where `origin/artix` speaks `loginctl`: elogind and
  systemd disagree about who owns the power verbs.
- **An option that defaults to the wrong thing is how a decision comes
  back.** No compositor option remains for exactly this reason.
- **Session state** (monitor layout, pointer warp) lives in
  `~/.config/suckless/autostart.sh`, never in `nix/`.
- **Keep parity with `origin/artix` byte-identical** for `dwm/config.h`,
  `st/config.h`, `dmenu/config.h`, `slstatus/config.h`, `dunst/dunstrc`,
  `fcitx5/{profile,config}`. nixpkgs carries every tool the Arch build
  uses, so nothing has had to diverge.
- **No compiler in the system.** Toolchains are `nix shell nixpkgs#…`; the
  user's home-manager list is the user's call. nix-ld exists for foreign
  binaries — list *direct* dependencies only, anything reached through it
  carries its own RUNPATH.
- **Documents describe the state that exists.** Check a claim against the
  machine or the evaluation before writing it, and write it in the tense
  that is true. This is a rule, not a style preference.

## Working language

Talk to the owner in **English**. Write code, comments and docs in
**English**. No emojis unless asked. Do not commit unless asked.

## When a change is not obvious

`nix store diff-closures` against the running system measures the cost of
a change instead of guessing it. `nix eval` proves a claim about
evaluation. Driving the live session with `xdotool` (through dwm itself,
not around it) is how the keybinding findings were made. The commit
message records the method next to each finding, next to the change it
describes.
