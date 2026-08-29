;;; Suckless Environment — Guix Home
;;;
;;; The USER half of the desktop.  suckless/desktop.scm installs every package
;;; system-wide, so this profile stays package-free; its job is the interactive
;;; shell, the audio stack and the per-user configuration files.
;;;
;;;   make home        # guix home reconfigure -L . home.scm
;;;
;;; NOTE: the files below are SYMLINKS into the store, which is what makes
;;; them declarative — editing ~/.config/doom/config.el in place will fail.
;;; Edit the copy in this repository and re-run `make home'.  To get editable
;;; copies instead, replace the service with a seed-if-absent activation.
;;;
;;; The Wayland and input-method environment variables deliberately live in
;;; dwl/dwl-session, not here: a TTY login is not a Wayland session and must
;;; not claim to be one.

(use-modules (gnu home)
             (gnu home services)
             (gnu home services shells)
             (gnu home services sound)
             (guix gexp))

(home-environment
 (packages '())

 (services
  (list
   ;; ~/.profile — read by login shells, including the one greetd hands the
   ;; session to.  Keep it to things a non-interactive shell also needs.
   (service home-shell-profile-service-type
            (list (plain-file "profile" "\
# Doom's command line (doom install / doom sync).
export PATH=\"$HOME/.config/emacs/bin:$PATH\"

# emacsclient reuses a running daemon and falls back to a fresh emacs.
export EDITOR='emacsclient -a emacs'
export VISUAL=\"$EDITOR\"
")))

   ;; Interactive bash: history, shopts, Tokyo Night prompt, aliases.
   (service home-bash-service-type
            (home-bash-configuration
             (bashrc (list (local-file "bash/bashrc")))))

   ;; PipeWire, implementing PulseAudio and ALSA.  dwl-session deliberately
   ;; does NOT start these by hand; Shepherd owns them.
   (service home-pipewire-service-type
            (home-pipewire-configuration (enable-pulseaudio? #t)))

   ;; Per-user configuration, deployed under ~/.config.
   ;; (home-environment has no `files' field — this service is the mechanism.)
   (service home-xdg-configuration-files-service-type
            `(("foot/foot.ini"   ,(local-file "foot/foot.ini"))
              ("dunst/dunstrc"   ,(local-file "dunst/dunstrc"))
              ("fcitx5/profile"  ,(local-file "fcitx5/profile"))
              ("fcitx5/config"   ,(local-file "fcitx5/config"))
              ;; $DOOMDIR.  Doom only reads these; its mutable state lives in
              ;; ~/.config/emacs and ~/.local/share/doom.
              ("doom/init.el"     ,(local-file "doom/init.el"))
              ("doom/config.el"   ,(local-file "doom/config.el"))
              ("doom/packages.el" ,(local-file "doom/packages.el")))))))
