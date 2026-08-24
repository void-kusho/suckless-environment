#!/bin/sh
#
# suckless-environment installer (Arch + Artix + Guix, POSIX sh)
# See .planning/phases/01-install-hardening-platform-detection/ for design notes.

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------------------------------------------------------------- config
# BUILD_DEPS additions:
# - harfbuzz       : st ligatures patch (hb.c)
# - imlib2, zlib   : st kitty-graphics patch (graphics.c)
# - libxrender     : st kitty-graphics links -lXrender
BUILD_DEPS="base-devel git libxft libxinerama libxrender freetype2 fontconfig \
harfbuzz imlib2 zlib xorg-server xorg-xinit"

# Runtime deps grouped by role. Installer-skipped on purpose: kernel,
# firmware, bootloader (grub/refind/os-prober/efibootmgr), init (openrc,
# elogind-openrc), artix-archlinux-support, AUR helper (handled separately).
RUNTIME_DEPS="\
ttf-iosevka-nerd noto-fonts-cjk noto-fonts-emoji \
feh picom dunst lxsession polkit-gnome \
fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-mozc \
libpulse pipewire pipewire-alsa pipewire-pulse wireplumber pamixer \
brightnessctl flameshot xclip xsel xdotool \
thunar thunar-volman gvfs gvfs-smb ntfs-3g \
bluez bluez-utils blueman \
networkmanager connman connman-gtk dhcpcd \
arc-gtk-theme papirus-icon-theme lxappearance \
vim neovim helix tmux btop neofetch \
nodejs npm jdk25-openjdk \
vlc discord spotify-launcher steam \
ly zip unzip resvg"

AUR_DEPS="brave-bin betterlockscreen i3lock-color gnome-bluetooth wiremix-git"

# ---------------------------------------------------------------- Guix package lists
# Guix uses different package names and has no AUR. Non-free packages
# (steam, discord, spotify, brave) are skipped — user installs manually
# via Nonguix channel or Flatpak after running install.sh.
BUILD_DEPS_GUIX="gcc-toolchain make pkg-config git libxft libxinerama \
libxrender freetype fontconfig harfbuzz imlib2 zlib xorg-server xinit"

RUNTIME_DEPS_GUIX="\
iosevka-nerd noto-fonts noto-fonts-emoji \
feh picom dunst lxsession polkit-gnome \
fcitx5 fcitx5-configtool fcitx5-gtk \
pulseaudio pipewire pipewire-pulseaudio wireplumber pamixer \
brightnessctl flameshot xclip xsel xdotool \
thunar thunar-volman gvfs ntfs-3g \
bluez blueman \
network-manager connman dhcpcd \
papirus-icon-theme lxappearance \
vim neovim helix tmux btop neofetch \
node openjdk \
vlc resvg zip unzip linux-tools"

# PPD_PKG, SERVICE_PKGS, INIT, AUR_HELPER set at runtime by
# detect_distro / ensure_aur_helper. SERVICE_PKGS carries -openrc
# supervisor variants on Artix (Arch ships systemd units inside base pkgs).
UDEV_RULE_SRC="$REPO_DIR/udev/90-backlight.rules"
UDEV_RULE_DST=/etc/udev/rules.d/90-backlight.rules
KEYBOARD_CONF_SRC="$REPO_DIR/xorg/00-keyboard.conf"
KEYBOARD_CONF_DST=/etc/X11/xorg.conf.d/00-keyboard.conf
SUDO_KEEPALIVE_PID=""

# ---------------------------------------------------------------- color + helpers (D-14)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RED='\033[31m'; C_GREEN='\033[32m'; C_YELLOW='\033[33m'
    C_BLUE='\033[34m'; C_CYAN='\033[36m'; C_RESET='\033[0m'
else
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''; C_RESET=''
fi

