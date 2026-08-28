;;; Suckless Environment — Guix Home Configuration
;;; =================================================
;;; Declarative, reproducible HOME configuration (user-level) that works
;;; alongside guix/system.scm.
;;;
;;; Split philosophy (mirrors Guix conventions, no duplication):
;;;   * guix/system.scm  — the whole desktop: suckless tools, session
;;;     daemons, apps, fonts, users, services, greetd, udev rules.  This is
;;;     the OS-level "module".
;;;   * guix/home.scm    — USER-level: interactive shell (bash), the
;;;     shell/profile environment (PATH, fcitx5 IM), PipeWire audio, and
;;;     the per-user config seeds (~/.config/...).  NO packages that
;;;     system.scm already installs.
;;;
;;; Because system.scm already installs every package, this home
;;; environment keeps a package-free profile; its real value is the
;;; environment, shell and per-user config seeds.
;;;
;;; Usage:
;;;   guix home reconfigure guix/home.scm
;;;
;;; What this configures:
;;;   - interactive bash (~/.bashrc: Tokyo Night prompt/colors/aliases)
;;;   - shell profile (~/.profile: PATH, EDITOR, fcitx5 IM + Wayland env vars)
;;;   - PipeWire audio stack (pulse + ALSA)
;;;   - config seeds: helix, dunst, fcitx5, foot (~/.config/...)

(use-modules (gnu home)
             (gnu home services)
             (gnu home services shells)
             (gnu home services sound)
             (guix gexp))

(home-environment
  ;; No packages here: guix/system.scm already installs the whole desktop
  ;; (tools, session daemons, apps, fonts), so this home profile is kept
  ;; deliberately package-free to avoid duplicating the system profile.
  ;; The interactive (login) shell is bash, wired up by home-bash-service-type
  ;; below — there is no `shell' field on home-environment itself.
  (packages '())

  ;; Services
  (services
   (list
    ;; Shell profile: PATH, editor, and the fcitx5 input-method env vars
    ;; (exported for every session, so no .xprofile is needed).
    (service home-shell-profile-service-type
             (list
              (plain-file "profile"
                          "# Ensure ~/.local/bin (built suckless utils + dmenu->wmenu shim) is first.
export PATH=\"$HOME/.local/bin:$PATH\"

# Guix (system) profile
export PATH=\"/run/current-system/profile/bin:$PATH\"

# Guix home profile
export PATH=\"$HOME/.guix-home/profile/bin:$PATH\"

# Default editor — Helix (hx)
export EDITOR=hx

# fcitx5 input method (see ~/.config/fcitx5)
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx

# Wayland session (set here so GUI apps pick the native backend regardless
# of how the session is launched: dwl-start or the greetd/tuigreet dwl-session).
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=dwl
export GDK_BACKEND=wayland
export QT_QPA_PLATFORM=wayland
export MOZ_ENABLE_WAYLAND=1

# XDG paths
export XDG_DATA_DIRS=\"$HOME/.guix-home/profile/share:$XDG_DATA_DIRS\"
export XDG_CONFIG_DIRS=\"$HOME/.guix-home/profile/etc/xdg:$XDG_CONFIG_DIRS\"
")))

    ;; Bash interactive config: Tokyo Night prompt/colors/aliases/neofetch.
    ;; Deployed as ~/.bashrc (the file itself guards non-interactive runs).
    (service home-bash-service-type
             (home-bash-configuration
              (bashrc (list (local-file "../bash/bashrc")))))

    ;; PipeWire audio stack (implements PulseAudio + ALSA).
    (service home-pipewire-service-type
             (home-pipewire-configuration
              (enable-pulseaudio? #t)))))

  ;; Per-user config seeds, deployed into ~/.config/...
  (files
   `(("config/helix/config.toml"
      ,(local-file "../helix/config.toml"))
     ("config/dunst/dunstrc"
      ,(local-file "../dunst/dunstrc"))
     ("config/fcitx5/profile"
      ,(local-file "../fcitx5/profile"))
     ("config/fcitx5/config"
      ,(local-file "../fcitx5/config"))
     ("config/foot/foot.ini"
      ,(local-file "../foot/foot.ini")))))
