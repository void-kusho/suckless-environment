# suckless-environment

A hardened, C-native utility suite for a dwm-based desktop environment targeting Arch Linux (systemd), Artix Linux (OpenRC + elogind), and GNU Guix (Shepherd).

## Supported Distributions

- **Arch Linux** — systemd init system
- **Artix Linux** — OpenRC init system with elogind
- **GNU Guix** — Shepherd init system

No other distributions are supported. No Wayland, no BSD, no macOS.

## Installation

### Arch Linux / Artix Linux

```bash
git clone https://github.com/YOUR_USERNAME/suckless-environment.git
cd suckless-environment
less install.sh          # review before running
./install.sh
```

The install script will:
1. Detect your distribution (Arch or Artix)
2. Install required dependencies via pacman
3. Build and install all suckless tools to `/usr/local/bin`
4. Build and install custom utilities to `~/.local/bin`
5. Copy configuration files to their proper locations

### GNU Guix

This environment supports GNU Guix with a declarative, reproducible configuration.

#### Step 1: Install Guix System

Follow the official installation guide:
https://guix.gnu.org/manual/en/html_node/Installation.html

#### Step 2: Apply channels (for Nonguix/non-free packages)

```bash
cp guix/channels.scm ~/.config/guix/channels.scm
guix pull
```

#### Step 3: Apply system configuration

This configures keyboard layout, udev rules, display manager, NetworkManager, Bluetooth, and system services.

```bash
sudo guix system reconfigure guix/system.scm
```

**Note:** Edit `guix/system.scm` before running:
- Update `host-name` to your hostname
- Update `timezone` to your timezone
- Update file system UUIDs (use `blkid` to find yours)
- Update bootloader target (e.g., `/dev/nvme0n1p1` for EFI)

#### Step 4: Apply home configuration

This installs all packages, configures PipeWire audio, dunst notifications, fcitx5 input method, and shell profile.

```bash
guix home reconfigure guix/home.scm
```

**Note:** Edit `guix/home.scm` before running:
- Update `name` to your username
- Update `home-directory` to your home path

#### Step 5: Build suckless tools from source

```bash
./install.sh
```

#### Step 6: Install non-free apps (optional)

```bash
# Flatpak setup
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install com.brave.Browser com.discordapp.Discord com.spotify.Client

# Nonguix (for Steam, Nerd Fonts)
guix install nerd-fonts
```

#### Guix Configuration Files

```
guix/
├── channels.scm    # Channel definitions (with Nonguix)
├── system.scm      # System config (keyboard, udev, display manager, services)
├── home.scm        # Home config (packages, pipewire, dunst, shell profile)
├── manifest.scm    # Flat package list (used by install.sh)
└── sddm-theme/     # Custom Tokyo Night SDDM login theme
    ├── theme.conf
    ├── Main.qml
    └── metadata.desktop
```

#### Guix-Specific Notes

- **Lock screen:** Uses `slock` (suckless) instead of `betterlockscreen`
- **Browser:** Defaults to brave via Flatpak
- **Power profiles:** Uses `cpupower` from `linux-tools` instead of `power-profiles-daemon`
- **Reproducible:** The entire system can be reproduced from `guix/` config files

## Keybindings

The window manager uses **Super (Windows key)** as the primary modifier (MODKEY).

### Launch Applications

| Key | Action | Description |
|-----|--------|-------------|
| `Super+d` | dmenu_run | Launch application |
| `Super+Return` | st | Open terminal |
| `Super+e` | thunar | Open file manager |
| `Super+Shift+b` | brave | Launch browser |

### Window Management

| Key | Action | Description |
|-----|--------|-------------|
| `Super+j` | focusstack +1 | Focus next window |
| `Super+k` | focusstack -1 | Focus previous window |
| `Super+h` | setmfact -0.05 | Shrink master area |
| `Super+l` | setmfact +0.05 | Expand master area |
| `Super+z` | zoom | Bring window to master |
| `Super+q` | killclient | Close focused window |
| `Super+t` | setlayout tile | Tile layout |
| `Super+f` | setlayout float | Floating layout |
| `Super+m` | setlayout monocle | Monocle layout |
| `Super+space` | setlayout | Cycle layouts |
| `Super+Shift+space` | togglefloating | Toggle floating |