info() { printf '==> %s%s%s\n' "$C_CYAN"   "$*" "$C_RESET"; }
skip() { printf '==> %s[skip]%s %s\n'       "$C_BLUE"  "$C_RESET" "$*"; }
warn() { printf '==> %sWARN:%s %s\n'        "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '==> %sFAIL:%s %s\n'        "$C_RED"    "$C_RESET" "$*" >&2; exit 1; }
hr()   { printf -- '-----------------------------------------------------------------\n'; }

# ---------------------------------------------------------------- guards (D-04, D-01, D-02, D-03)
require_non_root() {
    [ "$(id -u)" -eq 0 ] && \
        die "do not run as root — run as your normal user; sudo will be invoked when needed"
    return 0
}

detect_distro() {
    [ -r /etc/os-release ] || die "/etc/os-release not found"
    # shellcheck disable=SC1091
    . /etc/os-release
    case "$ID" in
        arch)
            PPD_PKG="power-profiles-daemon"
            SERVICE_PKGS=""
            ;;
        artix)
            PPD_PKG="power-profiles-daemon-openrc"
            SERVICE_PKGS="bluez-openrc networkmanager-openrc connman-openrc ly-openrc"
            ;;
        guix)
            PPD_PKG=""
            SERVICE_PKGS=""
            ;;
        *)
            die "unsupported distro: $ID (this installer supports arch, artix, and guix)"
            ;;
    esac
    if [ "$ID" = "guix" ]; then
        if command -v herd >/dev/null 2>&1; then
            INIT=shepherd
        else
            INIT=unknown
        fi
    elif [ -d /run/openrc ]; then
        INIT=openrc
    elif [ -d /run/systemd/system ]; then
        INIT=systemd
    else
        die "no live init detected (neither /run/openrc nor /run/systemd/system) — running in a chroot?"
    fi
    if [ "$ID" != "guix" ]; then
        command -v pacman >/dev/null 2>&1 || die "pacman not found on $ID — broken system"
    fi
    if [ "$ID" = "guix" ]; then
        command -v guix >/dev/null 2>&1 || die "guix not found on $ID — broken system"
    fi
    info "distro: $ID / init: $INIT / ppd: ${PPD_PKG:-none}"
}

# ---------------------------------------------------------------- sudo keepalive (D-05)
sudo_keepalive_start() {
    sudo -v || die "sudo credentials required"
    (
        while true; do
            sudo -n true 2>/dev/null || exit
            sleep 60
        done
    ) &
    SUDO_KEEPALIVE_PID=$!
}

sudo_keepalive_stop() {
    if [ -n "$SUDO_KEEPALIVE_PID" ]; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || :
    fi
    SUDO_KEEPALIVE_PID=""
}

ensure_aur_helper() {
    if [ "$ID" = "guix" ]; then
        skip "AUR helper: not needed on Guix"
        return 0
    fi
    if command -v paru >/dev/null 2>&1; then
        AUR_HELPER=paru
        skip "AUR helper: paru already installed"
        return 0
    fi
    if command -v yay >/dev/null 2>&1; then
        AUR_HELPER=yay
        skip "AUR helper: yay already installed"
        return 0
    fi

    printf '%s\n' "No AUR helper found. Required for brave-bin + betterlockscreen."
    printf '%s\n' "  1) install paru (recommended)"
    printf '%s\n' "  2) install yay"
    printf '%s\n' "  3) abort"
    printf 'choose [1/2/3]: '

    if [ -t 0 ]; then
        read -r choice
    else
        read -r choice < /dev/tty
    fi

    case "$choice" in
        1) bootstrap_aur_helper paru https://aur.archlinux.org/paru.git ;;
        2) bootstrap_aur_helper yay  https://aur.archlinux.org/yay.git ;;
        3) die "aborted by user" ;;
        *) die "invalid choice: $choice" ;;
    esac
}

bootstrap_aur_helper() {
    _name=$1
    _url=$2

    info "bootstrapping $_name: installing base-devel + git prerequisites"
    # shellcheck disable=SC2086
    sudo pacman -S --needed --noconfirm base-devel git \
        || die "failed to install base-devel git (needed to build $_name)"

    command -v git     >/dev/null 2>&1 || die "git not installed after pacman step"
    command -v makepkg >/dev/null 2>&1 || die "makepkg not installed after pacman step"

    info "bootstrapping $_name from AUR: $_url"
    _tmp=$(mktemp -d) || die "mktemp failed"
    # shellcheck disable=SC2064
    trap "rm -rf '$_tmp'; sudo_keepalive_stop" EXIT

    ( cd "$_tmp" && git clone --depth 1 "$_url" "$_name" ) \
        || die "git clone $_url failed"
    ( cd "$_tmp/$_name" && makepkg -si --noconfirm ) \
        || die "makepkg for $_name failed"

    trap 'sudo_keepalive_stop' EXIT
    rm -rf "$_tmp"

    AUR_HELPER=$_name
    info "$_name installed"
}

# ---------------------------------------------------------------- AUR helper bootstrap (D-08) — added in Task 2

# ---------------------------------------------------------------- install steps — added in Plans 02/03

