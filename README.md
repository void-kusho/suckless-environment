# suckless-environment

A hardened, C-native utility suite for a **dwl**-based **Wayland** desktop,
configured declaratively for **GNU Guix** (Shepherd). The compositor is
**dwl** (the Wayland wlroots spin-off of dwm), with a `foot` terminal,
`wmenu` menus, and the standard wlroots screenshot/lock/idle tools.

> Legacy: the historical Arch/Artix path (install.sh, dwm/st/dmenu, SLiM) was
> fully X11 and has been removed. The current focus (and this document) is the
> Guix/Wayland (dwl) desktop; the Guix config in `guix/` is the way forward.

## Overview

| Role | Tool |
|------|------|
| Compositor / window manager | **dwl** (dynamic Wayland compositor) |
| Status bar | dwl's built-in bar, fed by `dwl-status` |
| Terminal | **foot** |
| Program / command launcher | **wmenu** (`wmenu-run`) + `dmenu-shim` |
| Clipboard | **wl-clipboard** (`wl-copy`/`wl-paste`) + `dmenu-clipd`/`dmenu-clip` |
| Screenshot (Print) | **grim** + **slurp** → `wl-copy` |
| Lock screen | **swaylock** |
| Screen blanking / idle | **swayidle** → swaylock |
| Wallpaper | **swaybg** |
| Monitor layout | **wlr-randr** |
| X11 fallback | **xwayland** |
| Notifications | dunst |
| Display manager | **greetd** + **tuigreet** (X11-free console greeter) |

The `dmenu-*` utilities (`dmenu-clip`, `dmenu-cpupower`, `dmenu-session`)
invoke the literal `dmenu` binary; a `~/.local/bin/dmenu` **shim** translates
the dwl keybind → `wmenu`, so the C utilities need no Wayland rewrite.

## Installation — GNU Guix

This is a fully declarative setup. **Guix is not installed on the host**; the
`.scm` files are validated in a VirtualBox VM (see `guix-vm.md`) and applied to
the laptop over SSH or directly on a Guix System.

### Step 1: Install Guix System

Follow the official guide: https://guix.gnu.org/manual/en/html_node/Installation.html

### Step 2: Channels (for Nonguix / non-free)

```bash
cp guix/channels.scm ~/.config/guix/channels.scm
guix pull
```

### Step 3: System configuration

This configures the dwl compositor, greetd (display manager), users, services, udev
rules, NetworkManager and Bluetooth:

```bash
sudo guix system reconfigure guix/system.scm
```

**Note:** Edit `guix/system.scm` first:
- Update `host-name` and `timezone`
- Update file-system UUIDs (use `blkid`)
- Set the bootloader EFI target for your host

### Step 4: Home configuration

Sets up the interactive shell (bash), Wayland + fcitx5 environment, PipeWire
audio, and per-user config seeds (helix, dunst, fcitx5, **foot**). All *packages*
come from `guix/system.scm` — this home profile stays package-free.

```bash
guix home reconfigure guix/home.scm
```

### Step 5: Non-free / Flatpak apps (optional)

```bash
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install com.brave.Browser com.discordapp.Discord com.spotify.Client
```

### Guix Configuration Files

```
guix/
├── channels.scm    # Channel definitions (with Nonguix)
├── system.scm      # shim → hosts/laptop.scm (backward compat)
├── services.scm    # shared suckless-system, services, packages
├── hosts/
│   ├── laptop.scm  # real hardware (artix-btw)
│   └── vm.scm      # QEMU/VirtualBox test host
├── home.scm        # Home config: shell, Wayland env, pipewire, config seeds
└── manifest.scm    # Flat package list
suckless/
└── packages.scm    # Declarative suckless package definitions (suckless-dwl, suckless-utils)
guix-vm.md          # VirtualBox test plan for the Guix config
```

### Guix-Specific Notes

