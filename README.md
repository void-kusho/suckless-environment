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
nix flake check     # all five tools compile, and everything here evaluates
nix fmt             # format the Nix
```

`nix flake check` is the gate. It builds every package, the QEMU host, the
whole `nixos-btw` machine below, and — each against a throwaway root, so the
fake disk lives in the check and never in the thing being checked —
`nixosModules.laptop` and the installation template from
[step 3](#3-write-the-configuration). Nothing that fails it should reach
`nixos-rebuild switch`.

## Rebuild the reference machine

The laptop this was written on is in here, whole:

```bash
sudo nixos-rebuild switch --flake /path/to/this/repo#nixos-btw
```

`hosts/nixos-btw/` is its disks, bootloader, user, English-with-a-Japanese-
boot-entry locale, monitor layout and home-manager applications. Nothing
about it lives in `/etc/nixos` any more, and nothing about it leaks into
`nixosModules.laptop`, which is what everyone else imports and which still
has no disk in it.

Its `hardware-configuration.nix` is a snapshot, true until the disks are
reformatted. After a reinstall:

```bash
nixos-generate-config --show-hardware-config \
  | nixfmt > hosts/nixos-btw/hardware-configuration.nix
```

**Installing on a different machine? Do not copy this host** — its UUIDs are
not yours. Use the walkthrough below, which writes an `/etc/nixos` with no
disks in it.

## Install it, from a blank disk

Seven steps, start to finished desktop. Steps 1 and 2 are ordinary NixOS,
written out because "install NixOS however you like" is not a step-by-step;
the rest is this repository.

The whole configuration is written for you in step 3 — there is nothing here
to transcribe by hand.

**Already running NixOS?** Skip to step 3, use `/etc/nixos` wherever it says
`/mnt/etc/nixos`, and replace step 5 with the `nixos-rebuild` at the end of
it.

### 0. What you are about to get

`nixosModules.laptop` is the desktop **plus** the Intel TigerLake hardware
this was written on: redistributable firmware (the AX201 WiFi, the Jefferson
Peak bluetooth and the Iris Xe GuC all load microcode at runtime and are dead
without it), Intel microcode, `modesetting`, the iHD VA-API driver, thermald,
fstrim and fwupd. On other hardware use `nixosModules.default` instead — same
desktop, no chipset — and see [Use it as a module](#use-it-as-a-module).

**This repository describes a desktop and a chipset. It never describes a
disk.** There is no partition, no filesystem, no bootloader, no user and no
`stateVersion` anywhere in it. Those live in `/etc/nixos`, on the installed
machine, in files you own — which is what step 3 gives you.

### 1. Boot the ISO and partition

Boot the official NixOS minimal ISO and get it on a network — the installer
image has `wpa_supplicant` running already, so `wpa_cli` or a cable is
enough. **Everything below happens from the installer**, which is the point:
it is the one place where networking already works, so the machine's first
boot is straight into the finished desktop.

UEFI, wiping `/dev/nvme0n1` — **check the device name with `lsblk` first,
this erases it**:

```bash
sudo -i
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart swap linux-swap 1GiB 5GiB
parted /dev/nvme0n1 -- mkpart root ext4 5GiB 100%

mkfs.fat -F32 -n boot /dev/nvme0n1p1
mkswap -L swap /dev/nvme0n1p2 && swapon /dev/nvme0n1p2
mkfs.ext4 -L nixos /dev/nvme0n1p3

mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot && mount /dev/disk/by-label/boot /mnt/boot
```

### 2. Generate the hardware configuration

```bash
nixos-generate-config --root /mnt
```

This writes `/mnt/etc/nixos/hardware-configuration.nix` — your disks' UUIDs,
your initrd modules. **It is the one file here that cannot be copied from
anywhere**, and the next step leaves it alone. It also writes a
`configuration.nix`, which the template replaces:

```bash
mv /mnt/etc/nixos/configuration.nix /mnt/etc/nixos/configuration.nix.orig
```

### 3. Write the configuration

One command. It writes `flake.nix`, `configuration.nix`, `home.nix` and
`autostart.sh` beside the hardware configuration:

```bash
cd /mnt/etc/nixos
nix --extra-experimental-features "nix-command flakes" \
    flake init -t github:void-kusho/suckless-environment#laptop
