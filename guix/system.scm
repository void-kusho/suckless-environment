;;; Suckless Environment — Guix System Configuration
;;; =================================================
;;; Declarative, reproducible system configuration for the suckless
;;; Wayland desktop (dwl + foot + wmenu + utils) on GNU Guix.
;;;
;;; This file is a thin wrapper for backward compatibility.  The shared
;;; desktop logic now lives in `guix/services.scm` (procedure
;;; `suckless-system', services, packages) and the hosts live in
;;; `guix/hosts/laptop.scm` (real hardware) and `guix/hosts/vm.scm`
;;; (VirtualBox/QEMU test VM).
;;;
;;; Canonical entry points:
;;;   sudo guix system reconfigure guix/hosts/laptop.scm  # real laptop
;;;   guix system vm guix/hosts/vm.scm                    # ephemeral QEMU VM
;;;   sudo guix system reconfigure guix/system.scm        # shim -> laptop (compat)
;;;
;;; See `guix/hosts/*.scm` for host-specific file systems, bootloader,
;;; kernel and firmware.  See `guix/services.scm` for the composable
;;; `suckless-system' builder.

(eval-when (expand load eval)
  (let ((f (current-filename)))
    (when f
      (add-to-load-path (dirname (dirname f)))
      (add-to-load-path (string-append (dirname f) "/.."))))
  (add-to-load-path ".")
  (add-to-load-path "guix"))

(use-modules (guix hosts laptop))

%suckless-laptop