- **Lock screen:** `swaylock` (via `dmenu-session` + automatic `swayidle`)
- **Display manager:** greetd + `tuigreet`, a TTY/console greeter that runs the
  dwl session via `--cmd dwl-session` (no X server involved)
- **Session:** either the packaged `dwl-session` (greetd/tuigreet → `dwl-status | dwl`)
  or the manual `./dwl-start`
- **Browser:** **Brave** (primary) via Flatpak — dwl's `BROWSER_CMD`; **LibreWolf** (secondary) is a Guix package
- **Power profiles:** `cpupower` from `linux-tools` (backed by `dmenu-cpupower`)
- **Reproducible:** the entire desktop is reproduced from `guix/`

## Testing in a VM

You don't need Guix installed on the host to validate the config — the hosts live in `guix/hosts/` and share logic in `guix/services.scm` + `suckless/packages.scm`:

- `guix/hosts/laptop.scm` — real hardware (`%suckless-laptop`)
- `guix/hosts/vm.scm` — QEMU/VirtualBox test host (`%suckless-vm`, no backlight, `/dev/vda`, `linux-libre`)
- `guix/system.scm` — thin shim → laptop (backward compat)

**A) Ephemeral QEMU VM (fastest, no VirtualBox):**
```bash
cp guix/channels.scm ~/.config/guix/channels.scm && guix pull
guix system vm -L . guix/hosts/vm.scm  # builds VM image + prints .../bin/run-vm.sh
./gnu/store/...-run-vm.sh       # boots VM; login on tty1 via greetd/tuigreet → dwl
```

**B) VirtualBox VM (persistent):**
Create a 30GB VM (Arch Linux 64-bit, 4GB RAM), boot the Guix System base ISO, install a minimal `/mnt/etc/config.scm`, then inside the VM:
```bash
git clone <this-repo> && cd suckless-environment
cp guix/channels.scm ~/.config/guix/channels.scm && guix pull
sudo guix system reconfigure -L . guix/hosts/laptop.scm   # or vm.scm inside the VM; primary compile gate
guix home reconfigure guix/home.scm
make -C utils install PREFIX="$HOME/.local"
```
Full VirtualBox steps, what to verify (greetd on tty1, `dwl | dwl-status`, `wmenu`, `wl-copy`, `swaylock`, PipeWire), and iterating are in `guix-vm.md`.

> Snapshot the VM before the first reconfigure.

## Keybindings

Compositor uses **Super (Windows/Logo)** as MODKEY (dwl's analogue of dwm's Mod4).

### Launch Applications

| Key | Action | Description |
|-----|--------|-------------|
| `Super+d` | spawn menucmd | `wmenu-run` launcher |
| `Super+Return` | spawn termcmd | `foot` terminal |
| `Super+e` | spawn | `thunar` file manager |
| `Super+Shift+b` | spawn | Brave browser |

### Window Management

| Key | Action | Description |
|-----|--------|-------------|
| `Super+j` | focusstack +1 | Focus next window |
| `Super+k` | focusstack -1 | Focus previous window |
| `Super+i` | incnmaster +1 | Grow master area |
| `Super+h` | setmfact -0.05 | Shrink master area |
| `Super+l` | setmfact +0.05 | Expand master area |
| `Super+z` | zoom | Bring window to master |
| `Super+Shift+C` | killclient | Close focused window |
| `Super+t` | setlayout tile | Tile layout |
| `Super+f` | setlayout float | Floating layout |
| `Super+m` | setlayout monocle | Monocle layout |
| `Super+space` | setlayout | Cycle layouts |
| `Super+Shift+space` | togglefloating | Toggle floating |

### Tag Navigation (`Super+[1-9]`)

| Key | Action | Description |
|-----|--------|-------------|
| `Super+[1-9]` | view | Switch to tag |
| `Super+0` | view | View all tags |
| `Super+Ctrl+[1-9]` | toggleview | Toggle tag visibility |
| `Super+Shift+[1-9]` | tag | Send window to tag |
| `Super+Shift+0` | tag | Send window to all tags |

