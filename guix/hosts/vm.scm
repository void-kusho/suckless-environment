;;; Host: VirtualBox test VM — hosts/vm.nix
;;; --------------------------------------------------------------------
;;; Throwaway test config.  No battery/backlight (dwl-status shows errors —
;;; expected), graphics are emulated (virtio).

(eval-when (expand load eval)
  (add-to-load-path (string-append (dirname (current-filename)) "/../..")))

(define-module (guix hosts vm)
  #:use-module (gnu system)
  #:use-module (gnu system file-systems)
  #:use-module (gnu bootloader grub)
  #:use-module (gnu packages linux)
  #:use-module (guix services)
  #:export (%suckless-vm))

(define %suckless-vm
  (suckless-system
   #:host-name "suckless-vm"
   #:user "you"
   #:user-comment "Test user"
   ;; Simplest free kernel for the VM
   #:kernel linux-libre
   #:file-systems
   (append
    (list (file-system
           (mount-point "/")
           (device (file-system-label "guix-root"))
           (type "ext4")))
    %base-file-systems)
   #:swap-devices '()
   #:bootloader grub-bootloader
   #:bootloader-targets '("/dev/vda")))

%suckless-vm
