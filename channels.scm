;;; Guix channels.
;;;
;;;   cp channels.scm ~/.config/guix/channels.scm && guix pull
;;;
;;; nonguix supplies the non-free Intel WiFi/Bluetooth firmware and the
;;; `linux' kernel that hosts/laptop.scm needs.  hosts/vm.scm does NOT use it,
;;; so the VM can always be built and tested with a stock Guix.
;;;
;;; REPRODUCIBILITY: this file floats on the channel tips, which is what you
;;; want from `guix pull'.  To make the VM and the laptop build byte-identical
;;; systems, freeze the result afterwards:
;;;
;;;   make lock            # guix describe -f channels > channels-lock.scm
;;;   guix time-machine -C channels-lock.scm -- system build -L . hosts/vm.scm
;;;
;;; Commit channels-lock.scm.  It is the only thing that keeps dwl's version
;;; and dwl/patches/ from drifting apart.

(cons* (channel
        (name 'nonguix)
        (url "https://gitlab.com/nonguix/nonguix")
        (introduction
         (make-channel-introduction
          "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
          (openpgp-fingerprint
           "2A39 3FFF 68F4 EF7A 3D29 12AF 6F51 20A0 22FB B2D5"))))
       %default-channels)