install_pkgs() {
    case "$ID" in
        guix)
            install_pkgs_guix
            ;;
        arch|artix)
            install_pkgs_pacman
            ;;
    esac
}

install_pkgs_guix() {
    info "installing guix packages via manifest"
    info "manifest: $REPO_DIR/guix/manifest.scm"
    guix package -m "$REPO_DIR/guix/manifest.scm" \
        || die "guix package install failed"
    info "packages installed — run 'guix home reconfigure guix/home.scm' for services"
}

install_pkgs_pacman() {
    info "installing pacman packages (build + runtime + PPD + service variants for $ID)"
    # shellcheck disable=SC2086   # intentional word-splitting on space-separated lists
    sudo pacman -S --needed --noconfirm $BUILD_DEPS $RUNTIME_DEPS $SERVICE_PKGS "$PPD_PKG" \
        || die "pacman install failed"

    info "installing AUR packages via $AUR_HELPER"
    # shellcheck disable=SC2086
    "$AUR_HELPER" -S --needed --noconfirm $AUR_DEPS \
        || die "$AUR_HELPER install failed"
}

install_udev_rule() {
    if [ "$ID" = "guix" ]; then
        skip "udev rule: managed declaratively via guix/system.scm"
        info "  See guix/system.scm — brightnessctl udev rules are included"
        return 0
    fi
    [ -r "$UDEV_RULE_SRC" ] || die "$UDEV_RULE_SRC not found in repo"

    if [ -r "$UDEV_RULE_DST" ] && sudo cmp -s "$UDEV_RULE_SRC" "$UDEV_RULE_DST"; then
        skip "udev rule already installed and up to date: $UDEV_RULE_DST"
        return 0
    fi

    info "installing $UDEV_RULE_DST"
    sudo install -m 0644 -o root -g root "$UDEV_RULE_SRC" "$UDEV_RULE_DST" \
        || die "failed to install $UDEV_RULE_DST"

    info "reloading udev rules + triggering backlight subsystem"
    sudo udevadm control --reload-rules \
        || warn "udevadm control --reload-rules failed"
    sudo udevadm trigger -s backlight \
        || warn "udevadm trigger -s backlight failed"
}

install_keyboard_conf() {
    if [ "$ID" = "guix" ]; then
        skip "keyboard config: managed declaratively via guix/system.scm"
        info "  See guix/system.scm — keyboard-layout is set there"
        return 0
    fi
    [ -r "$KEYBOARD_CONF_SRC" ] || die "$KEYBOARD_CONF_SRC not found in repo"

    if [ -r "$KEYBOARD_CONF_DST" ] && sudo cmp -s "$KEYBOARD_CONF_SRC" "$KEYBOARD_CONF_DST"; then
        skip "keyboard layout already installed and up to date: $KEYBOARD_CONF_DST"
        return 0
    fi

    info "installing $KEYBOARD_CONF_DST (persistent br/abnt2 layout)"
    sudo install -m 0644 -o root -g root "$KEYBOARD_CONF_SRC" "$KEYBOARD_CONF_DST" \
        || die "failed to install $KEYBOARD_CONF_DST"
    info "keyboard layout applies on next X server start (log out / reboot)"
}

enable_service() {
    _svc=power-profiles-daemon

    case "$INIT" in
        systemd)
            if systemctl is-enabled --quiet "$_svc" 2>/dev/null; then
                skip "$_svc already enabled (systemd)"
            else
                info "enabling $_svc via systemd"
                sudo systemctl enable --now "$_svc" \
                    || die "systemctl enable $_svc failed"
            fi
            ;;
        openrc)
            if rc-update -q show default 2>/dev/null | grep -qw "$_svc"; then
                skip "$_svc already in default runlevel (openrc)"
            else
                info "adding $_svc to default runlevel (openrc)"
                sudo rc-update add "$_svc" default \
                    || die "rc-update add $_svc failed"
                sudo rc-service "$_svc" start \
                    || warn "$_svc start failed — check 'rc-service $_svc status'"
            fi
            ;;
        shepherd)
            if [ -z "$_svc" ] || [ "$_svc" = "" ]; then
                skip "power-profiles-daemon: managed declaratively via guix/home.scm"
                info "  See guix/home.scm — PipeWire services are configured there"
                return 0
            fi
            if command -v herd >/dev/null 2>&1; then
                info "starting $_svc via shepherd"
                herd start "$_svc" 2>/dev/null \
                    || warn "herd start $_svc failed — check 'herd status $_svc'"
            fi
            ;;
        *)
            die "enable_service: unknown INIT=$INIT"
            ;;
    esac
}