### Tag Navigation

| Key | Action | Description |
|-----|--------|-------------|
| `Super+[1-9]` | view | Switch to tag |
| `Super+0` | view | View all tags |
| `Super+Shift+[1-9]` | tag | Send window to tag |
| `Super+Shift+0` | tag | Send window to all tags |

### Monitor Navigation

| Key | Action | Description |
|-----|--------|-------------|
| `Super+,` | focusmon -1 | Focus previous monitor |
| `Super+.` | focusmon +1 | Focus next monitor |
| `Super+Shift+,` | tagmon -1 | Send window to previous monitor |
| `Super+Shift+.` | tagmon +1 | Send window to next monitor |

### System

| Key | Action | Description |
|-----|--------|-------------|
| `Super+b` | togglebar | Toggle status bar |
| `Super+Tab` | view | View last tag |
| `Super+v` | dmenu-clip | Clipboard history |
| `Super+p` | dmenu-cpupower | CPU power profile |
| `Ctrl+Alt+Delete` | dmenu-session | Session menu (lock/logout/reboot/shutdown) |
| `Super+Shift+q` | quit | Exit dwm |
| `Super+Ctrl+Shift+q` | quit (1) | Force quit dwm |

### Media Keys

| Key | Action | Description |
|-----|--------|-------------|
| `Print` | flameshot gui | Screenshot (region select, annotate, copy) |
| `Brightness Up` | brightness-notify up | Increase brightness |
| `Brightness Down` | brightness-notify down | Decrease brightness |
| `Volume Up` | pactl set-sink-volume +5% | Increase volume |
| `Volume Down` | pactl set-sink-volume -5% | Decrease volume |
| `Volume Mute` | pactl set-sink-mute toggle | Toggle mute |

## Utilities

### battery-notify
Monitors battery level and sends notifications via dunst when low. Designed to run from cron or a timer.

### brightness-notify
Adjusts display brightness using brightnessctl and shows an OSD notification.

### dmenu-clip
Clipboard history browser. Shows cached clipboard entries via dmenu, lets you restore any entry.

### dmenu-clipd
Clipboard daemon that watches for clipboard changes and caches them to disk. Runs as a background service.

### dmenu-cpupower
CPU power profile selector. Switches between performance, balanced, and power-saving modes using cpupower (Guix) or power-profiles-daemon (Arch/Artix).

### dmenu-session
Session menu for lock screen, logout, reboot, and shutdown. Uses loginctl for session management.

## Troubleshooting

### "command not found" for dependencies

```bash
which dmenu st dwm slstatus   # check if binaries are installed
echo $PATH                    # verify ~/.local/bin is in PATH
```

Ensure `base-devel` (Arch/Artix) is installed. If using bash, add to `~/.bashrc`:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### AUR helper fails (Arch/Artix)

```bash
which yay paru   # check if AUR helper is installed
```

Install yay or paru manually first, or use pacman directly for dependencies.

### brightnessctl permissions

```bash
brightnessctl -l                    # list available devices
groups                              # check your groups
ls -la /sys/class/backlight/        # check backlight permissions
```

Add user to video group: `sudo usermod -aG video $USER`

### Session doesn't start

```bash
cat ~/.xprofile
cat ~/.local/bin/dwm-start
```

Ensure dwm-start is executable and referenced in `~/.xprofile`.

### Build fails with "X11/Xlib.h: No such file" (Guix)

Ensure `pkg-config` is available:
```bash
guix install pkg-config
```

### slock fails with "cannot open display" (Guix)

```bash
guix install slock
echo $DISPLAY  # should show :0 or similar
```

### cpupower not found (Guix)

```bash
guix install linux-tools
```

### Fonts not rendering (Guix)

Nerd Fonts require the Nonguix channel:
```bash
guix pull
guix install nerd-fonts
```

## Contributing

For contributor documentation, AI assistant context, and project roadmap, see:

- [CLAUDE.md](./CLAUDE.md) — AI assistant context and project specifications

## License

See individual LICENSE files in each subdirectory (dwm/, st/, dmenu/, slstatus/, utils/).
