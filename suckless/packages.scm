;;; Suckless Environment — Guix package definitions
;;; =================================================
;;; Declarative package definitions for the Wayland (dwl) desktop.
;;;
;;; This module builds the vendored suckless Wayland tools from this
;;; repository using Guix' build systems:
;;;   * suckless-dwl   — the dwl Wayland compositor, built from the
;;;                      upstream Guix `dwl` recipe with our dwl/config.h
;;;                      overlaid (status bar, Tokyo Night, keybindings).
;;;   * suckless-utils — the C utility suite (battery-notify,
;;;                      brightness-notify, dmenu-clip, dmenu-clipd,
;;;                      dmenu-cpupower, dmenu-session) built by
;;;                      utils/Makefile.
;;;
;;; The legacy X11 tools (dwm/dmenu/st/slstatus) are NOT packaged here:
;;; the Guix desktop is Wayland-only (dwl/foot/wmenu).  The utils' menu
;;; backend is the `dmenu` shim (utils/dmenu-shim) that routes to wmenu.
;;;
;;; Loaded like any local Guix module, e.g. from system.scm:
;;;   (use-module (suckless packages))
;;;   ; -> suckless-dwl suckless-utils

(define-module (suckless packages)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages window-management)
  #:export (suckless-dwl suckless-utils))

;; dwl (Wayland compositor, dwm-for-wayland) built with our dwl/config.h.
;; We build on top of the upstream Guix `dwl` recipe (gnu-build-system using
;; dwl's own Makefile, inputs wlroots + wayland + libinput + libxkbcommon...
;; already wired by (gnu packages window-management)) and merely swap in our config.h before
;; compilation — the dwl Makefile picks up a `config.h` placed in the source.
(define-public suckless-dwl
  (package
    (inherit dwl)
    (name "suckless-dwl")
    (arguments
     (substitute-keyword-arguments (package-arguments dwl)
       ((#:phases phases '%standard-phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'install-custom-config
              (lambda _
                ;; Overlay our config.h onto the upstream dwl tree.
                (copy-file #$(local-file "../dwl/config.h") "config.h")))))))
    (synopsis "dwl (suckless Wayland compositor) with suckless config")
    (description
     "A dwl built on the upstream Guix dwl recipe with the vendored
dwl/config.h from this repository: the Wayland compositor with the
suckless-environment keybindings, Tokyo Night colours and integrated
status bar.")))

;; Custom C utilities: battery-notify, brightness-notify, dmenu-session,
;; dmenu-cpupower, dmenu-clip, dmenu-clipd.  Built by utils/Makefile.
;;
;; Guix-specific generation: dmenu-session/dmenu-cpupower only ship
;; config.def.h, so we generate config.h before building — and force the
;; cpupower backend (power-profiles-daemon is not in Guix main repos),
;; while dmenu-session already defaults to swaylock (Wayland).
(define-public suckless-utils
  (let ((utils-src (local-file "../utils" #:recursive? #t)))
    (package
      (name "suckless-utils")
      (version "1.0")
      (source utils-src)
      (build-system gnu-build-system)
      (inputs '())                      ; pure POSIX C; CLIs (wl-copy, wmenu) on PATH
      (native-inputs '())
      (arguments
       (list #:make-flags
             #~(list (string-append "PREFIX=" #$output))
             #:phases
             #~(modify-phases %standard-phases
                 (delete 'configure)
                 (delete 'check)
                 (add-before 'build 'generate-config.h
                   (lambda _
                     (for-each
                      (lambda (dir)
                        (let ((def (string-append dir "/config.def.h")))
                          (when (and (file-exists? def)
                                     (not (file-exists?
                                           (string-append dir "/config.h"))))
                            (copy-file def (string-append dir "/config.h")))))
                      '("dmenu-session" "dmenu-cpupower"))
                     ;; Force the cpupower backend (Guix has no
                     ;; power-profiles-daemon).
                     (substitute* "dmenu-cpupower/config.h"
                       (("#define USE_CPUPOWER 0")
                        "#define USE_CPUPOWER 1"))))
                 (replace 'install
                   (lambda _
                     (invoke "make" "install"
                             (string-append "PREFIX=" #$output)))))))
      (synopsis "suckless-environment C utilities")
      (description "Custom C utilities for the suckless environment:
battery-notify, brightness-notify, dmenu-session, dmenu-cpupower,
dmenu-clip and dmenu-clipd.")
      (home-page "https://suckless.org/")
      (license license:expat))))
