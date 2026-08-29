;;; The real machine.                                  (= hosts/laptop.nix)
;;;
;;;   * Intel TigerLake i5-1135G7 (8 threads), Iris Xe graphics
;;;   * 16 GiB RAM, NVMe SSD
;;;   * BAT1, intel_backlight; Intel WiFi + Bluetooth
;;;   * eDP-1 1920x1080@60 on the left, DP-1 1920x1080@180 on the right
;;;     (the output LAYOUT is declared in dwl/config.h's monrules)
;;;
;;; This file holds HARDWARE facts only; every desktop decision is in
;;; suckless/desktop.scm.
;;;
;;;   make check-laptop                      # build, change nothing
;;;   make laptop                            # sudo guix system reconfigure
;;;
;;; Never reconfigure this host with a configuration that has not booted in
;;; the VM first.
;;;
;;; Needs the nonguix channel (see channels.scm) for the Intel WiFi firmware.

(use-modules (gnu)
             (suckless desktop)
             (nongnu packages linux)
             (nongnu packages video)
             (nongnu system linux-initrd))

(suckless-system
 #:host-name "artix-btw"
 #:user "void"
 #:user-comment "void"

 ;; Non-free firmware: Intel WiFi/Bluetooth need it, and microcode-initrd
 ;; loads the CPU microcode update.
 #:kernel linux
 #:initrd microcode-initrd
 #:firmware (list linux-firmware)

 ;; UUIDs read from the live machine (`lsblk -f`, 2026-08-29):
 ;;   nvme0n1p1 vfat ESP  D5A8-D954                            -> /boot/efi
 ;;   nvme0n1p2 swap SWAP 4697d7c2-e298-4e46-b97d-197fd4a96039
 ;;   nvme0n1p3 ext4 ROOT 6852d602-61ce-43fb-9c28-91ecf89adccc -> /
 #:file-systems
 (append (list (file-system
                 (mount-point "/")
                 (device (uuid "6852d602-61ce-43fb-9c28-91ecf89adccc" 'ext4))
                 (type "ext4"))
               (file-system
                 (mount-point "/boot/efi")
                 (device (uuid "D5A8-D954" 'fat32))
                 (type "vfat")))
         %base-file-systems)
 #:swap-devices
 (list (swap-space
        (target (uuid "4697d7c2-e298-4e46-b97d-197fd4a96039"))))

 ;; grub-efi's target is the EFI System Partition's MOUNT POINT, never the
 ;; whole disk.
 #:bootloader-targets '("/boot/efi")

 ;; Iris Xe (Gen12) needs the iHD driver.  The main Guix channel only has
 ;; intel-vaapi-driver, which is the old i965 and stops at Gen9 — useless
 ;; here; intel-media-driver lives in nonguix.  Swap in
 ;; intel-media-driver/nonfree if you need the closed codecs too.
 #:extra-packages (list intel-media-driver))
