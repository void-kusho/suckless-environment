# suckless-environment

A minimal X11 desktop for **NixOS**: dwm, st, dmenu and slstatus built from
the sources in this repository, a small suite of C utilities, and Doom Emacs.
Tokyo Night everywhere, Japanese input, one toggle:

```nix
programs.suckless-environment.enable = true;
```

## At a glance

| Command | What it does |
|---|---|
| `nix run .#vm` | boots the desktop in QEMU — no disk, nothing installed |
| `nix flake check` | the gate: builds every tool, the VM, the reference machine, the module and the template |
| `sudo nixos-rebuild switch` | rebuilds the reference machine (`/etc/nixos` is a symlink to this clone) |
| `nix flake init -t .#laptop` | writes an `/etc/nixos` for a **different** machine |
| `imports = [ nixosModules.default ]` | the desktop alone, inside a configuration you already have |

Two rules hold everywhere in this repository:

- **`nix/` describes a desktop and a chipset, never a disk.** No partitions,
  no bootloader, no users, no `stateVersion` in any module.
- **`hosts/` describes machines.** `hosts/nixos-btw/` is the laptop this was
  written on, UUIDs included. Nobody imports a host.

## Try it in QEMU

```bash
nix run .#vm
```

Boots `hosts/vm.nix` straight into dwm: no login, no `startx`. Wallpaper,
bar, keybindings and session daemons are all there.

**Move the pointer onto the window before pressing anything.** Your host's
MODKEY is Super and so is the guest's; the window grabs input on hover
(`-display gtk,grab-on-hover=on`), and until it does, `Super+…` goes to your
own window manager. `Ctrl+Alt+G` toggles the grab, `Ctrl+Alt+F` goes full
screen.

The VM shares the host's `/nix/store`, so it costs a build, not a download.
It cannot show you backlight, WiFi firmware, VA-API or the two-monitor
layout — those need the hardware. Two knobs in `hosts/vm.nix`:
`virtualisation.memorySize` and `virtualisation.graphics` (`false` for a
serial console).

## Check it

```bash
nix flake check     # the gate
nixfmt $(git ls-files '*.nix')     # formatting; `nix fmt` walks past this tree and exits non-zero
```

`nix flake check` builds the five tools, the QEMU host, the whole
`nixos-btw` machine, and — against a throwaway root, so the fake disk lives
in the check and not in the thing checked — `nixosModules.laptop` and the
install template. Nothing that fails it should reach `nixos-rebuild switch`.

## Rebuild the reference machine

`hosts/nixos-btw/` is the laptop this was written on: disks, bootloader,
user, locale, monitor layout, home-manager applications. On that laptop,
`/etc/nixos` is a **symlink to this clone** and nothing else.

Once:

```bash
sudo ln -s /home/void/suckless-environment /etc/nixos
```

Every day after:

```bash
sudo nixos-rebuild switch
```

`nixos-rebuild` implies `--flake /etc/nixos` when `/etc/nixos/flake.nix`
exists and picks `nixosConfigurations.<hostname>`, so the plain command and
`sudo nixos-rebuild switch --flake .#nixos-btw` build the same store path.

**Why a symlink.** The alternative — a small flake in `/etc/nixos` that
imports this one as a `git+file:` input — sees only *committed* work and
only moves when someone runs `nix flake update`. That is what the machine
had, and it ran nine days behind this repository without any error to show
for it. A symlink has no lock file to go stale.

Two files in the host are generated on the machine and copied in, never
hand-edited:

| File | Refresh with |
|---|---|
| `hardware-configuration.nix` | `nixos-generate-config --show-hardware-config \| nixfmt > hosts/nixos-btw/hardware-configuration.nix` — after a reinstall |
| `autostart.sh` | it *is* the source: an activation script installs it into `~/.config/suckless/` on every switch |

**Installing on other hardware? Do not copy this host.** Its UUIDs are not
yours. Use the next section.

## Install on a new machine

Seven steps from a blank disk to the finished desktop. Steps 1–2 are plain
NixOS; the rest is this repository. Nothing is transcribed by hand — step 3
writes the whole configuration.

