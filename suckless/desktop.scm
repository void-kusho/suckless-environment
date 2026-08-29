;;; Suckless Environment — the whole desktop, in one place  (= nix/module.nix)
;;;
;;; `suckless-system' is the composable operating-system builder.  Hosts pass
;;; only HARDWARE facts; every desktop decision lives here, so hosts/laptop.scm
;;; and hosts/vm.scm cannot drift apart.
;;;
;;;   (use-modules (suckless desktop))
;;;   (suckless-system #:host-name "..." #:user "..." #:file-systems ...)

(define-module (suckless desktop)
  #:use-module (gnu)
  #:use-module (gnu packages)
  ;; (gnu) re-exports the system/service modules but NOT package variables;
  ;; `linux-libre' is the default #:kernel below and comes from here.
  #:use-module (gnu packages linux)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services desktop)
  #:use-module (gnu services xorg)
  #:use-module (gnu services linux)
  #:use-module (gnu system)
  #:use-module (guix gexp)
  #:use-module (suckless packages)
  #:export (suckless-system %suckless-packages))

;; See the note in (suckless packages): by name, and LOUD on a typo.
(define (pkg name) (specification->package name))

;; --------------------------------------------------------------------
;; Packages
;; --------------------------------------------------------------------
(define %suckless-packages
  (append
   ;; Built from this repository.
   (list suckless-dwl suckless-utils dwl-session)

   (map pkg
        '(;; --- Wayland session stack ---
          "foot"                  ; terminal (dwl termcmd)
          "wmenu"                 ; menu backend behind the dmenu shim
          "wl-clipboard"          ; wl-copy / wl-paste (dmenu-clip, dmenu-clipd)
          "grim" "slurp"          ; Print-key screenshots
          "swaylock"              ; lock screen (dmenu-session, swayidle)
          "swaybg"                ; wallpaper (autostart hook)
          "swayidle"              ; idle -> lock (dwl-session)
          "wlr-randr"             ; ad-hoc output tweaks; the layout is in config.h

          ;; --- session daemons and keybind helpers ---
          "dunst"                 ; notifications (battery / brightness OSD)
          "libnotify"             ; notify-send, used by the Print keybind
          "lxsession"             ; lxpolkit, the polkit authentication agent
          "brightnessctl"         ; engine behind brightness-notify
          "pulseaudio"            ; pactl, for the volume keys and dwl-status
          "cpupower"              ; backend of dmenu-cpupower

          ;; --- input method ---
          ;; The X11 machine used fcitx5-mozc; mozc is NOT packaged in Guix, so
          ;; Japanese input is provided by Anthy.  fcitx5/profile keeps
          ;; keyboard-br as the default IM, exactly as before.
          "fcitx5"
          "fcitx5-anthy"
          "fcitx5-gtk"
          "fcitx5-qt"
          "fcitx5-configtool"

          ;; --- editor: Doom Emacs ---
          ;; emacs-pgtk speaks Wayland natively (no XWayland round trip).  Doom
          ;; itself stays imperative (`doom install' / `doom sync'); everything
          ;; below is a system dependency of Doom or of an ENABLED module, and
          ;; the list was derived from `doom doctor' plus the binaries actually
          ;; present on the reference machine — not from guesswork.
          ;;
          ;; Guix ships emacs-pgtk 30.2; the reference machine runs 31.1, which
          ;; `doom doctor' itself flags as an unsupported development build.
          ;; For something closer to 31, swap in "emacs-next-pgtk".
          "emacs-pgtk"
          "git"                   ; :tools magit
          "ripgrep"               ; :tools lookup, project search
          "fd"                    ; doom doctor asks for it; absent on the
                                  ; reference machine, so this is an upgrade
          "cmake" "libtool" "gcc-toolchain" "make" "pkg-config"
                                  ; :term vterm compiles its module on first use
          "poppler" "autoconf" "automake"
                                  ; :tools pdf — pdf-tools builds epdfinfo
          "tmux"                  ; :tools tmux
          "gnupg"                 ; magit signing, auth-source
          "sqlite"                ; forge / org caches
          "python-wrapper"        ; :lang python
          "rust" "rust-analyzer"  ; :lang rust +lsp.  Guix 1.93 vs 1.96 on the
                                  ; reference machine; its rustup toolchain in
                                  ; ~/.cargo cannot run on Guix (prebuilt
                                  ; binaries need /lib64/ld-linux), so the
                                  ; packaged one replaces it.
          "clang"                 ; :lang cc +lsp — provides clangd (16 vs 22)
          ;; NOT packaged usefully, and deliberately left out:
          ;;   zig   Guix has 0.11.0, the machine runs 0.16.0 — five language
          ;;         breaking releases apart, and zig-zls 0.15 matches neither.
          ;;   node  Guix has 10.24.1, the machine runs 26.7.0.
          ;; Install those from upstream instead; see README.

          ;; --- applications bound in dwl/config.h ---
          "thunar" "thunar-volman" "gvfs"
          "exo"                   ; Thunar's "Open Terminal Here" resolves foot
          "thunar-archive-plugin" "xarchiver" "7zip" "zip" "unzip"
          "librewolf"             ; secondary browser; Brave comes from Flatpak
          "flatpak"
          "blueman"
          "btop" "neofetch"

          ;; --- fonts ---
          ;; The X11 setup used "Iosevka Nerd Font"; Guix ships no Nerd-patched
          ;; Iosevka, so the glyphs come from font-nerd-symbols through the
          ;; fallback chains in dwl/config.h, foot.ini and dunstrc.
          "font-iosevka"
          "font-nerd-symbols"
          "font-google-noto-sans-cjk"   ; the 一二三 tag labels
          "font-google-noto-emoji"
          ;; doom doctor asks for Symbola as Emacs' last-resort font; Guix has
          ;; no Symbola, and Unifont covers the same "render anything" role.
          "font-gnu-unifont"

          ;; --- TLS ---
          "nss-certs"))))

