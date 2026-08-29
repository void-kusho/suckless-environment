;;; Host: VirtualBox test VM — hosts/vm.nix
;;; --------------------------------------------------------------------
;;; Throwaway test config.  No battery/backlight (dwl-status shows errors —
;;; expected), graphics are emulated (virtio).

(eval-when (expand load eval)
  (let ((f (current-filename)))
    (when f
      (add-to-load-path (dirname (dirname (dirname f))))
      (add-to-load-path (string-append (dirname f) "/../.."))
      (add-to-load-path (string-append (dirname f) "/.."))))
  (add-to-load-path ".")
  (add-to-load-path "guix")
  (add-to-load-path "guix/hosts"))

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