```

`nix flake init` never overwrites a file that already exists, so the
hardware configuration is safe either way.

### 4. Edit four lines

Open `/mnt/etc/nixos/configuration.nix` — `nano` and `vim` are both on the
ISO — and change the lines marked `EDIT`:

| | |
|---|---|
| `networking.hostName` | whatever you want to call the machine |
| `users.users.void` | your username — **also** in `flake.nix` and in the activation script at the bottom of the same file |
| `time.timeZone` | `timedatectl list-timezones` |
| `system.stateVersion` | the release you are installing |

Then two decisions, both explained in the file itself and both fine to leave
alone:

- **Language.** The desktop is Japanese-first. The template turns it English
  and keeps a `japanese` entry in the boot menu to switch back. Delete that
  block for a Japanese system.
- **home-manager.** The template uses it for user applications. Delete
  `home.nix` and the blocks marked `HOME-MANAGER` in `flake.nix` if you would
  rather declare everything in `configuration.nix`.

If you have one monitor, delete `autostart.sh` and the
`system.activationScripts.suckless-autostart` block that installs it.

### 5. Install

```bash
nixos-install --flake /mnt/etc/nixos#nixos-btw \
  --option extra-experimental-features "nix-command flakes"
reboot
```

`#nixos-btw` is the `nixosConfigurations.<name>` in `flake.nix`; if you
renamed it, name it here too.

Expect a long download — this builds the whole desktop, dwm and st and the
utilities included. `nixos-install` asks for a root password at the end.

