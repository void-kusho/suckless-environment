;;; Suckless Environment — Guix Package Manifest
;;; ==============================================
;;; A flat list of all packages needed for the suckless environment.
;;; This is the simplest way to install everything on an existing Guix system.
;;;
;;; Usage:
;;;   guix package -m guix/manifest.scm
;;;
;;; After installing, run ./install.sh to build and install the suckless tools
;;; from source (dwm, st, dmenu, slstatus, utils).

(specifications->manifest
 '(;; === Build tools ===
   "gcc-toolchain"
   "make"
   "pkg-config"
   "git"

   ;; === X11 and suckless dependencies ===
   "libxft"
   "libxinerama"
   "libxrender"
   "freetype"
   "fontconfig"
   "harfbuzz"
   "imlib2"
   "zlib"
   "xorg-server"
   "xinit"

   ;; === Fonts ===
   "font-gnu-freefont"
   "font-liberation"
   "font-dejavu"

   ;; === Notification daemon ===
   "dunst"

   ;; === Screenshot ===
   "flameshot"

   ;; === Clipboard ===
   "xclip"
   "xsel"

   ;; === Display utilities ===
   "xdotool"
   "xrandr"
   "feh"

   ;; === Compositor ===
   "picom"

   ;; === File manager ===
   "thunar"
   "thunar-volman"
   "thunar-archive-plugin"
   "thunar-media-tags-plugin"
   "gvfs"
   "tumbler"

   ;; === Audio ===
   "pulseaudio"
   "pamixer"
   "pipewire"
   "pipewire-pulseaudio"
   "wireplumber"

   ;; === Brightness ===
   "brightnessctl"

   ;; === Power management ===
   "linux-tools"

   ;; === Input method ===
   "fcitx5"
   "fcitx5-configtool"

   ;; === Polkit ===
   "polkit-gnome"

   ;; === Editors and terminal tools ===
   "emacs"
   "ripgrep"
   "fd"
   "gnupg"
   "hicolor-icon-theme"
   "tmux"
   "btop"
   "neofetch"

   ;; === Networking ===
   "network-manager-applet"

   ;; === Bluetooth ===
   "bluez"

   ;; === Flatpak (for non-free apps) ===
   "flatpak"

   ;; === Archive tools ===
   "zip"
   "unzip"

   ;; === Image processing ===
   "resvg"

   ;; === HTTPS ===
   "nss-certs"))
