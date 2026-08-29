;;; Suckless Environment — Guix System Configuration
;;; =================================================
;;; Declarative, reproducible system configuration for the suckless
;;; Wayland desktop (dwl + foot + wmenu + utils) on GNU Guix.
;;;
;;; This is the Guix equivalent of the NixOS module (nix/module.nix):
;;; a single composable procedure that builds a full `operating-system`
;;; with the whole desktop, keyboard, services and session behind it.
;;;
;;; Structure mirrors hosts/*.nix from the nixos branch:
;;;   * (suckless-system ...)  — the composable OS builder (nix/module.nix)
;;;   * %suckless-laptop       — real machine entrypoint (hosts/laptop.nix)
;;;   * %suckless-vm           — VirtualBox test host      (hosts/vm.nix)
;;;
;;; Usage (real machine, needs sudo):
;;;   sudo guix system reconfigure guix/system.scm
;;;   # or, to build/try the VM test config:
;;;   guix system vm guix/system.scm        ; QEMU VM (see guix-vm.md)
;;;
;;; Deciding which entrypoint to build: pass a --load-path or edit which
;;; operating-system the file evaluates to at the bottom.

(eval-when (expand load eval)
  (add-to-load-path (dirname (dirname (current-filename)))))

(use-modules (gnu)
             (gnu system)
             (gnu system nss)
             (gnu system shadow)
             (gnu system uuid)
             (gnu system file-systems)
             (gnu system linux-initrd)
             (gnu packages)
             (gnu packages linux)
             (gnu packages freedesktop)
             (gnu packages fonts)
             (gnu packages fontutils)
             (gnu packages base)
             (gnu packages admin)
             (gnu packages bootloaders)
             (gnu packages commencement)
             (gnu packages lxde)
             (gnu bootloader grub)
             (gnu packages certs)
             (gnu packages pkg-config)
             (gnu packages version-control)
             (gnu packages compression)
             (gnu packages image)
             (gnu packages gnome)
             (gnu packages gtk)
             (gnu packages librewolf)
             (gnu packages video)
             (gnu packages xorg)
             (gnu packages xdisorg)
             (gnu packages window-management)
             (gnu packages xfce)
             (gnu packages networking)
             (gnu packages pulseaudio)
             (gnu packages fcitx5)
             (gnu packages web-browsers)
             (gnu packages vim)
             (gnu packages terminals)
             (gnu packages text-editors)
             (gnu services)
             (gnu services base)
             (gnu services xorg)
             (gnu services networking)
             (gnu services dbus)
             (gnu services desktop)
             (gnu services sound)
             (gnu services linux)
             (gnu services shepherd)
             (guix gexp)
             (guix packages)
             (guix channels)
             ((guix licenses) #:prefix license:)
             (guix build-system trivial)
             (suckless packages)
             (nongnu packages linux)
             (nongnu system linux-initrd))

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

;; Helper: make the package list resilient across Guix channel versions.
;; `xwayland` vs `xorg-server-xwayland`, `make` vs `gnu-make`, `linux-tools`
;; vs `cpupower`, nerd-font renames etc. all differ between channels.
;; Using `specification->package` by package *name* (not variable) plus
;; filtering out missing specs means a single rename won't break the whole
;; `guix system reconfigure`. Local packages (suckless-*, dwl-session) stay
;; as variables. No extra imports needed — `catch` is core Guile.
(define (try-spec spec)
  (catch #t
    (lambda () (specification->package spec))
    (lambda _ #f)))

(define (specs->pkgs specs)
  (let loop ((lst specs) (out '()))
    (if (null? lst)
        (reverse out)
        (let ((pkg (try-spec (car lst))))
          (loop (cdr lst) (if pkg (cons pkg out) out))))))

;; System-wide packages shared by every host.  User-level extras and
;; editors live in guix/home.scm (see there for the split philosophy).
(define %suckless-system-packages
  (append
   (list
    ;; suckless tools, built from the vendored sources (suckless/packages.scm)
    suckless-dwl suckless-utils
    dwl-session)               ; greetd session runner (+ dwl-status on PATH)

   (specs->pkgs
    '(
      ;; Wayland session stack (wmenu/wlroots ecosystem)
      "foot"                      ; terminal (dwl termcmd)
      "wmenu"                     ; dmenu backend for the suckless dmenu-* utils
      "wl-clipboard"              ; wl-copy/wl-paste (dmenu-clip, dmenu-clipd)
      "grim" "slurp"                ; Print-key screenshots
      "swaylock"                  ; lock screen (dmenu-session)
      "swaybg"                    ; wallpaper (autostart hook)
      "swayidle"                  ; idle -> lock (autostart hook)
      "wlr-randr"                 ; monitor layout (autostart hook)
      ;; xwayland is `xwayland` on Guix master but `xorg-server-xwayland` on
      ;; older channels; let dwl pull it when needed. Uncomment if you need it:
      ;; "xwayland" "xorg-server-xwayland"

      ;; session daemons & helpers referenced by the launcher / keybinds
      "dunst"                     ; notifications (battery/brightness alerts)
      "libnotify"                 ; provides notify-send (used by the Print keybind)
      "lxsession"                 ; provides lxpolkit, the polkit agent
      "brightnessctl"             ; brightness engine used by brightness-notify
      "pulseaudio"                ; provides pactl for volume media keys
      "cpupower"                  ; CPU power profiles (dmenu-cpupower backend)

      ;; input method — fcitx5 is launched by the session launcher (dwl-start /
      ;; the autostart hook) and the IM env vars are seeded in guix/home.scm.
      "fcitx5"
      "fcitx5-configtool"         ; GUI tool to manage the input method

      ;; applications bound in dwl/config.h
      "thunar"
      "librewolf"               ; secondary browser (privacy-focused Firefox fork)

      ;; NOTE: Brave is the PRIMARY browser — it is NOT packaged in Guix, so it
      ;; is installed via Flatpak (guix/system.scm cannot provide it).  dwl's
      ;; BROWSER_CMD already launches it: `flatpak run com.brave.Browser`.
      ;; LibreWolf (above) is the packaged secondary/fallback browser.

      ;; thunar integrations (exo finds foot via its .desktop entry)
      "exo"
      "thunar-archive-plugin"
      "xarchiver"
      "p7zip"
      "zip"
      "unzip"

      ;; bluetooth stack
      "blueman"

      ;; standard editor
      "helix"

      ;; fonts: Iosevka (mono) + Nerd Font (JetBrainsMono gives the Nerd glyphs
      ;; used by foot.ini, dunst and dwl-status.sh) + Noto CJK/emoji + icons.
      "font-iosevka"
      "font-nerd-jetbrains-mono"
      "font-awesome"
      "font-google-noto-sans-cjk"
      "font-google-noto-emoji"

      ;; build + tooling
      "git"
      "make"
      "gcc-toolchain"
      "pkg-config"

      ;; HTTPS certificates
      "nss-certs"))))

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
           (initrd base-initrd)
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

;; --------------------------------------------------------------------
;; Host: real laptop (Intel TigerLake, NVMe) — hosts/laptop.nix
;; --------------------------------------------------------------------
;; Intel i5-1135G7, 16 GiB RAM, NVMe NVMe0n1, intel_backlight,
;; Intel WiFi/Bluetooth, Iris Xe (modesetting).
(define %suckless-laptop
  (suckless-system
   #:host-name "artix-btw"
   #:user "void"
   #:user-comment "user"
   ;; Intel microcode (non-free firmware)
   #:kernel linux
   #:initrd microcode-initrd
   #:firmware (list linux-firmware)
   #:kernel-arguments '()
   ;; NVMe root at /dev/nvme0n1p3 (adjust UUIDs to your install!)
   #:file-systems
   (append
    (list (file-system
           (mount-point "/")
           (device (uuid "6852d602-61ce-43fb-9c28-91ecf89adccc" 'ext4))
           (type "ext4"))
          (file-system
           (mount-point "/boot/efi")
           (device (uuid "D5A8-D954" 'fat32))
           (type "vfat")))
    %base-file-systems)
   #:swap-devices
   (list (swap-space (target (uuid "4697d7c2-e298-4e46-b97d-197fd4a96039"))))
   ;; grub-efi-bootloader: the target must be the EFI System Partition
   ;; (its mount point here, /boot/efi) — NOT the whole disk.
   #:bootloader grub-efi-bootloader
   #:bootloader-targets '("/boot/efi")
   ;; Hardware acceleration (Iris Xe VA-API) — installed via the profile
   #:extra-packages (list intel-vaapi-driver)))

;; --------------------------------------------------------------------
;; Host: VirtualBox test VM — hosts/vm.nix
;; --------------------------------------------------------------------
;; Throwaway test config.  No battery/backlight (dwl-status shows errors —
;; expected), graphics are emulated (virtio).  Built into a runnable VM:
;;   guix system vm guix/system.scm  (or edit the final value below)
(define %suckless-vm
  (suckless-system
   #:host-name "suckless-vm"
   #:user "you"
   #:user-comment "Test user"
   ;; Simplest free kernel for the VM
   #:kernel linux-libre
   ;; Matched to your guix-btw VM (lsblk -f on 2026-08-28):
   ;;   sda1 vfat A729-FD5E  /boot/efi
   ;;   sda2 swap ac676da8-dbb5-4264-9867-db365f3dd1f7
   ;;   sda3 ext4 f3632921-5496-49a7-922e-55915ae713a  /
   ;; For `guix system vm` this FS is ignored (it builds an image).
   #:file-systems
   (append
    (list (file-system
           (mount-point "/boot/efi")
           (device (uuid "A729-FD5E" 'fat32))
           (type "vfat"))
          (file-system
           (mount-point "/")
           (device (uuid "f3632921-5496-49a7-922e-55915ae713a" 'ext4))
           (type "ext4")))
    %base-file-systems)
   #:swap-devices (list (swap-space (target (uuid "ac676da8-dbb5-4264-9867-db365f3dd1f7"))))
   #:bootloader grub-efi-bootloader
   #:bootloader-targets '("/boot/efi")))

;; --------------------------------------------------------------------
;; Which host to build.  This value is what `guix system reconfigure`
;; (or `guix system vm`) actually builds.
;;
;;   * %suckless-laptop  — real machine; `sudo guix system reconfigure`
;;   * %suckless-vm      — VirtualBox/QEMU test host; switch the line
;;     below to %suckless-vm, then:
;;         guix system vm guix/system.scm    (build a runnable VM)
;;         sudo guix system reconfigure ...  (test in VirtualBox, see guix-vm.md)
;;
;; NOTE: `guix system vm` uses whatever this file evaluates to, so to
;; build the VM you MUST flip `%suckless-laptop` to `%suckless-vm` below.
;; --------------------------------------------------------------------
%suckless-laptop
