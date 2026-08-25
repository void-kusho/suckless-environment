# suckless-environment

A complete dwm-based desktop environment, built the suckless way and
packaged for **NixOS** (declarative).

| Component | Version | Customization |
|-----------|---------|---------------|
| dwm | 6.8 | alwayscenter, attachaside, restartsig, status2d+systray, Fibonacci layouts; Super modkey; Tokyo Night colors; Japanese tags |
| st | 0.9.3 | kitty-graphics, ligatures (harfbuzz), clickurl, clipboard, expected-anysize |
| dmenu | 5.4 | desktoponly patch (+ `dmenu_run_desktop`) |
| slstatus | 1.1 | status2d Tokyo Night bar: CPU / RAM / battery / volume (pamixer) / Japanese datetime |
| utils | 1.0 | 6 custom C utilities: battery-notify, brightness-notify, dmenu-session, dmenu-cpupower, dmenu-clip, dmenu-clipd |

On NixOS everything is built from the vendored sources in this repo by
plain `stdenv.mkDerivation` wrappers that call each tool's own Makefile —
the classic suckless workflow, fully declarative.

## Repository layout

```
dwm/ dmenu/ st/ slstatus/   vendored sources + your config.h (edit these!)
utils/                      custom C utilities + shared common code
nix/lib.nix                 tiny wrapper: runs each Makefile with PREFIX set
nix/packages.nix            one derivation per tool + utils suite
nix/module.nix              NixOS module: programs.suckless-environment.enable
default.nix                 entrypoint for classic configuration.nix users
flake.nix                   flake entrypoint (same module + packages)
hosts/minimal.nix           template configuration.nix (generic machine)
hosts/laptop.nix             this laptop: Intel TigerLake specifics
hosts/vm.nix                 disposable test VM (see below)
dunst/ fcitx5/ picom/       config seeds deployed declaratively on NixOS
helix/                      Helix editor config, seeded into ~/.config
bash/bashrc                 interactive bash config (prompt, colors, aliases)
```

## Full install guide (NixOS minimal + git)

Assumes NixOS minimal already installed, booting to a TTY login.

### 1. Get this repo into /etc/nixos

```sh
cd /etc/nixos
sudo git clone https://github.com/void-kusho/suckless-environment.git
sudo git checkout nixos          # the NixOS packaging lives on this branch
```

### 2. Enable it in /etc/nixos/configuration.nix

```nix
imports = [
  ./hardware-configuration.nix
  ./suckless-environment              # <- add this line
];

programs.suckless-environment.enable = true;

users.users.myuser = {
  isNormalUser = true;
  extraGroups = [ "wheel" "networkmanager" "video" "input" ];  # video/input = brightness
};
```

Personal apps can ride along through the module's escape hatch:

```nix
programs.suckless-environment.extraPackages = with pkgs; [
  discord steam vlc neovim tmux btop   # whatever you need
];
```

(See `hosts/minimal.nix` for a complete reference file.)

### 3. Apply

```sh
sudo nixos-rebuild switch
```

First run compiles all tools from source. The toggle sets up:

* **Session**: dwm+slstatus registered as default session (`none+dwm`),
  started by a launcher that brings up dunst, the clipboard daemon,
  lxpolkit, fcitx5 (mozc), flameshot, the battery monitor loop
* **Tools & utils**: all four suckless tools + the six C utilities
* **Apps**: thunar, brave, betterlockscreen, feh, brightnessctl,
  picom, xdotool, xclip/xsel, pactl
* **Input**: br/abnt2 keyboard layout, fcitx5+mozc Japanese input
* **System**: PipeWire audio, NetworkManager, bluetooth,
  power-profiles-daemon (Super+p menu), backlight udev rules,
  Iosevka Nerd Font + Noto CJK + emoji
* **Helix** (`hx`) as the standard editor — your `helix/config.toml` is
  seeded into `~/.config/helix` on first launch
* **Bash** — your interactive config (Tokyo Night prompt/colors,
  history, aliases, neofetch greeting) is injected via
  `programs.bash.interactiveShellInit`; `EDITOR=hx` system-wide

### 4. Log in

**With Ly** (or greetd/sddm/cosmic-greeter) — enable it next to the
toggle; X autostart flips on automatically:

```nix
services.displayManager.ly.enable = true;
```

Ly appears at boot with **dwm preselected**.

**Without any display manager** — log into a TTY and run `startx`
(installed for you; the generated xinitrc starts the same session).

### Autostart hook (machine-specific bits)

Monitor layouts and wallpapers differ per machine, so they are NOT
hardcoded. Create `~/.config/suckless/autostart.sh` — the session
sources it before anything else. Example (dual monitor laptop):

```sh
# ~/.config/suckless/autostart.sh
xrandr --output eDP-1 --mode 1920x1080 --rate 60 --pos 0x0 \
       --output DP-1 --primary --mode 1920x1080 --rate 180 --pos 1920x0
xdotool mousemove 2880 540
feh --no-fehbg --bg-fill ~/wallpapers/sushi_original.png
```

### Thunar: terminal & archives

Thunar's context menus work out of the box, no custom actions needed:

* **Open Terminal Here** — Thunar's native action runs `exo-open`,
  which reads `/etc/xdg/xfce4/helpers.rc` (`TerminalEmulator=st`) and
  finds st through the `st.desktop` entry the module ships. Works on
  any folder, spaces in paths included.