The `--option` is needed because the ISO has flakes turned off; the installed
system turns them on itself, so every rebuild afterwards is just:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos-btw
```

### 6. First login

Ly greets you on tty1, themed Tokyo Night, with `dwm` already selected.
Log in with the password from `initialPassword`, then change it:

```bash
passwd
```

and delete the `initialPassword` line — it only ever applied to the account's
creation, but leaving a password in a file you may publish is a bad habit.

You should be looking at dwm: a wallpaper, a bar with the date and battery,
and nothing else. `Super+Return` opens a terminal, `Super+d` lists
applications, `Ctrl+Alt+Del` offers lock/logout/reboot/shutdown. The full map
is in [Keybindings](#keybindings).

Wireless is NetworkManager now, and your user is in its group, so no `sudo`:
`wifitui` in a terminal, or `nmtui` if you prefer the one that ships with it.

### 7. Finish Doom Emacs

The framework is a git checkout and stays imperative — the *configuration*
comes from this repository through `$DOOMDIR`, so this is a one-time
bootstrap and never needs repeating:

```bash
git clone https://github.com/doomemacs/core ~/.config/emacs
~/.config/emacs/bin/doom install
rm -rf ~/.config/doom     # dead weight; see the Doom Emacs section below
```

### Two things worth doing once

**A lock screen with your wallpaper.** `betterlockscreen` locks against a
pre-rendered cache; without it, `Ctrl+Alt+Del` → `lock` has nothing to draw:

```bash
betterlockscreen -u ~/.config/suckless/wallpaper.png
```

**Icons and cursors.** The reference machine uses icon and cursor themes
downloaded by hand into `~/.local/share/icons`; they are user state and are
not packaged here. Without them you get the module's defaults —
Papirus-Dark and Adwaita, both installed. `lxappearance` changes either.

### When something goes wrong

**The rebuild fails.** Read the first error, not the last; nixpkgs
renames things between releases and the message names the old and the new
option. Nothing has changed on the running system — a failed `switch` is a
no-op.

**It boots to a black screen or a TTY.** Pick the previous generation in the
boot menu; every rebuild leaves one. From a TTY,
`sudo nixos-rebuild switch --rollback` does the same thing.

**The greeter rejects your password.** The console keymap is `br-abnt2`.
If your keyboard is not Brazilian, set `console.keyMap` and
`services.xserver.xkb.layout` in `configuration.nix` — both are `mkDefault`
in the module precisely so you can.

**The keyboard "goes English" while typing.** fcitx5 rewrites
`~/.config/fcitx5/profile` at runtime, and the copy this repository ships is
only a seed. If it has drifted to `DefaultIM=mozc`, every key goes through
the Japanese engine. `rm ~/.config/fcitx5/profile` and log in again; the
shipped profile leaves mozc on `Ctrl+Alt+Space` instead of underfoot.

**A program you compiled elsewhere will not start.** It says which library it
wants — `error while loading shared libraries: libfoo.so.1`. Add the package
that provides it to `programs.nix-ld.libraries` and rebuild. The module
already lists the GTK, webkit, X11, OpenGL, audio and font sets.

**Check before you switch.** `nix flake check` in a clone of this repository
builds every tool, the VM host, the module and the template. Nothing that
fails it should reach `nixos-rebuild switch`.

## Use it as a module

If you do not want the whole `/etc/nixos` above — on other hardware, or in a
configuration you already have:

```nix
imports = [ inputs.suckless-env.nixosModules.default ];
programs.suckless-environment.enable = true;
programs.suckless-environment.extraPackages = with pkgs; [ discord steam ];
```

| | |
|---|---|
| `nixosModules.default` | the desktop, behind `programs.suckless-environment.enable` |
| `nixosModules.laptop` | that, plus the Intel TigerLake hardware this was written on |

Remember `inputs.suckless-env.inputs.nixpkgs.follows = "nixpkgs"`. Without
it you evaluate and download a second nixpkgs, the one pinned in this
repository's own `flake.lock`.

`video` and `input` are the groups the backlight udev rules grant brightness
writes to; `wheel` is what the disk-mounting polkit rule keys on. A user
without them gets a desktop whose brightness keys do nothing.

### Doom Emacs

`$DOOMDIR` points into the Nix store — `doom/` in this repository is the
configuration, deployed by `environment.variables.DOOMDIR`, so there is
nothing to seed and nothing to drift. Doom's own mutable state stays in
`~/.config/emacs` and `~/.local/share/doom`.

The framework is a git checkout and stays imperative — that is the two-line
bootstrap in [step 7](#7-finish-doom-emacs), run once and never again.

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
flake.nix           the interface: hosts, modules, packages, checks, template
nix/module.nix      the whole desktop behind programs.suckless-environment
nix/laptop.nix      nixosModules.laptop — Intel TigerLake facts, no disks
nix/packages.nix    one derivation per vendored tool
nix/lib.nix         the shared builder they all use
hosts/nixos-btw/    the reference machine, complete — disks, user, home-manager
hosts/vm.nix        the disposable QEMU host
templates/laptop/   the /etc/nixos `nix flake init` writes for a NEW machine
dwm/ st/ dmenu/ slstatus/   vendored sources, patches and config.h
utils/              the C utilities
doom/               $DOOMDIR: init.el, config.el, packages.el
bash/ dunst/ fcitx5/ picom/ thunar/ tmux/   deployed by the module
```

**`nix/*` never describes a disk; `hosts/*` does.** That is the whole
division. Import `nixosModules.laptop` and you get a desktop and a chipset
and none of anyone else's partitions; build `nixosConfigurations.nixos-btw`
and you get this laptop, UUIDs and all.

Machine-specific session setup — monitor layout, pointer warp — is
`~/.config/suckless/autostart.sh`, which the dwm launcher sources. The
module never writes it: it is the host's, and `hosts/nixos-btw/autostart.sh`
is installed into `$HOME` by an activation script so that even this piece of
state is declarative for the one machine that has an opinion about it.

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
