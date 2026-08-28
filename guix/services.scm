;;; Guix services — shared desktop services & packages
;;; =================================================
;;; Shared definitions for the suckless Wayland desktop.
;;; This module is imported by guix/system.scm and the host files
;;; under guix/hosts/*.scm.  It provides the composable
;;; `suckless-system' procedure, the `suckless-services' list and the
;;; `%suckless-system-packages' set, plus the dwl session helpers.
;;;
;;; The file lives at guix/services.scm so that (guix services) is
;;; found via the repo root on %load-path (see the eval-when below).

(eval-when (expand load eval)
  (add-to-load-path (string-append (dirname (current-filename)) "/..")))

(define-module (guix services)
  #:use-module (gnu)
  #:use-module (gnu system)
  #:use-module (gnu system nss)
  #:use-module (gnu system shadow)
  #:use-module (gnu system uuid)
  #:use-module (gnu system file-systems)
  #:use-module (gnu packages)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages fonts)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages base)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages bootloaders)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages lxde)
  #:use-module (gnu bootloader grub)
  #:use-module (gnu packages certs)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages image)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages librewolf)
  #:use-module (gnu packages video)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages window-management)
  #:use-module (gnu packages xfce)
  #:use-module (gnu packages networking)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages fcitx5)
  #:use-module (gnu packages web-browsers)
  #:use-module (gnu packages vim)
  #:use-module (gnu packages terminals)
  #:use-module (gnu packages text-editors)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services xorg)
  #:use-module (gnu services networking)
  #:use-module (gnu services dbus)
  #:use-module (gnu services desktop)
  #:use-module (gnu services sound)
  #:use-module (gnu services linux)
  #:use-module (gnu services shepherd)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix channels)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system trivial)
  #:use-module (suckless packages)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu system linux-initrd)
  #:export (suckless-system
            suckless-services
            %suckless-system-packages
            %backlight-udev-rules
            dwl-session
            %dwl-session-script
            %dwl-status-script))


;; --------------------------------------------------------------------
;; Shared desktop services & packages (the "module" part).
;; --------------------------------------------------------------------

;; Backlight access for the `video` group (and kbd backlight for
;; `input`).  sysfs attributes have no /dev node, hence RUN+= chgrp/chmod
;; instead of udev GROUP=/MODE= directives — mirrors nix/module.nix.
(define %backlight-udev-rules
  (plain-file "90-backlight.rules"
              "ACTION==\"add\", SUBSYSTEM==\"backlight\", RUN+=\"/run/current-system/profile/bin/chgrp video /sys/class/backlight/%k/brightness\"
ACTION==\"add\", SUBSYSTEM==\"backlight\", RUN+=\"/run/current-system/profile/bin/chmod g+w /sys/class/backlight/%k/brightness\"
ACTION==\"add\", SUBSYSTEM==\"leds\", KERNEL==\"*::kbd_backlight\", RUN+=\"/run/current-system/profile/bin/chgrp input /sys/class/leds/%k/brightness\"
ACTION==\"add\", SUBSYSTEM==\"leds\", KERNEL==\"*::kbd_backlight\", RUN+=\"/run/current-system/profile/bin/chmod g+w /sys/class/leds/%k/brightness\""))

;; dwl session launcher: sources the per-machine autostart hook, then execs
;; the real compositor with the status script piped to dwl's stdin (which
;; dwl reads as its statusline).  Mirrors the old dwm session wrapper.
;; Monitor layouts, wallpapers and session daemons belong in
;; ~/.config/suckless/autostart.sh, NOT here.
(define %dwl-status-script
  (local-file "../dwl/dwl-status.sh"))

(define %dwl-session-script
  (program-file "dwl-session"
                #~(begin
                    (use-modules (ice-9 popen) (ice-9 rdelim)
                                 (ice-9 string-fun))
                    (let ((autostart
                           (string-append (getenv "HOME")
                                          "/.config/suckless/autostart.sh")))
                      ;; The hook is a POSIX shell script; run it through a
                      ;; shell (primitive-load would misread it as Scheme).
                      (when (file-exists? autostart)
                        (system autostart)))
                    ;; Replace this process with /bin/sh running the status
                    ;; pipeline, feeding dwl's stdin.  execl is core Guile.
                    (execl "/bin/sh" "/bin/sh" "-c"
                           "dwl-status | dwl"))))

;; Session launcher for the greetd display manager.  greetd (X11-free, TTY
;; based) runs `tuigreet' as the greeter, which in turn starts this session
;; via `--cmd dwl-session'.  We install the session executable and the
;; dwl-status helper together in one profile package so both are on PATH
;; the instant the greeter hands off.
(define dwl-session
  (package
    (name "dwl-session")
    (version "1.0")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list #:modules '((guix build utils))
           #:builder
           #~(begin
               (use-modules (guix build utils))
               (define out #$output)
               (mkdir-p (string-append out "/bin"))
               (copy-file #$(%dwl-session-script)
                          (string-append out "/bin/dwl-session"))
               (copy-file #$(%dwl-status-script)
                          (string-append out "/bin/dwl-status"))
               (chmod (string-append out "/bin/dwl-session") #o755)
               (chmod (string-append out "/bin/dwl-status") #o755))))
    (synopsis "dwl session launcher for greetd")
    (description
     "Provides the dwl-session executable (which sources autostart and
pipes dwl-status into dwl) and the dwl-status helper on PATH.  greetd's
tuigreet greeter launches this as the user's Wayland session." )
    (home-page "https://suckless.org/")
    (license license:expat)))

;; System-wide packages shared by every host.  User-level extras and
;; editors live in guix/home.scm (see there for the split philosophy).
(define %suckless-system-packages
  (list
   ;; suckless tools, built from the vendored sources (suckless/packages.scm)
   suckless-dwl suckless-utils
   dwl-session               ; greetd session runner (+ dwl-status on PATH)

   ;; Wayland session stack (wmenu/wlroots ecosystem)
   foot                      ; terminal (dwl termcmd)
   wmenu                     ; dmenu backend for the suckless dmenu-* utils
   wl-clipboard              ; wl-copy/wl-paste (dmenu-clip, dmenu-clipd)
   grim slurp                ; Print-key screenshots
   swaylock                  ; lock screen (dmenu-session)
   swaybg                    ; wallpaper (autostart hook)
   swayidle                  ; idle -> lock (autostart hook)
   wlr-randr                 ; monitor layout (autostart hook)
   xwayland                  ; X11 app fallback under Wayland

   ;; session daemons & helpers referenced by the launcher / keybinds
   dunst                     ; notifications (battery/brightness alerts)
   libnotify                 ; provides notify-send (used by the Print keybind)
   lxsession                 ; provides lxpolkit, the polkit agent
   brightnessctl             ; brightness engine used by brightness-notify
   pulseaudio                ; provides pactl for volume media keys
   linux-tools               ; provides cpupower (dmenu-cpupower backend)

   ;; input method — fcitx5 is launched by the session launcher (dwl-start /
   ;; the autostart hook) and the IM env vars are seeded in guix/home.scm.
   fcitx5
   fcitx5-configtool         ; GUI tool to manage the input method

   ;; applications bound in dwl/config.h
   thunar
   librewolf               ; secondary browser (privacy-focused Firefox fork)

   ;; NOTE: Brave is the PRIMARY browser — it is NOT packaged in Guix, so it
   ;; is installed via Flatpak (guix/system.scm cannot provide it).  dwl's
   ;; BROWSER_CMD already launches it: `flatpak run com.brave.Browser`.
   ;; LibreWolf (above) is the packaged secondary/fallback browser.

   ;; thunar integrations (exo finds foot via its .desktop entry)
   exo
   thunar-archive-plugin
   xarchiver
   p7zip
   zip
   unzip

   ;; bluetooth stack
   blueman

   ;; standard editor
   helix

   ;; fonts: Iosevka (mono) + Nerd Font (JetBrainsMono gives the Nerd glyphs
   ;; used by foot.ini, dunst and dwl-status.sh) + Noto CJK/emoji + icons.
   font-iosevka
   font-nerd-jetbrains-mono
   font-awesome
   font-google-noto-sans-cjk
   font-google-noto-emoji

   ;; build + tooling
   git
   make
   gcc-toolchain
   pkg-config

   ;; HTTPS certificates
   nss-certs))

;; Shared system services grafted onto every host.
(define (suckless-services)
  (list
   ;; greetd display manager — TTY-based, no X server.  SLiM was dropped
   ;; because it is an X11 display manager and cannot launch the dwl
   ;; (Wayland) session.  greetd runs the `tuigreet' console greeter on a
   ;; virtual terminal, which starts the dwl session via `--cmd dwl-session'.
   (service greetd-service-type
            (greetd-configuration
             (allow-empty-passwords? #f)    ; hardened login
             (greeter-supplementary-groups '("video" "input"))
             (terminals
              (list
               (greetd-terminal-configuration
                (terminal-vt "1")
                (terminal-switch #t)
                (extra-shepherd-requirement '(elogind))
                (default-session-command
                  (greetd-user-session
                   (command (file-append tuigreet "/bin/tuigreet"))
                   (command-args '("--time" "--cmd" "dwl-session"))
                   (xdg-session-type "tty"))))))))
   ;; NetworkManager
   (service network-manager-service-type
            (network-manager-configuration (dns "dnsmasq")))

   ;; Bluetooth
   (service bluetooth-service-type
            (bluetooth-configuration (auto-enable? #t)))

   ;; Seat manager / power management
   (service elogind-service-type)

   ;; D-Bus (root)
   (service dbus-root-service-type)

   ;; Backlight udev rules for the video/input groups
   (service udev-service-type
            (udev-configuration (rules (list %backlight-udev-rules))))

   ;; Firmware update tooling (fwupdmgr) on laptop
   (service fwupd-service-type)))

;; --------------------------------------------------------------------
;; Composable operating-system builder.
;; --------------------------------------------------------------------
(define* (suckless-system
          #:key
          (host-name "suckless-guix")
          (timezone "America/Sao_Paulo")
          (locale "en_US.utf8")
          (user "you")
          (user-comment "User")
          (kernel linux-libre)
          (kernel-arguments '())
          (initrd default-initrd)
          (firmware '())
          (file-systems %base-file-systems)
          (swap-devices '())
          (bootloader grub-bootloader)
          (bootloader-targets '("/dev/sda"))
          (extra-packages '())
          (extra-services '()))
  (operating-system
    (host-name host-name)
    (timezone timezone)
    (locale locale)

    (kernel kernel)
    (kernel-arguments kernel-arguments)
    (initrd initrd)
    (firmware firmware)

    ;; Keyboard — Brazilian ABNT2
    (keyboard-layout
     (keyboard-layout "br" #:options '("abnt2")))

    ;; Bootloader
    (bootloader
     (bootloader-configuration
      (bootloader bootloader)
      (targets bootloader-targets)
      (keyboard-layout keyboard-layout)))

    ;; File systems
    (file-systems file-systems)

    ;; Swap
    (swap-devices swap-devices)

    ;; Users
    (users
     (cons* (user-account
             (name user)
             (comment user-comment)
             (group "users")
             (home-directory (string-append "/home/" user))
             (supplementary-groups
              '("wheel"      ; sudo access
                "video"      ; backlight control
                "input"      ; keyboard backlight
                "audio"      ; audio devices
                "netdev"     ; network devices
                "realtime"))); real-time scheduling
            %base-user-accounts))

    ;; System-wide packages
    (packages (append %suckless-system-packages extra-packages %base-packages))

    ;; Services
    (services
     (append (suckless-services)
             extra-services
             (modify-services %base-services)))))
