;;; Throwaway VM host — the thing you test against.       (= hosts/vm.nix)
;;;
;;; A SEPARATE file from hosts/laptop.scm: testing never edits the real
;;; machine's configuration, and nothing here leaks into it.  There is no
;;; "flip the last line" step any more.
;;;
;;;   make check      # type/service check only, no VM   (guix system build)
;;;   make vm         # boot the desktop in QEMU         (guix system vm)
;;;
;;; Deliberately free of nonguix: this host builds with a stock `guix pull',
;;; so a broken channel cannot block testing.
;;;
;;; Log in as `you' / `test' at the tuigreet prompt on vt1.
;;;
;;; What the VM CANNOT tell you: backlight, WiFi firmware, VA-API, the
;;; dual-monitor layout and the 180 Hz mode. Those need bare metal.

(use-modules (gnu)
             (suckless desktop))

(suckless-system
 #:host-name "suckless-vm"
 #:user "you"
 #:user-comment "Test user"
 ;; Throwaway credentials, VM only.  greetd runs with
 ;; allow-empty-passwords? #f, so the account needs one to be usable.
 #:user-password (crypt "test" "$6$suckless$")

 ;; Matches the existing VirtualBox guest (guix-btw): sda1 ESP, sda2 swap,
 ;; sda3 root.  `guix system vm' substitutes its own root and ignores these.
 #:file-systems
 (append (list (file-system
                 (mount-point "/boot/efi")
                 (device "/dev/sda1")
                 (type "vfat"))
               (file-system
                 (mount-point "/")
                 (device "/dev/sda3")
                 (type "ext4")))
         %base-file-systems)
 #:swap-devices (list (swap-space (target "/dev/sda2"))))
