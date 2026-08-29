;;; Suckless Environment — Guix System Configuration
;;; =================================================
;;; The whole desktop, in one self-contained file:
;;;
;;;   sudo guix system reconfigure guix/system.scm
;;;
;;; Deliberately NOT split into modules.  A split needs `-L .' on every
;;; invocation and broke `reconfigure' the last time it was tried; one file
;;; that just works is worth more than a tidy module tree.
;;;
;;; Packages are named by STRING through specification->package rather than by
;;; variable.  Guix renames and moves modules constantly (`make' is the
;;; variable `gnu-make', `pkg-config' is `%pkg-config', `wm' became
;;; `window-management'), and every one of those has already cost this repo a
;;; commit.  Names are stable, and an unknown one RAISES instead of silently
;;; disappearing.

(use-modules (gnu)
             (gnu packages)
             (gnu services)
             (gnu services base)
             (gnu services desktop)
             (gnu services xorg)
             (gnu system)
             (guix packages)
             (guix gexp)
             (guix build-system gnu)
             (guix build-system trivial)
             (guix git-download)                ; git-predicate
             ((guix licenses) #:prefix license:)
             (nongnu packages linux)
             (nongnu system linux-initrd))

(define (pkg name) (specification->package name))

;; Only git-TRACKED files go into the store.  Without this, a `make' left in
;; the working tree would copy dwm/dwm, the *.o files and the generated
;; utils/dmenu-*/config.h into the source derivation: the build would then
;; depend on whatever was last compiled by hand, which is the opposite of what
;; Guix is for.  .gitignore already lists exactly those artefacts, so git is
;; the right authority.  Falls back to "everything" outside a git checkout.
(define %source-only
  ;; current-filename is #f in a few evaluation contexts, and git-predicate
  ;; returns #f outside a checkout; either way, fall back to copying
  ;; everything rather than failing to evaluate.
  (let* ((here (current-filename))
         (root (and here (dirname (dirname here))))
         (pred (and root (git-predicate root))))
    (or pred (const #t))))

;; --------------------------------------------------------------------
;; The suckless tools, built from the vendored sources in this repository.
;; --------------------------------------------------------------------
;; Each tool keeps its own Makefile and the customised config.h next to it;
;; we only redirect PREFIX into the store.  The hardcoded /usr/X11R6 fallbacks
;; in their config.mk are harmless: the real headers arrive through CPATH from
;; the inputs below.

(define* (suckless-tool name version dir #:key inputs native-inputs
                        (tests? #f) (phases #~%standard-phases))
  (package
    (name name)
    (version version)
    (source (local-file dir #:recursive? #t #:select? %source-only))
    (build-system gnu-build-system)
    (inputs (map pkg inputs))
    (native-inputs (map pkg native-inputs))
    (arguments
     (list #:tests? tests?
           #:make-flags
           #~(list (string-append "PREFIX=" #$output)
                   (string-append "MANPREFIX=" #$output "/share/man")
                   "CC=gcc")
           #:phases phases))
    (synopsis (string-append name " — suckless-environment build"))
    (description
     "Built from this repository's vendored sources, with the patches and the
customised config.h that define the suckless-environment desktop.")
    (home-page "https://suckless.org/")
    (license license:expat)))

(define %x11-inputs '("libx11" "libxinerama" "libxft" "fontconfig" "freetype"))

(define suckless-dwm
  (suckless-tool "suckless-dwm" "6.8" "../dwm"
                 #:inputs %x11-inputs
                 #:native-inputs '("pkg-config")
                 #:phases #~(modify-phases %standard-phases (delete 'configure))))

(define suckless-dmenu
  (suckless-tool "suckless-dmenu" "5.4" "../dmenu"
                 #:inputs %x11-inputs
                 #:native-inputs '("pkg-config")
                 #:phases #~(modify-phases %standard-phases (delete 'configure))))

(define suckless-slstatus
  (suckless-tool "suckless-slstatus" "1.1" "../slstatus"
                 #:inputs '("libx11")
                 #:native-inputs '("pkg-config")
                 #:phases #~(modify-phases %standard-phases (delete 'configure))))

;; st carries the kitty-graphics (imlib2, Xrender) and ligatures (harfbuzz)
;; patches, and its `install' target runs `tic', which must write into the
;; store instead of $HOME.  st sets TERM=st-256color, so the binary is wrapped
;; to find its own terminfo at runtime.
(define suckless-st
  (suckless-tool "suckless-st" "0.9.3" "../st"
                 #:inputs (append %x11-inputs
                                  '("libxrender" "imlib2" "harfbuzz" "zlib"
                                    "bash-minimal"))
                 #:native-inputs '("pkg-config" "ncurses")
                 #:phases
                 #~(modify-phases %standard-phases
                     (delete 'configure)
                     (add-before 'install 'terminfo-into-output
                       (lambda _
                         (let ((ti (string-append #$output "/share/terminfo")))
                           (mkdir-p ti)
                           (setenv "TERMINFO" ti))))
                     (add-after 'install 'wrap-terminfo
                       (lambda _
                         (wrap-program (string-append #$output "/bin/st")
                           `("TERMINFO" =
                             (,(string-append #$output "/share/terminfo")))))))))

;; battery-notify, brightness-notify, dmenu-clip, dmenu-clipd, dmenu-cpupower
;; and dmenu-session.  dmenu-session locks with slock (see its config.def.h);
;; dmenu-cpupower needs the cpupower backend because Guix has no
;; power-profiles-daemon.
(define suckless-utils
  (suckless-tool "suckless-utils" "1.0" "../utils"
                 #:inputs '("libx11" "libxfixes")
                 #:tests? #t              ; `make test' — 11 cases
                 #:phases
                 #~(modify-phases %standard-phases
                     (delete 'configure)
                     (add-before 'build 'generate-config.h
                       (lambda _
                         (for-each
                          (lambda (d)
                            (let ((def (string-append d "/config.def.h"))
                                  (cfg (string-append d "/config.h")))
                              (when (and (file-exists? def)
                                         (not (file-exists? cfg)))
                                (copy-file def cfg))))
                          '("dmenu-session" "dmenu-cpupower"))
                         (substitute* "dmenu-cpupower/config.h"
                           (("#define USE_CPUPOWER 0")
                            "#define USE_CPUPOWER 1"))))
                     (replace 'check
                       (lambda* (#:key tests? #:allow-other-keys)
                         ;; Only test-util.  `make test' also runs test-dmenu,
                         ;; which calls dmenu_open() -- it spawns a real dmenu
                         ;; and BLOCKS waiting for a selection, so it hangs the
                         ;; build forever rather than failing.  test-util is
                         ;; pure and covers the shared helpers.
                         (when tests?
                           (invoke "make" "test-util")
                           (invoke "./test-util")))))))

;; The session launcher, plus the .desktop file SLiM reads to offer "dwm" on
;; the login screen (display managers discover sessions from
;; share/xsessions, and nothing in this repository provided one).
(define suckless-session
  (package
    (name "suckless-session")
    (version "1.0")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let ((bin (string-append #$output "/bin"))
                (xs  (string-append #$output "/share/xsessions")))
            (mkdir-p bin)
            (mkdir-p xs)
            (copy-file #$(local-file "../dwm-start") (string-append bin "/dwm-start"))
            (chmod (string-append bin "/dwm-start") #o555)
            (call-with-output-file (string-append xs "/dwm.desktop")
              (lambda (port)
                (format port "[Desktop Entry]~@
                              Type=XSession~@
                              Name=dwm~@
                              Comment=Dynamic window manager (suckless-environment)~@
                              Exec=~a/bin/dwm-start~%" #$output)))))))
    (synopsis "dwm session launcher and its xsession entry")
    (description
     "Installs @command{dwm-start} and the @file{dwm.desktop} XSession entry
that SLiM lists on the login screen.")
    (home-page "https://suckless.org/")
    (license license:expat)))

;; --------------------------------------------------------------------
;; System
;; --------------------------------------------------------------------

;; sysfs attributes have no /dev node, so udev GROUP=/MODE= do not apply and
;; we chgrp/chmod from RUN+= instead.  This EXTENDS the udev service that
;; %desktop-services already provides; instantiating a second one, or setting
;; (rules ...) wholesale, would throw away every default rule.
(define %backlight-udev-rules
  (udev-rule
   "90-backlight.rules"
   #~(string-append
      "ACTION==\"add\", SUBSYSTEM==\"backlight\", RUN+=\""
      #$(file-append (pkg "coreutils") "/bin/chgrp")
      " video /sys/class/backlight/%k/brightness\"\n"
      "ACTION==\"add\", SUBSYSTEM==\"backlight\", RUN+=\""
      #$(file-append (pkg "coreutils") "/bin/chmod")
      " g+w /sys/class/backlight/%k/brightness\"\n"
      "ACTION==\"add\", SUBSYSTEM==\"leds\", KERNEL==\"*::kbd_backlight\", RUN+=\""
      #$(file-append (pkg "coreutils") "/bin/chgrp")
      " input /sys/class/leds/%k/brightness\"\n"
      "ACTION==\"add\", SUBSYSTEM==\"leds\", KERNEL==\"*::kbd_backlight\", RUN+=\""
      #$(file-append (pkg "coreutils") "/bin/chmod")
      " g+w /sys/class/leds/%k/brightness\"\n")))

;; Without this, `guix system reconfigure' COMPILES the kernel and
;; linux-firmware from source — hours instead of minutes.
(define %nonguix-substitutes
  (simple-service
   'nonguix-substitutes guix-service-type
   (guix-extension
    (substitute-urls
     (append (list "https://substitutes.nonguix.org")
             %default-substitute-urls))
    (authorized-keys
     (append (list (plain-file "nonguix.pub"
                               "(public-key (ecc (curve Ed25519) (q #C1FD53E5D4CE971933EC50C9F307AE2171A2D3B52C804642A7A35F84F3A4EA98#)))"))
             %default-authorized-guix-keys)))))

(operating-system
  (host-name "artix-btw")
  (timezone "America/Sao_Paulo")
  ;; The reference machine runs C.UTF-8; en_US.utf8 is the well-trodden Guix
  ;; locale and gives the same English messages.  Change if you want pt_BR.
  (locale "en_US.utf8")

  ;; Non-free firmware: the Intel WiFi/Bluetooth will not come up without it,
  ;; and microcode-initrd loads the CPU microcode update.
  (kernel linux)
  (initrd microcode-initrd)
  (firmware (list linux-firmware))

  ;; `abnt2' is an xkb MODEL, not a variant and not an option — it is listed
  ;; under `! model' in xkb/rules/base.lst, and `br' has no abnt2 variant.
  (keyboard-layout (keyboard-layout "br" #:model "abnt2"))

  ;; The machine boots EFI from nvme0n1p1.  grub-bootloader on /dev/sda would
  ;; be wrong twice over: it is a BIOS install, and sda is the external disk.
  (bootloader
   (bootloader-configuration
    (bootloader grub-efi-bootloader)
    (targets '("/boot/efi"))
    (keyboard-layout (keyboard-layout "br" #:model "abnt2"))))

  ;; UUIDs read from the machine (`lsblk -f`, 2026-08-29).
  (file-systems
   (append
    (list (file-system
            (mount-point "/")
            (device (uuid "6852d602-61ce-43fb-9c28-91ecf89adccc" 'ext4))
            (type "ext4"))
          (file-system
            (mount-point "/boot/efi")
            (device (uuid "D5A8-D954" 'fat32))
            (type "vfat")))
    %base-file-systems))

  (swap-devices
   (list (swap-space
          (target (uuid "4697d7c2-e298-4e46-b97d-197fd4a96039")))))

  (users
   (cons* (user-account
           (name "void")
           (comment "void")
           (group "users")
           (home-directory "/home/void")
           ;; No "realtime": it is not one of Guix's %base-groups, and naming
           ;; a group that does not exist fails activation.
           (supplementary-groups
            '("wheel"      ; sudo
              "video"      ; backlight, DRM
              "input"      ; keyboard backlight, libinput
              "audio"
              "netdev"
              "lp"         ; printing
              "dialout"))) ; serial — the Arduino toolchain (Artix: `uucp')
          %base-user-accounts))

  (packages
   (append
    (list suckless-dwm suckless-st suckless-dmenu suckless-slstatus
          suckless-utils suckless-session)
    (map pkg
         '(;; session daemons and helpers started by dwm-start
           "dunst"                ; notification daemon
           "libnotify"            ; notify-send — battery-notify and
                                  ; brightness-notify call it directly
           "lxsession"            ; lxpolkit, the polkit agent
           "flameshot"            ; Print-key screenshots
           "feh"                  ; wallpaper
           "picom"                ; compositor
           "xdotool"              ; pointer warp onto DP-1
           "xrandr"               ; dual-monitor layout
           "xclip" "xsel"
           "gtk+"                 ; gtk-launch — dmenu_run_desktop pipes into
                                  ; it, so Super+d launches nothing without it
           "slock"                ; dmenu-session's lock (see its config.def.h)
           "brightnessctl"        ; brightness-notify backend
           "pulseaudio"           ; pactl, for the volume keys
           "pamixer"              ; slstatus' volume segment
           "cpupower"             ; dmenu-cpupower backend

           ;; input method
           "fcitx5" "fcitx5-anthy" "fcitx5-gtk" "fcitx5-qt" "fcitx5-configtool"

           ;; Doom Emacs and what `doom doctor' asks for
           "emacs" "git" "ripgrep" "fd" "tmux"
           "cmake" "libtool" "gcc-toolchain" "make" "pkg-config"
           "poppler" "autoconf" "automake"

           ;; applications bound in dwm/config.h
           "thunar" "thunar-volman" "thunar-archive-plugin" "xarchiver"
           "gvfs" "tumbler" "exo"
           "7zip" "zip" "unzip"
           "flatpak"              ; Brave, Discord, Spotify
           "blueman"
           "btop" "neofetch"

           ;; fonts — the machine uses Iosevka Nerd Font; Guix has no
           ;; Nerd-patched Iosevka, so the glyphs come from font-nerd-symbols
           ;; through fontconfig fallback.
           "font-iosevka" "font-nerd-symbols"
           "font-google-noto-sans-cjk" "font-google-noto-emoji"
           "font-gnu-unifont"

           "nss-certs"))
    %base-packages))

  (services
   (append
    (list
     ;; SLiM: a small X11 greeter, and the one this repo has always used.
     ;; It lists the "dwm" session from suckless-session's dwm.desktop.
     (service slim-service-type
              (slim-configuration
               (allow-empty-passwords? #f)
               (xorg-configuration
                (xorg-configuration
                 (keyboard-layout (keyboard-layout "br" #:model "abnt2"))))))

     ;; slock is setuid-root and drops privileges; without this service it
     ;; cannot authenticate and the screen stays locked.
     (service screen-locker-service-type
              (screen-locker-configuration
               (name "slock")
               (program (file-append (pkg "slock") "/bin/slock"))
               (using-pam? #f)
               (using-setuid? #t)))

     (udev-rules-service 'backlight %backlight-udev-rules)

     (service bluetooth-service-type
              (bluetooth-configuration (auto-enable? #t)))

     %nonguix-substitutes)

    ;; %desktop-services already provides elogind, dbus, polkit, udisks,
    ;; upower, NetworkManager and udev.  Declaring them again is a duplicate
    ;; service error — only GDM has to go, since SLiM replaces it.
    (modify-services %desktop-services
      (delete gdm-service-type))))

  (name-service-switch %mdns-host-lookup-nss))
