;;; Suckless Environment — Guix Home Configuration
;;; =================================================
;;; This is a declarative, reproducible home configuration for
;;; all user-level packages and services.
;;;
;;; Usage:
;;;   guix home reconfigure guix/home.scm
;;;
;;; What this configures:
;;;   - All suckless tools (built from source via packages)
;;;   - All runtime dependencies
;;;   - PipeWire audio stack
;;;   - Notification daemon (dunst)
;;;   - Input method (fcitx5)
;;;   - Flatpak (for non-free apps: Brave, Discord, Spotify)
;;;   - Shell profile (PATH, environment variables)

(use-modules (gnu home)
             (gnu home services)
             (gnu home services shell)
             (gnu home services sound)
             (gnu home services xorg)
             (gnu home services desktop)
             (gnu packages)
             (gnu packages admin)
             (gnu packages base)
             (gnu packages bash)
             (gnu packages certs)
             (gnu packages compression)
             (gnu packages curl)
             (gnu packages fontutils)
             (gnu packages freedesktop)
             (gnu packages glib)
             (gnu packages gnome)
             (gnu packages gtk)
             (gnu packages image)
             (gnu packages linux)
             (gnu packages networking)
             (gnu packages package-management)
             (gnu packages pdf)
             (gnu packages pkg-config)
             (gnu packages pulseaudio)
             (gnu packages python)
             (gnu packages texinfo)
             (gnu packages version-control)
             (gnu packages emacs)
             (gnu packages gnupg)
             (gnu packages rust-apps)
             (gnu packages web-browsers)
             (gnu packages wm)
             (gnu packages xdisorg)
             (gnu packages xfce)
             (gnu packages xorg)
             (guix gexp)
             (guix packages)
             (guix download)
             (guix build-system gnu)
             ((guix licenses) #:prefix license:))

(home-environment
  ;; Shell configuration
  (shell bash)

  ;; Packages — everything the user needs
  (packages
   (append
    (list
     ;; === Build tools ===
     gcc-toolchain
     make
     pkg-config
     git

     ;; === X11 and suckless dependencies ===
     libxft
     libxinerama
     libxrender
     freetype
     fontconfig
     harfbuzz
     imlib2
     zlib

     ;; === Fonts ===
     font-gnu-freefont
     font-liberation
     font-dejavu

     ;; === Core suckless tools (installed separately via install.sh) ===
     ;; dwm, st, dmenu, slstatus — built from repo source
     ;; The repo's install.sh handles building and installing these

     ;; === Notification daemon ===
     dunst

     ;; === Screenshot ===
     flameshot

     ;; === Clipboard ===
     xclip
     xsel

     ;; === Display utilities ===
     xdotool
     xrandr
     feh

     ;; === Compositor ===
     picom

      ;; === File manager ===
      thunar
      thunar-volman
      thunar-archive-plugin
      thunar-media-tags-plugin
      gvfs
      tumbler

     ;; === Audio ===
     pulseaudio
     pamixer

     ;; === Brightness ===
     brightnessctl

     ;; === Power management ===
     linux-tools          ; provides cpupower

     ;; === Input method ===
     fcitx5
     fcitx5-configtool

     ;; === Polkit ===
     polkit-gnome

      ;; === Editors and terminal tools ===
      emacs
      ripgrep
      fd
      gnupg
      hicolor-icon-theme
      tmux
      btop
      neofetch

     ;; === Networking ===
     network-manager-applet

     ;; === Bluetooth ===
     bluez

     ;; === Flatpak (for non-free apps) ===
     flatpak

     ;; === Archive tools ===
     zip
     unzip

     ;; === Image processing ===
     resvg

     ;; === HTTPS ===
     nss-certs)

    %base-packages))

  ;; Services
  (services
   (list
    ;; PipeWire audio stack
    (service home-pipewire-service-type
             (home-pipewire-configuration
              (enable-pulseaudio? #t)))

    ;; Shell environment — PATH and variables
    (service home-shell-profile-service-type
             (list
              (plain-file "profile"
                          "# Ensure ~/.local/bin is in PATH
export PATH=\"$HOME/.local/bin:$PATH\"

# Guix profile
export PATH=\"$HOME/.guix-profile/bin:$PATH\"

# fcitx5 input method
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx

# XDG paths
export XDG_DATA_DIRS=\"$HOME/.guix-profile/share:$XDG_DATA_DIRS\"
export XDG_CONFIG_DIRS=\"$HOME/.guix-profile/etc/xdg:$XDG_CONFIG_DIRS\"
")))))

  ;; Home directory files
  (files
   `(("config/dunst/dunstrc"
      ,(local-file "../dunst/dunstrc"))
     ("config/fcitx5/profile"
      ,(local-file "../fcitx5/profile"))
     ("config/fcitx5/config"
      ,(local-file "../fcitx5/config"))
     ;; Doom Emacs config
     ("config/doom/init.el"
      ,(local-file "../doom/init.el"))
     ("config/doom/config.el"
      ,(local-file "../doom/config.el"))
     ("config/doom/packages.el"
      ,(local-file "../doom/packages.el")))))