ensure_groups() {
    _need=""
    _groups=",$(id -nG "$USER" | tr ' ' ',' ),"
    case "$_groups" in
        *,video,*) ;;
        *)         _need="${_need}video," ;;
    esac
    case "$_groups" in
        *,input,*) ;;
        *)         _need="${_need}input," ;;
    esac
    _need=${_need%,}

    if [ -z "$_need" ]; then
        skip "user $USER already in video,input"
        return 0
    fi

    info "adding $USER to groups: $_need"
    sudo usermod -aG "$_need" "$USER" \
        || die "usermod -aG $_need $USER failed"
    warn "log out and back in to activate new group membership"
}

# Guix config.h generation — create distro-specific config.h files
generate_guix_configs() {
    if [ "$ID" != "guix" ]; then
        return 0
    fi
    info "generating Guix-specific config.h files"

    # dmenu-session: use slock instead of betterlockscreen
    if [ ! -f "$REPO_DIR/utils/dmenu-session/config.h" ]; then
        cp "$REPO_DIR/utils/dmenu-session/config.def.h" \
           "$REPO_DIR/utils/dmenu-session/config.h"
        info "created utils/dmenu-session/config.h (slock backend)"
    fi

    # dmenu-cpupower: use cpupower instead of power-profiles-daemon
    if [ ! -f "$REPO_DIR/utils/dmenu-cpupower/config.h" ]; then
        cp "$REPO_DIR/utils/dmenu-cpupower/config.def.h" \
           "$REPO_DIR/utils/dmenu-cpupower/config.h"
        # Enable cpupower backend
        sed -i 's/#define USE_CPUPOWER 0/#define USE_CPUPOWER 1/' \
            "$REPO_DIR/utils/dmenu-cpupower/config.h"
        info "created utils/dmenu-cpupower/config.h (cpupower backend)"
    fi

    # dwm: set browser to brave via Flatpak
    # The user can override by editing dwm/config.h directly
    info "dwm browser: defaults to brave via Flatpak (edit dwm/config.h BROWSER_CMD to change)"
}

# INST-06: only install from utils/; never copy scripts/ to PATH.
install_suckless_tool() {
    _dir=$1
    _prefix="/usr/local"
    if [ "$ID" = "guix" ]; then
        _prefix="$HOME/.local"
    fi
    info "building $_dir (prefix: $_prefix)"
    make -C "$REPO_DIR/$_dir" clean PREFIX="$_prefix" \
        || die "make -C $_dir clean failed"
    # If config.h is root-owned from a prior `sudo make install`, this step fails.
    # D-21 defers the chown fix; manual workaround:
    #   sudo chown "$USER:$USER" dwm/config.h st/config.h dmenu/config.h slstatus/config.h
    make -C "$REPO_DIR/$_dir" PREFIX="$_prefix" \
        || die "make -C $_dir failed (check config.h ownership if it's root-owned)"
    info "installing $_dir (requires sudo)"
    sudo make -C "$REPO_DIR/$_dir" install PREFIX="$_prefix" \
        || die "sudo make -C $_dir install failed"
}

install_binaries() {
    install_suckless_tool dwm
    install_suckless_tool st
    install_suckless_tool dmenu
    install_suckless_tool slstatus

    info "building + installing utils/ to \$HOME/.local/bin"
    make -C "$REPO_DIR/utils" clean all \
        || die "make -C utils clean all failed"
    make -C "$REPO_DIR/utils" install \
        || die "make -C utils install failed"
}

install_dotfile() {
    _src=$1
    _dst=$2

    if [ -e "$_dst" ]; then
        if cmp -s "$_src" "$_dst"; then
            skip "$_dst up to date"
            return 0
        fi
        _bak="$_dst.bak.$(date +%Y%m%d-%H%M%S)"
        cp -p "$_dst" "$_bak" \
            || die "failed to back up $_dst"
        info "backed up existing $_dst to $_bak"
    fi

    mkdir -p "$(dirname "$_dst")"
    cp "$_src" "$_dst" \
        || die "failed to install $_dst"
    info "installed $_dst"
}