;; --------------------------------------------------------------------
;; Services
;; --------------------------------------------------------------------

;; Backlight access for the `video' group (and the keyboard backlight for
;; `input').  sysfs attributes have no /dev node, so udev GROUP=/MODE= do not
;; apply and we chgrp/chmod from RUN+= instead.
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

;; greetd owns every text console: tuigreet on vt1 launches the dwl session,
;; vt2-6 get the default agreety text greeter.  This is why login-service-type
;; and mingetty-service-type are deleted below — two services cannot both
;; provide term-tty1.
(define %greetd-terminals
  (cons (greetd-terminal-configuration
         (terminal-vt "1")
         (terminal-switch #t)
         (default-session-command
           (greetd-user-session
            (command (file-append (pkg "tuigreet") "/bin/tuigreet"))
            (command-args '("--time" "--remember" "--cmd" "dwl-session")))))
        (map (lambda (vt)
               (greetd-terminal-configuration (terminal-vt vt)))
             '("2" "3" "4" "5" "6"))))

(define %suckless-services
  (list
   (service greetd-service-type
            (greetd-configuration
             (allow-empty-passwords? #f)
             (greeter-supplementary-groups '("video" "input"))
             (terminals %greetd-terminals)))

   ;; swaylock authenticates through PAM; without this service it cannot
   ;; verify the password and the screen stays locked for good.
   (service screen-locker-service-type
            (screen-locker-configuration
             (name "swaylock")
             (program (file-append (pkg "swaylock") "/bin/swaylock"))
             (using-pam? #t)
             (using-setuid? #f)))

   ;; Extends the udev service that %base-services already provides — a second
   ;; (service udev-service-type ...) would be a duplicate.
   (udev-rules-service 'backlight %backlight-udev-rules)

   (service bluetooth-service-type
            (bluetooth-configuration (auto-enable? #t)))))

;; --------------------------------------------------------------------
;; The operating-system builder
;; --------------------------------------------------------------------
(define* (suckless-system
          #:key
          host-name
          (user "void")
          (user-comment "user")
          ;; #f means "no password set" — the account cannot log in until
          ;; passwd(1) is run.  Throwaway hosts pass a crypted string.
          (user-password #f)
          (timezone "America/Sao_Paulo")
          (locale "pt_BR.utf8")
          (kernel linux-libre)
          (kernel-arguments '())
          (initrd base-initrd)
          (firmware '())
          (file-systems %base-file-systems)
          (swap-devices '())
          (bootloader grub-efi-bootloader)
          (bootloader-targets '("/boot/efi"))
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

    ;; Brazilian ABNT2.  `abnt2' is an xkb MODEL, not a variant and not an
    ;; option (see `! model' in xkb/rules/base.lst).  This covers the console
    ;; and GRUB only; dwl gets its own xkb_rules from dwl/config.h.
    (keyboard-layout (keyboard-layout "br" #:model "abnt2"))

    (bootloader
     (bootloader-configuration
      (bootloader bootloader)
      (targets bootloader-targets)
      (keyboard-layout (keyboard-layout "br" #:model "abnt2"))))

    (file-systems file-systems)
    (swap-devices swap-devices)

    (users
     (cons* (user-account
             (name user)
             (comment user-comment)
             (group "users")
             (home-directory (string-append "/home/" user))
             (password user-password)
             ;; No "realtime": it is not one of Guix's %base-groups, and
             ;; referring to a group that does not exist fails activation.
             (supplementary-groups
              '("wheel"      ; sudo
                "video"      ; backlight, DRM
                "input"      ; keyboard backlight, libinput
                "audio"
                "netdev")))
            %base-user-accounts))

    (packages (append %suckless-packages extra-packages %base-packages))

    (services
     (append %suckless-services
             extra-services
             (modify-services %desktop-services
               ;; GDM is an X11 display manager and cannot start a Wayland
               ;; session for us; greetd replaces it.
               (delete gdm-service-type)
               ;; greetd manages every VT, so the stock console logins must go.
               (delete login-service-type)
               (delete mingetty-service-type))))))
