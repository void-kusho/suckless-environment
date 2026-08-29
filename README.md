# suckless-environment

A minimal X11 desktop for **GNU Guix**: dwm, st, dmenu, slstatus and a small
suite of C utilities, with Doom Emacs.

Everything is declarative. One `reconfigure` builds the tools from the sources
in this repository, installs every dependency and registers the dwm session
with the SLiM login screen. There is no install script: on Guix, `guix system
reconfigure` **is** the installer. (The Arch/Artix build lives on the `artix`
branch.)

| Role | Tool | Patches applied |
|------|------|-----------------|
| Window manager | **dwm** 6.8 | status2d, status2d-systray, attachaside, fibonacci, alwayscenter, restartsig |
| Terminal | **st** 0.9.3 | kitty-graphics, ligatures, clickurl, clipboard, anysize, font2 |
| Menu | **dmenu** 5.4 | center, border, desktoponly, inlinePrompt, xyw |
| Status bar | **slstatus** 1.1 | — |
| Editor | **Doom Emacs** on `emacs` | — |
| Login | **SLiM** | — |
| Lock | slock | **Screenshot** flameshot |
| Compositor | picom | **Notifications** dunst |
| Input method | fcitx5 + anthy | **Audio** PipeWire, under Shepherd |

`guix/system.scm` describes one specific machine: an Intel TigerLake laptop,
EFI, NVMe, two 1920×1080 outputs (eDP-1 left, DP-1 primary right), ABNT2
keyboard. Adapting it is four edits — see step 2.

## Install

### 1. Channels and substitutes

The configuration uses the non-free `linux` kernel and `linux-firmware`,
without which the Intel WiFi does not come up.

```bash
cp guix/channels.scm ~/.config/guix/channels.scm
guix pull

# Authorise nonguix's build farm on the machine doing the BUILDING.
# Skip this and reconfigure compiles the kernel and firmware from source.
wget https://substitutes.nonguix.org/signing-key.pub
sudo guix archive --authorize < signing-key.pub
```

The built system authorises the same server for itself — that is
`%nonguix-substitutes` in `guix/system.scm`.

To make two machines build the *same* system, freeze the channel commits:

```bash
guix describe -f channels > channels-lock.scm    # commit this
guix time-machine -C channels-lock.scm -- system reconfigure guix/system.scm
```

### 2. The system

```bash
sudo guix system reconfigure guix/system.scm
```

Reboot and pick **dwm** at the SLiM prompt.

Every reconfigure is a generation, so a bad one is never fatal — pick an older
entry in the GRUB menu, or:

```bash
sudo guix system roll-back
guix system list-generations
```

`guix/system.scm` is one self-contained file on purpose: a module split needs
`-L .` on every invocation and has broken `reconfigure` here before. It
carries **this** machine's facts, so for another one edit `host-name`, the
user account, the file-system and swap UUIDs (`lsblk -f`), and the `xrandr`
line in `dwm-start` if your outputs differ.

### 3. The user

```bash
guix home reconfigure guix/home.scm
```

Shell (`bash/bashrc`: Tokyo Night prompt, `EDITOR=emacsclient`), the PipeWire
services, and the `~/.config` seeds for dunst, fcitx5 and Doom.

Audio belongs to Shepherd here, which is why `dwm-start` — unlike the Artix
one — does not launch `pipewire` itself.

### 4. Doom Emacs

The framework is a git checkout and stays imperative:

```bash
git clone https://github.com/doomemacs/core ~/.config/emacs
~/.config/emacs/bin/doom install
```

`guix/system.scm` already installs what `doom doctor` asks for. Language
servers and compilers are deliberately **not** in the system configuration —
use `guix shell rust rust-analyzer` in the project that needs them.

### 5. Non-free apps (optional)

```bash
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install com.brave.Browser com.discordapp.Discord com.spotify.Client
```

## Testing it first, in QEMU

`guix system vm` replaces the root file system and boots the kernel directly,
so it ignores the UUIDs and the bootloader — the same file works as a test VM
with no second copy to keep in sync:

```bash
guix system vm guix/system.scm     # prints a script; run it
```

The account has no password, so in the VM switch to a console with
**Ctrl+Alt+F1**, log in as `root`, run `passwd void`, then return to SLiM with
**Ctrl+Alt+F7**.

Clone this repository rather than copying the directory: the package
definitions select their sources with `git-predicate`, which outside a
checkout falls back to copying everything, build artefacts included.

What a VM cannot tell you: backlight, WiFi firmware, the dual-monitor layout
and DP-1's 180 Hz.

## Files

```
guix/channels.scm   channels (nonguix, for the firmware)
guix/system.scm     the whole desktop: the five packages, services, SLiM
guix/home.scm       shell, PipeWire, ~/.config seeds
dwm-start           the session: daemons, monitors, then exec dwm
dwm/ st/ dmenu/ slstatus/   vendored sources, patches and config.h
utils/              the C utilities
doom/               $DOOMDIR: init.el, config.el, packages.el
bash/ dunst/ fcitx5/        deployed by home.scm (bashrc sets EDITOR=emacsclient)
```