**Already on NixOS?** Start at step 3, read `/etc/nixos` wherever it says
`/mnt/etc/nixos`, and replace step 5 with `sudo nixos-rebuild switch --flake /etc/nixos#<hostname>`.

### 0. What you get

`nixosModules.laptop` = the desktop **plus** the Intel TigerLake this was
written on: redistributable firmware (the AX201 WiFi, the Jefferson Peak
bluetooth and the Iris Xe GuC load microcode at runtime and are dead
without it), Intel microcode, `modesetting`, the iHD VA-API driver, the
QuickSync runtime, thermald, fstrim, fwupd. On other hardware use
`nixosModules.default` — same desktop, no chipset — see
[Use it as a module](#use-it-as-a-module).

### 1. Boot the ISO and partition

Boot the official NixOS minimal ISO and get on a network (`wpa_cli`, or a
cable). Everything below runs from the installer, so the machine's first
boot is straight into the finished desktop.

UEFI, wiping `/dev/nvme0n1`. **Check the device with `lsblk` first — this
erases it.**

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
mv /mnt/etc/nixos/configuration.nix /mnt/etc/nixos/configuration.nix.orig
```

`hardware-configuration.nix` is your disks and initrd modules — the one
file that cannot come from anywhere else. The generated `configuration.nix`
is replaced by the template in the next step.

### 3. Write the configuration

```bash
cd /mnt/etc/nixos
nix --extra-experimental-features "nix-command flakes" \
    flake init -t github:void-kusho/suckless-environment#laptop
```

Writes `flake.nix`, `configuration.nix`, `home.nix` and `autostart.sh` next
to the hardware configuration. `nix flake init` never overwrites an
existing file.

### 4. Edit four lines

In `/mnt/etc/nixos/configuration.nix`, the lines marked `EDIT`:

| Line | Value |
|---|---|
| `networking.hostName` | the machine's name |
| `users.users.void` | your username — **also** in `flake.nix` and in the activation script at the bottom of the file |
| `time.timeZone` | from `timedatectl list-timezones` |
| `system.stateVersion` | the release you are installing |

Two choices, both explained in the file, both fine as they are:

- **Language.** The desktop is Japanese-first; the template makes the
  system English and keeps a `japanese` boot entry. Delete that block for a
  Japanese system.
- **home-manager.** The template uses it for user applications. Delete
  `home.nix` and the `HOME-MANAGER` blocks in `flake.nix` to declare
  everything in `configuration.nix` instead.

One monitor? Delete `autostart.sh` and the
`system.activationScripts.suckless-autostart` block.

### 5. Install

```bash
nixos-install --flake /mnt/etc/nixos#nixos-btw \
  --option extra-experimental-features "nix-command flakes"
reboot
```

`#nixos-btw` is the `nixosConfigurations.<name>` in `flake.nix`; if you
renamed it, rename it here. Expect a long build — dwm, st and the utilities
compile. `nixos-install` asks for a root password at the end.

The `--option` is only for the ISO, which has flakes off. The installed
system turns them on, so afterwards it is:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos-btw
```

### 6. First login

Ly greets you on tty1 with `dwm` selected. Log in with the
`initialPassword`, then:

```bash
passwd
```

and delete the `initialPassword` line — it applied at account creation only,
and a password in a file you may publish is a bad habit.

You should see a wallpaper and a bar. `Super+Return` opens a terminal,
`Super+d` lists applications, `Ctrl+Alt+Del` is the session menu. The full
map is under [Keybindings](#keybindings). WiFi is `wifitui` (or `nmtui`),
no `sudo` — your user is in the `networkmanager` group.

### 7. Finish Doom Emacs

Doom's framework is a git checkout and stays imperative. Its *configuration*
comes from this repository through `$DOOMDIR`, so this runs once:

```bash
git clone https://github.com/doomemacs/core ~/.config/emacs
~/.config/emacs/bin/doom install
rm -rf ~/.config/doom     # dead weight — see Doom Emacs below
```

### Worth doing once

- **Lock screen.** `betterlockscreen` locks against a pre-rendered image;
  without one, `Ctrl+Alt+Del → lock` has nothing to draw:
  `betterlockscreen -u <any image>` (the repository's wallpaper is
  `wallpapers/sushi_original.png`).
- **Icons and cursors.** The defaults are Papirus-Dark and Adwaita, both
  installed. Personal sets go in `~/.local/share/icons`; `lxappearance`
  switches.

### When something goes wrong

| Symptom | What to do |
|---|---|
| The rebuild fails | Read the *first* error. nixpkgs renames options between releases and names both. A failed `switch` changes nothing on the running system. |
| Black screen or a TTY after boot | Pick the previous generation in the boot menu, or `sudo nixos-rebuild switch --rollback`. |
| The greeter rejects the password | The console keymap is `br-abnt2`. Not Brazilian? Set `console.keyMap` and `services.xserver.xkb.layout` in your host — both are `mkDefault` in the module for this reason. |
| The keyboard "goes English" while typing | fcitx5 rewrote `~/.config/fcitx5/profile` to `DefaultIM=mozc`, routing every key through the Japanese engine. `rm` that file and log in again; the shipped seed keeps mozc on `Ctrl+Alt+Space`. |
| No microphone or no sound in Brave, Spotify, Obsidian, Meet — right after a rebuild | The switch restarted PipeWire (any rebuild that touches glibc restarts every user service), and Chromium/Electron apps do not reconnect to a new audio server. Close the app completely (`pkill -f brave`) and reopen it. A bluetooth headset exposes its microphone only in the HFP/Handsfree profile, not A2DP — `pavucontrol` → Configuration. |
| The 180 Hz monitor feels like 60 | Something is compositing the whole screen — a compositor you started, or a picom left in `autostart.sh`. The desktop ships none; see [Monitors](#monitors). |
| A binary built elsewhere will not start | It names the library: `error while loading shared libraries: libfoo.so.1`. Add the package to `programs.nix-ld.libraries` and rebuild. |
| Not sure it will work | `nix flake check` in a clone, before `switch`. |

## Use it as a module

On other hardware, or in a configuration you already have:

```nix
imports = [ inputs.suckless-env.nixosModules.default ];
programs.suckless-environment.enable = true;
programs.suckless-environment.extraPackages = with pkgs; [ discord ];
```

| Module | Contents |
|---|---|
| `nixosModules.default` | the desktop, behind `programs.suckless-environment.enable` |
| `nixosModules.laptop` | the desktop plus the Intel TigerLake facts above |

Set `inputs.suckless-env.inputs.nixpkgs.follows = "nixpkgs"`, or you
evaluate and download a second nixpkgs — the one pinned in this repository's
own `flake.lock`.

Your user needs three groups: `video` and `input` (the backlight udev rules
grant brightness writes to them — without them the brightness keys do
nothing) and `wheel` (the polkit rule that mounts internal disks without a
password).

## Configure it

### Language

The desktop is **Japanese**, with English as the fallback for anything
untranslated (`LANGUAGE=ja:en`; `LANG` alone would fall back to the C locale).
`ja_JP`, `en_US`, `pt_BR` and `C` are generated, the UI font is Noto Sans
CJK JP, and slstatus prints 年月日. The reference machine inverts this: its
host sets English and keeps a `japanese` boot entry.

Three different things, and only the last one rebuilds:

| You want | Do |
|---|---|
| to type Japanese | nothing — fcitx5 + mozc are on; `Ctrl+Alt+Space` switches, `fcitx5-configtool` configures |
| one session in English | `LANG=en_US.UTF-8 startx` |
| the whole system in the other language | pick the other entry in the boot menu, or `sudo /run/current-system/specialisation/<name>/bin/switch-to-configuration switch`, then log out and in |
| to change the default | `i18n.defaultLocale` in your host, and rebuild |

There is no GUI or TUI for the system locale on NixOS, and that is not an
omission: `/etc/locale.conf` is a store symlink, so `localectl set-locale`
cannot write it. The specialisation is the NixOS-shaped answer.

### Monitors

Layout lives in `~/.config/suckless/autostart.sh`, sourced by the dwm
launcher on every login. On the reference machine that file is installed
from `hosts/nixos-btw/autostart.sh` by an activation script; elsewhere,
`arandr` writes an `xrandr` line and you paste it there.

The reference machine drives its panel and an **AOC 27G4** on DP-1. What the
AOC offers and what an X11 session gets:

| The monitor offers | X11 uses | Where |
|---|---|---|
| 1920×1080 at 180 Hz | yes, always | `autostart.sh` |
| FreeSync 48–180 Hz | **only with DP-1 as the sole output** | `vrr on` |
| 10 bits per colour | the link may negotiate 10 bpc (`max bpc: 12`); the X framebuffer stays 8-bit | — |
| HDR10 | no: X11 has no HDR path; that needs a Wayland compositor | — |

**There is no compositor, and that is what makes 180 Hz real.** A
compositor paints the whole root through one vsynced swap, and the X server
ties that swap to a single CRTC — with two monitors of equal size, the
first one it finds, which here is the 60 Hz panel. Measured on the
reference machine with a root-sized GL window: 60 swaps/s while a window
on DP-1 alone did 180. So with picom running, DP-1 scanned out 180 times a
second and its content changed 60. Without a compositor every window
presents to its own CRTC at its own rate. What goes with it: the
open/close animations, and a global tear-free guarantee — Brave and mpv
vsync themselves; a terminal scrolling fast may show a tear line.

**FreeSync needs one monitor, and that is Xorg, not this configuration.**
Variable refresh on X11 takes the driver allowing it
(`Option "VariableRefresh" "true"`, set in the host) and the server
**page-flipping** the window instead of copying it. Present only flips a
window that covers the *whole root*. With the panel lit the root is
3840×1080, a window that fills DP-1 is copied, and the CRTC's
`VRR_ENABLED` never leaves 0. Measured with `glxgears -fullscreen` and
`drm_info`: 0 with both outputs, 1 the moment the panel is off.

So the host ships a switch:

```
vrr on      panel off; DP-1 is the whole screen, fullscreen GL/Vulkan flips with FreeSync
vrr off     both monitors again, from autostart.sh
vrr         which of the two
```

dwm moves the panel's windows to DP-1 when it goes away and leaves them
there when it comes back — park what you want to keep on DP-1 first. To
watch it engage: `nix run nixpkgs#drm_info | grep VRR_ENABLED` while a
fullscreen game runs.

### Everything else

TUI where one exists, GUI only where it does not:

| | Tool | |
|---|---|---|
| WiFi | `wifitui` | TUI, same version as the reference machine |
| Network (wired, VPN) | `nmtui` | TUI, ships with NetworkManager |
| Audio | `pulsemixer` | TUI: devices, volume, default sink (`pavucontrol` is the GUI, on the reference machine) |
| Bluetooth | `bluetuith` | TUI: pairing (`blueman-manager` is the GUI) |
| Input methods | `fcitx5-configtool` | GUI: engines and switch keys |
| Theme | `lxappearance` | GUI: GTK theme, icons, cursor, UI font |
| Monitors | `arandr`, `vrr` | see [Monitors](#monitors) |
| CPU profile | `Super+p` | `dmenu-cpupower` |
| Disks | Thunar | click it in the sidebar; udisks2 mounts it |
| Mouse, touchpad | — | `services.libinput` in your host, or `xinput` at runtime |

**Secondary drives** are not declared anywhere: a second disk is not part of
the desktop. udisks2 mounts them under `/run/media/$USER/<label>`, and a
polkit rule lets `wheel` do it silently — udisks2 treats a fixed internal
drive as "system internal", which would otherwise ask for a password on every
login.

**AppImages** run as on any other distribution: `chmod +x Foo.AppImage &&
./Foo.AppImage`, or a double-click in Thunar. `programs.appimage` installs
`appimage-run` (an FHS sandbox with the `/usr/lib` an AppImage expects) and
`binfmt` registers it with the kernel. Its library set is extended with
`libepoxy`, which GTK and Flutter AppImages need.

**Plain binaries built elsewhere** run through `programs.nix-ld`, which
answers the `/lib64/ld-linux-x86-64.so.2` a foreign ELF asks for, and
`programs.nix-ld.libraries`, which hands it GTK, webkit, X11, OpenGL, audio,
font and terminal libraries. A Tauri app from another distribution starts by
double-clicking it. A program that wants something outside the list says so
— `error while loading shared libraries: libfoo.so.1` — and the fix is one
package added to that list.

**Theme.** The module ships `/etc/xdg/gtk-3.0/settings.ini` — Arc-Dark,
Papirus-Dark, Adwaita cursors, Noto Sans 11. `lxappearance` writes
`~/.config/gtk-3.0/settings.ini`, which overrides it.

**tmux** is the reference machine's configuration — Tokyo Night Moon,
`C-Space` prefix, vi copy-mode through `xclip`, `Alt+hjkl` panes,
`Alt+1..9` windows — deployed as `/etc/tmux.conf`. Like `$DOOMDIR` it is
read-only: its `bind r` reloads a file that does not exist, and changes come
from a rebuild.

### Doom Emacs

`$DOOMDIR` points into the store: `doom/` in this repository is the
configuration, deployed through `environment.variables.DOOMDIR`. Nothing to
seed, nothing to drift; Doom's mutable state stays in `~/.config/emacs` and
`~/.local/share/doom`.

| To | Do |
|---|---|
| change the configuration | edit `doom/`, rebuild; `doom sync` if `init.el` or `packages.el` changed (`config.el` alone needs a restart) |
| bootstrap the framework | [step 7](#7-finish-doom-emacs), once |
| know which config is in use | `doom info` — `doom doctor` names both directories in a fixed order and calls the wrong one ignored |
| get a language server | `nix shell nixpkgs#rust-analyzer` in the project; toolchains are deliberately not on the system |

`doom install` writes `~/.config/doom` from Doom's example templates
whether or not `$DOOMDIR` is set. It is never read here and safe to delete.

## Login

**Ly is the display manager**, on tty1, in the Tokyo Night palette, with
dwm registered as `none+dwm` and selected by default. Ly is a TUI on the
Linux console, which has two consequences: the password is typed on the
**console** keymap (`br-abnt2`, set by the module), not X's; and the clock is
ASCII, because the console font has no CJK.

For a TTY login and `startx` instead:

```nix
services.displayManager.ly.enable = false;
```

The module follows: `services.xserver.autorun` goes off and the `startx`
pseudo-DM comes back. `hosts/vm.nix` does exactly this, which is how the VM
boots straight into dwm. greetd and SDDM are detected too.

## Layout

```
flake.nix           the interface: hosts, modules, packages, checks, template
nix/module.nix      the whole desktop behind programs.suckless-environment
nix/laptop.nix      nixosModules.laptop — Intel TigerLake facts, no disks
nix/packages.nix    one derivation per vendored tool
nix/lib.nix         the shared builder they all use
hosts/nixos-btw/    the reference machine, complete — disks, user, home-manager
hosts/vm.nix        the disposable QEMU host
templates/laptop/   the /etc/nixos that `nix flake init` writes for a NEW machine
dwm/ st/ dmenu/ slstatus/   vendored sources, patches and config.h
utils/              the C utilities
doom/               $DOOMDIR: init.el, config.el, packages.el
wallpapers/         the default wallpaper (programs.suckless-environment.wallpaper)
bash/ dunst/ fcitx5/ thunar/ tmux/   deployed by the module
```

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

| | |
|---|---|
| `battery-notify` | low/critical notifications, 30 s tick |
| `brightness-notify` | brightnessctl plus an OSD notification |
| `dmenu-clipd` / `dmenu-clip` | clipboard daemon and history browser |
| `dmenu-cpupower` | power profile selector, through `powerprofilesctl` |
| `dmenu-session` | lock / logout / reboot / shutdown, through `betterlockscreen` and `systemctl` |

## Contributing

`CLAUDE.md` is the project context: the reference machine, what was found
broken and how, and the reasoning behind each decision.

## License

See the LICENSE files in each subdirectory (dwm/, st/, dmenu/, slstatus/,
utils/).