### Monitor Navigation

| Key | Action | Description |
|-----|--------|-------------|
| `Super+,` | focusmon | Focus output to the left |
| `Super+.` | focusmon | Focus output to the right |
| `Super+Shift+,` | tagmon | Send window to left output |
| `Super+Shift+.` | tagmon | Send window to right output |

### System

| Key | Action | Description |
|-----|--------|-------------|
| `Super+Tab` | view | View last tag |
| `Super+v` | spawn clipcmd | `dmenu-clip` clipboard history |
| `Super+p` | spawn cpucmd | `dmenu-cpupower` CPU power profile |
| `Ctrl+Alt+Delete` | spawn sessioncmd | `dmenu-session` (lock/logout/reboot/shutdown) |
| `Ctrl+Alt+Backspace` | quit | Kill the compositor |
| `Super+Shift+Q` | quit | Exit dwl |
| `Ctrl+Alt+F1..F12` | chvt | Switch virtual terminal |

### Media Keys

| Key | Action | Description |
|-----|--------|-------------|
| `Print` | grim+slurp | Screenshot selection → clipboard (notify-send confirm) |
| Brightness Up | brightness-notify up | Increase brightness |
| Brightness Down | brightness-notify down | Decrease brightness |
| Volume Up | pactl +5% | Increase volume |
| Volume Down | pactl -5% | Decrease volume |
| Volume Mute | pactl toggle | Toggle mute |

## Utilities (C, in `utils/`)

### battery-notify
Monitors battery level, sends dunst notifications when low. Runs on a 30s loop
from the session launcher.

### brightness-notify
Adjusts brightness with `brightnessctl` and shows an OSD notification.

### dmenu-clip
Clipboard history browser. Lists cached entries via the `dmenu` shim (`wmenu`),
lets you restore any entry.

### dmenu-clipd
Clipboard daemon that watches `wl-paste --watch` and caches changes to disk.
De-duplicates by hash and prunes to a bounded LRU list. Runs as a session daemon.

### dmenu-cpupower
CPU power-profile selector (performance / balanced / power-saving) via `cpupower`.

### dmenu-session
Session menu for lock, logout, reboot, shutdown — `swaylock` for locking, isn't
tied to X11.

### dmenu-shim
The `~/.local/bin/dmenu` shim that maps the utils' native `dmenu` CLI to
`wmenu`, giving run/command menus a Tokyo Night look under Wayland.

## Troubleshooting

### "command not found" for dependencies

```bash
which dwl foot wmenu grim slurp swaylock   # check binaries are on PATH
echo $PATH                                 # ~/.local/bin and Guix profile are first
```

### Session doesn't start

```bash
cat ~/.config/suckless/autostart.sh   # per-machine hook (monitors, wallpaper)
cat ~/.local/bin/dwl-start             # manual entry point
```

Ensure `dwl-start` is executable, or log in through the `tuigreet` greeter.

### Screenshot / clipboard not working

The Print shortcut needs `grim`, `slurp`, `wl-copy` and `notify-send`; clipboard
history needs `wl-paste` and `dmenu-clipd`. All are in `guix/system.scm`'s
package list.

### swaylock locks but nothing happens / no keyboard

`swaylock` grabs input; type your password (no echo) and press Return. Add the
`-C` config if you need a custom color scheme.

### Fonts not rendering

The Nerd glyphs used by `foot.ini`, `dunst` and `dwl-status.sh` come from the
**`font-nerd-jetbrains-mono`** package, which is declared in
`guix/system.scm` (main Guix channel, no Nonguix needed). If glyphs show as
boxes (tofu), re-run `guix system reconfigure guix/system.scm` and refresh the
font cache (`fc-cache -f`).

## Contributing

For contributor documentation, AI assistant context, and project roadmap, see
`CLAUDE.md`.

## License

See the individual LICENSE files in each subdirectory (dwl/, foot/, utils/).
