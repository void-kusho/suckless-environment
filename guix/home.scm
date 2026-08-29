;;; Suckless Environment — Guix Home
;;;
;;;   guix home reconfigure guix/home.scm
;;;
;;; The USER half only.  guix/system.scm installs every package system-wide,
;;; so this profile stays package-free; its job is the interactive shell, the
;;; audio stack and the per-user configuration files.
;;;
;;; Three fields that do NOT exist on home-environment, and used to be here:
;;; `shell', `files', and the system-only %base-packages.  Files are deployed
;;; through home-xdg-configuration-files-service-type; the login shell comes
;;; from home-bash-service-type.

(use-modules (gnu home)
             (gnu home services)
             (gnu home services shells)      ; shellS, plural
             (gnu home services sound)
             (guix gexp))

(home-environment
 (packages '())

 (services
  (list
   ;; ~/.profile — read by login shells.  The session's own environment
   ;; (input method, PATH into the system profile) is set by dwm-start, which
   ;; is the only thing that reliably runs for a graphical login.
   (service home-shell-profile-service-type
            (list (plain-file "profile" "\
# Doom's command line (doom install / doom sync).
export PATH=\"$HOME/.config/emacs/bin:$PATH\"

# emacsclient reuses a running daemon and falls back to a fresh emacs.
export EDITOR='emacsclient -a emacs'
export VISUAL=\"$EDITOR\"
")))

   ;; Interactive bash: history, Tokyo Night prompt, aliases.
   (service home-bash-service-type
            (home-bash-configuration
             (bashrc (list (local-file "../bash/bashrc")))))

   ;; PipeWire, implementing PulseAudio and ALSA.
   (service home-pipewire-service-type
            (home-pipewire-configuration (enable-pulseaudio? #t)))

   ;; Per-user configuration, deployed under ~/.config.
   (service home-xdg-configuration-files-service-type
            `(("dunst/dunstrc"    ,(local-file "../dunst/dunstrc"))
              ("fcitx5/profile"   ,(local-file "../fcitx5/profile"))
              ("fcitx5/config"    ,(local-file "../fcitx5/config"))
              ;; $DOOMDIR.  Doom only reads these; its mutable state lives in
              ;; ~/.config/emacs and ~/.local/share/doom.
              ("doom/init.el"     ,(local-file "../doom/init.el"))
              ("doom/config.el"   ,(local-file "../doom/config.el"))
              ("doom/packages.el" ,(local-file "../doom/packages.el")))))))