* **Extract Here / Create Archive…** — provided by
  `thunar-archive-plugin`, which delegates to **xarchiver**; backends
  `p7zip`, `zip`, `unzip` cover zip/tar.gz/tar.xz/7z and more.

If you previously had hand-made custom actions in
`~/.config/Thunar/uca.xml`, delete them (or start from an empty
`<actions/>`) — the native entries replace them.

### Compositor (vsync + animations)

The session starts **picom** automatically with a minimal config:
tear-free rendering (`vsync`), and subtle animations — windows slide up
when opened, down when closed (~0.15s). No shadows, transparency or
blur, and fullscreen apps bypass compositing, so nothing else changes.

Config lives in `picom/picom.conf` (deployed to `/etc/xdg/picom/`);
a user `~/.config/picom/picom.conf` overrides it. To disable entirely:

```nix
programs.suckless-environment.compositor.enable = false;
```

### Troubleshooting

* Brightness keys do nothing: your user must be in `video` (and `input`
  for keyboard backlight); re-login after adding.
* Japanese input dead in some app: fcitx5 env vars are exported per
  session — make sure the app was launched inside the session, not via
  `su`.
* Volume shows Muted/n/a: PipeWire user services must be running
  (`systemctl --user status pipewire pipewire-pulse wireplumber`).
* Using a greeter outside Ly/greetd/sddm/cosmic-greeter: add
  `services.xserver.autorun = true;`.

## Keybindings

`Mod` = Super. Highlights (full list in `dwm/config.h`):

| Key | Action |
|-----|--------|
| `Mod+d` | dmenu_run_desktop (app launcher) |
| `Mod+Return` | st |
| `Mod+v` | clipboard history (dmenu-clip) |
| `Mod+p` | CPU power profile (dmenu-cpupower) |
| `Ctrl+Alt+Delete` | session menu: lock/logout/reboot/shutdown |
| `Mod+e` / `Mod+Shift+b` | thunar / brave |
| `Print` | flameshot gui |
| `Mod+[1-9]`, `Mod+0` | tags / all |
| `Mod+t/f/m/r/Shift+r` | tile / float / monocle / spiral / rotated-spiral |
| `Mod+Shift+q` (quit) · `Mod+Ctrl+Shift+q` (force quit) | exit dwm |

Media keys: volume ±5% / mute via pactl, brightness via
brightness-notify (needs `video` group).

## Hardware layer

The module is hardware-agnostic. Machine-specific decisions live in a
host file — see `hosts/laptop.nix` for this laptop (Intel TigerLake
i5-1135G7 / Iris Xe, NVMe, BAT1, intel_backlight, dual-display
eDP-1 + DP-1@180Hz):

* Intel microcode updates
* VA-API video acceleration via `intel-media-driver` (iHD)
* `modesetting` Xorg driver (not the legacy xf86-video-intel)
* `services.thermald` — TigerLake throttling protection
* weekly `fstrim` for the SSD, `fwupd` for firmware updates

Copy the host file to `/etc/nixos/hosts/`, import it from
`configuration.nix`, add your generated `hardware-configuration.nix`,
and put your monitor layout in `~/.config/suckless/autostart.sh`
(the exact eDP-1/DP-1@180Hz lines are commented inside the host file).

## Test drive in a VM (disposable, production untouched)

`hosts/vm.nix` is a self-contained throwaway host — it never touches the
production configs. Build and run it on **any machine with Nix + flakes**
(the first build downloads ~1 GB from cache.nixos.org):

```sh
git clone -b nixos https://github.com/void-kusho/suckless-environment
cd suckless-environment
nix build .#vm
./result/bin/run-nixos-vm
```

A QEMU window opens; log in as **you** / password **test**, then run
`startx`. The VM shares your host's `/nix/store`, so rebuilds after
config changes are fast:

```sh
nix build .#vm && ./result/bin/run-nixos-vm
```

Headless (serial console only, e.g. for scripted checks):

```sh
QEMU_OPTS="-display none -serial stdio" ./result/bin/run-nixos-vm
```

What a VM run validates: boot chain, session startup (startx → dwm +
slstatus + picom), bash prompt/config, `hx` seeding, Thunar terminal &
archive actions, dunst/fcitx5, fonts (Japanese tags), NetworkManager.
What it cannot: real Iris Xe VA-API, your monitors @180 Hz, backlight,
battery BAT1 — those need bare metal.

## Customizing (NixOS)

Everything visual/behavioral lives in the per-tool `config.h` files and
`utils/*/config.h`:

```sh
$EDITOR dwm/config.h
sudo nixos-rebuild switch
```

No other file needs to change — derivations always build what is in the
source tree.

## Maintenance

* **Update a tool**: replace its vendored source with the new release,
  re-apply your `config.h` (and patches), bump `version` in
  `nix/packages.nix`.
* **Patch dwm/st**: apply the `.diff` by hand, keep the patch file in
  `<tool>/patches/`, commit both together.
* **Format Nix code**: `nix develop -c nixfmt nix/ hosts/ *.nix`
* Build artifacts are gitignored.

## Building packages standalone

Without NixOS at all:

```sh
nix-build nix/packages.nix -A st      # result/bin/st
nix build .#utils                     # all six C utilities
```

## Artix / Arch

The Artix/Arch installer and its session script live on the `artix`
branch: `git checkout artix && ./install.sh`.
