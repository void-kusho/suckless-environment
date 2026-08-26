;;; Suckless Environment — Guix System Configuration
;;; =================================================
;;; This is a declarative, reproducible system configuration for
;;; running the suckless desktop environment on Guix.
;;;
;;; Usage:
;;;   sudo guix system reconfigure guix/system.scm
;;;
;;; What this configures:
;;;   - Brazilian ABNT2 keyboard layout
;;;   - Backlight udev rules for brightnessctl
;;;   - Display manager (sddm)
;;;   - NetworkManager
;;;   - Bluetooth
;;;   - Polkit agent
;;;   - Xorg with essential packages

(use-modules (gnu)
             (gnu system)
             (gnu system nss)
             (gnu packages)
             (gnu packages xorg)
             (gnu packages linux)
             (gnu packages freedesktop)
             (gnu packages fonts)
             (gnu packages wm)
             (gnu packages display-managers)
             (gnu packages networking)
             (gnu packages bluetooth)
             (gnu packages package-management)
             (gnu packages emacs)
             (gnu services)
             (gnu services xorg)
             (gnu services networking)
             (gnu services bluetooth)
             (gnu services shepherd)
             (gnu services dbus)
             (gnu services linux)
             (guix gexp)
             (guix packages)
             (guix channels)
             (nongnu packages linux)
             (nongnu system linux-initrd))

(operating-system
  ;; Kernel — use linux-libre by default, or uncomment for non-free:
  ;; (kernel linux)
  ;; (initrd microcode-initrd)
  ;; (firmware (list linux-firmware))

  (host-name "suckless-guix")
  (timezone "America/Sao_Paulo")
  (locale "en_US.utf8")

  ;; Keyboard — Brazilian ABNT2
  (keyboard-layout
   (keyboard-layout "br"
                    #:options '("abnt2")))

  ;; Bootloader
  (bootloader
   (bootloader-configuration
    (bootloader grub-bootloader)
    (targets '("/dev/sda"))
    (keyboard-layout keyboard-layout)))

  ;; File systems — UPDATE THESE UUIDs for your system
  ;; Use `blkid` to find your partition UUIDs
  (file-systems
   (append
    (list
     (file-system
       (mount-point "/")
       (device (uuid "ROOT_UUID" 'ext4))
       (type "ext4"))
     (file-system
       (mount-point "/boot/efi")
       (device (uuid "EFI_UUID" 'fat32))
       (type "vfat")))
    %base-file-systems))

  ;; Swap — optional, adjust as needed
  ;; (swap-devices
  ;;  (list (swap-space
  ;;         (target (uuid "SWAP_UUID")))))

  ;; Users
  (users
   (cons* (user-account
           (name "user")
           (comment "User")
           (group "users")
           (home-directory "/home/user")
           (supplementary-groups
            '("wheel"    ; sudo access
              "video"    ; backlight control
              "input"    ; keyboard backlight
              "audio"    ; audio devices
              "netdev"   ; network devices
              "lp"       ; printing
              "realtime"))); real-time scheduling
          %base-user-accounts))

  ;; System-wide packages
  (packages
   (append
    (list
     ;; Xorg and display
     xorg-server
     xinit
     xterm

     ;; Window manager (built from source, but keep upstream as fallback)
     ;; dwm is installed separately via install.sh

     ;; Fonts
     font-gnu-freefont
     font-liberation
     font-dejavu

     ;; Essential utils
     git
     make
     gcc-toolchain
     pkg-config
     nss-certs            ; HTTPS certificates

     ;; Network
     network-manager
     network-manager-applet

     ;; Bluetooth
     bluez

     ;; Polkit
     polkit-gnome

      ;; Audio
      pulseaudio

      ;; Display manager
      sddm

      ;; Editor
      emacs)

    %base-packages))

  ;; Services
  (services
   (append
    (list
     ;; Display manager — SDDM with custom theme
     (service sddm-service-type
              (sddm-configuration
               (theme "suckless-tokyonight")
               (xorg-configuration
                (xorg-configuration
                 (keyboard-layout keyboard-layout)))))

     ;; NetworkManager
     (service network-manager-service-type
              (network-manager-configuration
               (dns "dnsmasq")))

     ;; Bluetooth
     (service bluetooth-service-type
              (bluetooth-configuration
               (auto-enable? #t)))

     ;; D-Bus
     (service dbus-root-service-type)

     ;; ELogind (seat management)
     (service elogind-service-type)

     ;; Udev rules for backlight
     (service udev-service-type
              (udev-configuration
               (rules (list brightnessctl))))

     ;; Polkit agent — started as user service via SDDM
     ;; (polkit-gnome is launched by dwm-start)

     ;; Allow privilege escalation for video group
     (service special-files-service-type
              `(("/etc/udev/rules.d/90-backlight.rules"
                 ,(plain-file "90-backlight.rules"
                              "ACTION==\"add\", SUBSYSTEM==\"backlight\", RUN+=\"/run/current-system/profile/bin/chgrp video /sys/class/backlight/%k/brightness\"
ACTION==\"add\", SUBSYSTEM==\"backlight\", RUN+=\"/run/current-system/profile/bin/chmod g+w /sys/class/backlight/%k/brightness\"
ACTION==\"add\", SUBSYSTEM==\"leds\", KERNEL==\"*::kbd_backlight\", RUN+=\"/run/current-system/profile/bin/chgrp input /sys/class/leds/%k/brightness\"
ACTION==\"add\", SUBSYSTEM==\"leds\", KERNEL==\"*::kbd_backlight\", RUN+=\"/run/current-system/profile/bin/chmod g+w /sys/class/leds/%k/brightness\""))))

     ;; SDDM theme — symlink theme directory
     (service special-files-service-type
              `(("/run/current-system/profile/share/sddm/themes/suckless-tokyonight"
                 ,(local-file "./sddm-theme" #:recursive? #t))))

    ;; Keep default services (SSH, NTP, etc.)
    %desktop-services)))
