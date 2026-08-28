;;; Host: real laptop (Intel TigerLake, NVMe) — hosts/laptop.nix
;;; --------------------------------------------------------------------
;;; Intel i5-1135G7, 16 GiB RAM, NVMe NVMe0n1, intel_backlight,
;;; Intel WiFi/Bluetooth, Iris Xe (modesetting).

(eval-when (expand load eval)
  (add-to-load-path (string-append (dirname (current-filename)) "/../..")))

(define-module (guix hosts laptop)
  #:use-module (gnu system)
  #:use-module (gnu system file-systems)
  #:use-module (gnu bootloader grub)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages video)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu system linux-initrd)
  #:use-module (guix services)
  #:export (%suckless-laptop))

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

%suckless-laptop