install_dotfiles() {
    install_dotfile "$REPO_DIR/dunst/dunstrc" "$HOME/.config/dunst/dunstrc"
    install_dotfile "$REPO_DIR/.xprofile"    "$HOME/.xprofile"
    install_dotfile "$REPO_DIR/dwm-start"    "$HOME/.local/bin/dwm-start"
    chmod +x "$HOME/.local/bin/dwm-start"
    # fcitx5 seed config: rest on keyboard-br, mozc on demand, no WM hotkey
    # clash. fcitx rewrites these on exit, so restart it after install
    # (`fcitx5 -r -d`) to load the new values.
    install_dotfile "$REPO_DIR/fcitx5/profile" "$HOME/.config/fcitx5/profile"
    install_dotfile "$REPO_DIR/fcitx5/config"  "$HOME/.config/fcitx5/config"
}

WARN_COUNT=0

v_ok()   { printf '  %sOK%s   %s\n' "$C_GREEN" "$C_RESET" "$*"; }
v_info() { printf '  %sINFO%s %s\n' "$C_BLUE"  "$C_RESET" "$*"; }
v_warn() { printf '  %sWARN%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; WARN_COUNT=$((WARN_COUNT + 1)); }

check_cmd() {
    _label=$1
    _cmd=$2
    _failmsg=$3
    if command -v "$_cmd" >/dev/null 2>&1; then
        v_ok "$_label: $(command -v "$_cmd")"
    else
        v_warn "$_failmsg"
    fi
}

verify_install() {
    hr
    info "verification summary (D-17: warnings only, never fatal)"
    hr

    # Path checks (D-16 items 1-9)
    check_cmd "dwm"               dwm               "dwm not on PATH — re-run install or check /usr/local/bin"
    check_cmd "st"                st                "st not on PATH"
    check_cmd "dmenu"             dmenu             "dmenu not on PATH"
    check_cmd "slstatus"          slstatus          "slstatus not on PATH"
    check_cmd "dunst"             dunst             "dunst not on PATH"
    check_cmd "brightnessctl"     brightnessctl     "brightnessctl not on PATH — brightness keys will fail"
    check_cmd "flameshot"         flameshot         "flameshot not on PATH — Print key screenshot will fail"
    check_cmd "loginctl"          loginctl          "loginctl missing — session actions will fail"

    if [ "$ID" = "guix" ]; then
        check_cmd "slock"             slock              "slock missing — dmenu-session lock will use fallback"
        check_cmd "cpupower"          cpupower           "cpupower missing (install linux-tools) — dmenu-cpupower will be non-functional"
    else
        check_cmd "betterlockscreen"  betterlockscreen  "betterlockscreen missing — dmenu-session lock will fail"
        check_cmd "powerprofilesctl"  powerprofilesctl  "powerprofilesctl missing — dmenu-cpupower will be non-functional"
    fi

    # 10. PPD reachability (distinguishes installed-but-dead from missing)
    if [ "$ID" = "guix" ]; then
        if _out=$(cpupower frequency-info -p 2>/dev/null) && [ -n "$_out" ]; then
            v_ok "cpupower reachable (current governor: $_out)"
        else
            v_warn "cpupower unreachable — check 'cpupower frequency-info'"
        fi
    else
        if _out=$(powerprofilesctl get 2>/dev/null) && [ -n "$_out" ]; then
            v_ok "power-profiles-daemon reachable (current profile: $_out)"
        else
            v_warn "power-profiles-daemon unreachable — check 'systemctl status power-profiles-daemon' (Arch) or 'rc-service power-profiles-daemon status' (Artix)"
        fi
    fi

    # 11. Session active
    if [ -n "${XDG_SESSION_ID:-}" ]; then
        _active=$(loginctl show-session "$XDG_SESSION_ID" --property=Active 2>/dev/null || true)
        case "$_active" in
            Active=yes) v_ok "session $XDG_SESSION_ID is active" ;;
            *)          v_warn "session $XDG_SESSION_ID is not active — some features require active session" ;;
        esac
    else
        v_info "no XDG_SESSION_ID — install.sh not run from a logged-in session (OK if run from tty)"
    fi

    # 12. Backlight device (glob-safe)
    set -- /sys/class/backlight/*/brightness
    if [ -e "$1" ]; then
        v_ok "backlight device: $(dirname "$1")"
    else
        v_info "no backlight device detected (desktop? headless?)"
    fi

    # 13. Groups (comma-framed, no false positives)
    _groups_check=",$(id -nG "$USER" | tr ' ' ',' ),"
    _have_video=0; _have_input=0
    case "$_groups_check" in *,video,*) _have_video=1 ;; esac
    case "$_groups_check" in *,input,*) _have_input=1 ;; esac
    if [ "$_have_video" -eq 1 ] && [ "$_have_input" -eq 1 ]; then
        v_ok "user $USER in groups: video,input"
    else
        v_warn "user $USER not in video,input — log out and back in to activate"
    fi

    # 14. Udev rule
    if [ "$ID" = "guix" ]; then
        v_info "udev rule: on Guix, managed via config.scm (see install output above)"
    elif [ -r /etc/udev/rules.d/90-backlight.rules ]; then
        v_ok "udev rule present: /etc/udev/rules.d/90-backlight.rules"
    else
        v_warn "/etc/udev/rules.d/90-backlight.rules not found"
    fi

    # 14b. Keyboard layout config + live layout (br/abnt2)
    if [ "$ID" = "guix" ]; then
        v_info "keyboard layout: on Guix, managed via config.scm (see install output above)"
    else
        if [ -r "$KEYBOARD_CONF_DST" ]; then
            v_ok "keyboard layout config present: $KEYBOARD_CONF_DST"
        else
            v_warn "$KEYBOARD_CONF_DST not found — keyboard may default to us"
        fi
        if command -v setxkbmap >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
            if setxkbmap -query 2>/dev/null | grep -q 'layout: *br'; then
                v_ok "active X keyboard layout: br"
            else
                v_warn "active X keyboard layout is not br — log out/in to apply $KEYBOARD_CONF_DST"
            fi
        else
            v_info "no X display — skipping live keyboard layout check"
        fi
    fi

    # 15. Dunst running
    if pgrep -x dunst >/dev/null 2>&1; then
        v_ok "dunst running"
    else
        v_info "dunst not running — will start with X session"
    fi

    hr
    if [ "$WARN_COUNT" -eq 0 ]; then
        info "verification passed with 0 warnings"
    else
        info "verification passed with $WARN_COUNT warning(s) — review above"
    fi
    # D-17: NEVER exit non-zero on warnings.
}

# ---------------------------------------------------------------- Guix non-free notice
print_guix_nonfree_notice() {
    if [ "$ID" != "guix" ]; then
        return 0
    fi
    hr
    info "Guix declarative configuration"
    hr
    echo "All configurations are in guix/ directory:"
    echo ""
    echo "  guix/channels.scm  — Channel definitions (copy to ~/.config/guix/channels.scm)"
    echo "  guix/system.scm    — System configuration (keyboard, udev, display manager)"
    echo "  guix/home.scm      — Home configuration (packages, pipewire, dunst)"
    echo "  guix/manifest.scm  — Package manifest (already used by install.sh)"
    echo ""
    echo "To make the system fully reproducible:"
    echo ""
    echo "  1. Copy channels.scm:"
    echo "     cp guix/channels.scm ~/.config/guix/channels.scm"
    echo "     guix pull"
    echo ""
    echo "  2. Apply system config (requires sudo):"
    echo "     sudo guix system reconfigure guix/system.scm"
    echo ""
    echo "  3. Apply home config:"
    echo "     guix home reconfigure guix/home.scm"
    echo ""
    hr
    info "Non-free software — manual install required"
    hr
    echo "The following packages are not in Guix main repos and were skipped:"
    echo ""
    echo "  Flatpak setup (required for Brave, Discord, Spotify):"
    echo "               flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"
    echo ""
    echo "  Steam:       Install via Nonguix channel"
    echo "               https://gitlab.com/nonguix/nonguix"
    echo ""
    echo "  Discord:     flatpak install com.discordapp.Discord"
    echo ""
    echo "  Spotify:     flatpak install com.spotify.Client"
    echo ""
    echo "  Brave:       flatpak install com.brave.Browser"
    echo ""
    echo "  Nerd Fonts:  Install via Nonguix channel"
    echo "               guix install nerd-fonts"
    hr
}

# ---------------------------------------------------------------- main
main() {
    require_non_root
    detect_distro
    if [ "$ID" != "guix" ]; then
        sudo_keepalive_start
        trap 'sudo_keepalive_stop' EXIT
        trap 'sudo_keepalive_stop; exit 130' INT
        trap 'sudo_keepalive_stop; exit 143' TERM
    fi

    ensure_aur_helper
    install_pkgs
    install_udev_rule
    install_keyboard_conf
    enable_service
    ensure_groups
    generate_guix_configs
    install_binaries
    install_dotfiles
    print_guix_nonfree_notice
    verify_install
    info "install complete"
}

main "$@"