Machine-specific setup — monitor layout, wallpaper, pointer warp — lives in
`dwm-start`.

## Keybindings

MODKEY is **Super**.

| Key | Action |
|-----|--------|
| `Super+d` / `Super+Return` | dmenu / st |
| `Super+e` / `Super+Shift+b` | Thunar / Brave |
| `Super+Shift+e` | Emacs in tmux |
| `Super+v` / `Super+p` | clipboard history / CPU profile |
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
| Brightness / Volume keys | `brightness-notify`, `pactl` |

## Utilities (`utils/`)

Plain POSIX C, one `config.h` each.

```bash
make -C utils test-util && ./utils/test-util     # 10 cases, pure
```

The Guix package runs exactly that during the build. `make -C utils test`
additionally runs `test-dmenu`, which calls `dmenu_open()` — it spawns a real
dmenu and blocks on a selection, so run it only from an interactive session,
never in a build.

- **battery-notify** — low/critical notifications, 30 s tick
- **brightness-notify** — brightnessctl plus an OSD notification
- **dmenu-clipd** / **dmenu-clip** — clipboard daemon and history browser
- **dmenu-cpupower** — CPU governor selector
- **dmenu-session** — lock / logout / reboot / shutdown

## Differences from the Arch/Artix build

Every one of these is forced by what Guix packages, not a preference:

- **Lock:** `slock`, not `betterlockscreen`, which Guix does not package. It is
  setuid through `screen-locker-service-type`; without that service it cannot
  authenticate.
- **Login:** **SLiM**. Guix has no `ly`. The session entry comes from the
  `dwm.desktop` that `suckless-session` installs — display managers discover
  sessions from `share/xsessions`.
- **Browser:** Brave via Flatpak.
- **Power profiles:** `cpupower`. Guix has no `power-profiles-daemon`, and no
  `linux-tools` package.
- **Input method:** fcitx5 + **anthy**; Guix does not package mozc.
- **Fonts:** the configs ask for `Iosevka`, not `Iosevka Nerd Font` — Guix has
  no Nerd-patched Iosevka. The glyphs slstatus prints still appear:
  `font-nerd-symbols` is installed and dwm, st and Pango all fall back per
  glyph on their own (`drw.c`'s nomatches cache, `x.c`'s frc cache).
- **No `~/.xprofile`:** sourcing it is an Arch/Debian display-manager
  convention that SLiM does not follow. The three input-method exports live in
  `dwm-start`, which is the only thing guaranteed to run.
- **Audio is a Shepherd service** (`home-pipewire-service-type`), so
  `dwm-start` does not start the daemons by hand; doing both would race.
- **`dwm-start` sets `XDG_DATA_DIRS`.** `dmenu_run_desktop` scans
  `$XDG_DATA_DIRS/applications`, and its built-in default
  (`/usr/local/share:/usr/share`) does not exist on Guix — without this the
  launcher lists nothing.

## Troubleshooting

**The dwm session is missing from the SLiM list.** SLiM discovers sessions
from `.desktop` files; check the reconfigure actually took:

```bash
ls /run/current-system/profile/share/xsessions/
```

**slock does nothing, or will not unlock.** It needs to be setuid, which
`screen-locker-service-type` arranges:

```bash
ls -l /run/setuid-programs/slock     # expect -rws...
```

**Fonts render as boxes.** Nerd Fonts do *not* need the Nonguix channel, and
there is no `nerd-fonts` package — nor a Nerd-patched Iosevka:

```bash
fc-list | grep -i "iosevka\|nerd"    # expect Iosevka + Symbols Nerd Font
fc-cache -f
```

**Super+d opens an empty menu, or launches nothing.** `dmenu_run_desktop`
reads `$XDG_DATA_DIRS/applications` and pipes the choice into `gtk-launch`
(from `gtk+`). Check both:

```bash
echo $XDG_DATA_DIRS | tr : '\n' | grep profile
command -v gtk-launch
```

**No battery or brightness notifications.** Those utilities shell out to
`notify-send`, which comes from `libnotify` — separate from the `dunst`
daemon that displays them:

```bash
command -v notify-send && notify-send test
```

**No sound.** PipeWire runs as a Guix Home service, not from `dwm-start`:

```bash
herd status pipewire
```

**Reconfigure is compiling the kernel.** nonguix's substitute server was never
authorised on the building machine — see step 1.

**cpupower not found.** The package is `cpupower`. There is no `linux-tools`
in Guix; that name has cost this repository a commit before.

## Contributing

`CLAUDE.md` holds the project context: the reference machine, the parity
matrix, and the Guix facts behind these decisions.

## License

See the LICENSE files in each subdirectory (dwm/, st/, dmenu/, slstatus/,
utils/).
