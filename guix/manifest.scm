;;; Suckless Environment — Guix Package Manifest
;;; ==============================================
;;; A flat list of all packages needed for the suckless Wayland (dwl) desktop.
;;; This is the simplest way to install everything on an existing Guix system
;;; without `guix system reconfigure`.
;;;
;;; Usage:
;;;   guix package -m guix/manifest.scm
;;;
;;; The vendored suckless tools (dwl, utils) are built declaratively by
;;; guix/packages.scm and installed via guix/system.scm; this manifest only
;;; covers the surrounding packages.

(specifications->manifest
 '(;; === Build tools ===
   "gcc-toolchain"
   "make"
   "pkg-config"
   "git"

   ;; === Wayland / wlroots ecosystem ===
   "foot"            ; terminal
   "wmenu"           ; dmenu backend for the dmenu-* utils
   "wl-clipboard"    ; wl-copy/wl-paste
   "grim"            ; screenshots (Print key)
   "slurp"           ; region selection for grim
   "swaylock"        ; lock screen
   "swaybg"          ; wallpaper
   "swayidle"        ; idle -> lock
   "wlr-randr"       ; monitor layout
   "xwayland"        ; X11 app fallback

   ;; === Fonts ===
   "font-gnu-freefont"
   "font-liberation"
   "font-dejavu"

   ;; === Notification daemon ===
   "dunst"

   ;; === File manager ===
   "thunar"
   "thunar-volman"
   "gvfs"

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
   "vim"
   "neovim"
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
