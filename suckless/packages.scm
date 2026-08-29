;;; Suckless Environment — package definitions            (= nix/packages.nix)
;;;
;;; Everything this repository builds from its own sources:
;;;
;;;   suckless-dwl    the dwl compositor, patched (bar + snail + dwindle) and
;;;                   built with dwl/config.h
;;;   suckless-utils  the C utility suite in utils/
;;;   dwl-session     the session launcher and its status feeder
;;;
;;; Packages that merely need to be INSTALLED are named by specification in
;;; suckless/desktop.scm, never redefined here.
;;;
;;; Standalone use:
;;;   guix build -L . -e '(@ (suckless packages) suckless-dwl)'

(define-module (suckless packages)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages)
  #:export (suckless-dwl suckless-utils dwl-session))

;; Referring to packages by NAME rather than by variable survives Guix's most
;; common churn (modules being split and renamed) — and, unlike the previous
;; `try-spec' helper, specification->package RAISES on an unknown name instead
;; of silently dropping it.  A typo must break the build, not the desktop.
(define (pkg name) (specification->package name))

;; --------------------------------------------------------------------
;; dwl — patched, with our config.h
;; --------------------------------------------------------------------
;; Order is load-bearing; see dwl/patches/README.  Verified to apply to a
;; pristine dwl 0.8 tree with zero rejects.
(define %dwl-patches
  (list (local-file "../dwl/patches/bar.patch")
        (local-file "../dwl/patches/snail-0.8.patch")
        (local-file "../dwl/patches/dwindle.patch")))

(define-public suckless-dwl
  (let ((base (pkg "dwl")))
    (package
      (inherit base)
      (name "suckless-dwl")
      (source
       (origin
         (inherit (package-source base))
         ;; Keep whatever patches Guix already carries.
         (patches (append (origin-patches (package-source base))
                          %dwl-patches))))
      ;; The bar patch draws with drwl, which needs fcft (font rasterisation)
      ;; and pixman; it adds both to the Makefile's PKGS.
      (inputs (modify-inputs (package-inputs base)
                (append (pkg "fcft") (pkg "pixman"))))
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:phases phases '%standard-phases)
          #~(modify-phases #$phases
              ;; dwl's Makefile generates config.h from config.def.h unless one
              ;; is already present, so dropping ours in is the whole story.
              (add-after 'unpack 'install-custom-config
                (lambda _
                  (copy-file #$(local-file "../dwl/config.h") "config.h")))))))
      (synopsis "dwl with the suckless-environment configuration")
      (description
       "The dwl Wayland compositor patched with an integrated dwm-style bar and
the snail and dwindle layouts, built with this repository's dwl/config.h:
Tokyo Night colours, kanji tags and the keybindings of the X11 dwm setup."))))

;; --------------------------------------------------------------------
;; The C utilities
;; --------------------------------------------------------------------
;; Plain POSIX C with no library dependencies; the tools they drive (wl-copy,
;; wmenu, swaylock, cpupower, brightnessctl) are found on PATH at runtime.
;; utils/Makefile also installs the dmenu->wmenu shim as $PREFIX/bin/dmenu.
(define-public suckless-utils
  (package
    (name "suckless-utils")
    (version "1.0")
    (source (local-file "../utils" #:recursive? #t))
    (build-system gnu-build-system)
    (arguments
     (list
      #:make-flags #~(list (string-append "PREFIX=" #$output))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (add-before 'build 'generate-config.h
            (lambda _
              ;; These two ship only config.def.h (their config.h is generated
              ;; and gitignored).
              (for-each
               (lambda (dir)
                 (let ((def (string-append dir "/config.def.h"))
                       (cfg (string-append dir "/config.h")))
                   (when (and (file-exists? def) (not (file-exists? cfg)))
                     (copy-file def cfg))))
               '("dmenu-session" "dmenu-cpupower"))
              ;; Guix has no power-profiles-daemon, so dmenu-cpupower must use
              ;; the cpupower backend.
              (substitute* "dmenu-cpupower/config.h"
                (("#define USE_CPUPOWER 0") "#define USE_CPUPOWER 1"))))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests? (invoke "make" "test")))))))
    (synopsis "suckless-environment C utilities")
    (description
     "battery-notify, brightness-notify, dmenu-clip, dmenu-clipd,
dmenu-cpupower and dmenu-session, plus the dmenu->wmenu shim that lets the
X11-era dmenu command line drive a Wayland menu.")
    (home-page "https://suckless.org/")
    (license license:expat)))

;; --------------------------------------------------------------------
;; The session
;; --------------------------------------------------------------------
;; One launcher for BOTH login paths (greetd --cmd dwl-session, and a plain
;; TTY), so they cannot drift apart, plus the status feeder it pipes into dwl.
(define-public dwl-session
  (package
    (name "dwl-session")
    (version "1.0")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let ((bin (string-append #$output "/bin")))
            (mkdir-p bin)
            (for-each
             (lambda (source name)
               (let ((target (string-append bin "/" name)))
                 (copy-file source target)
                 (chmod target #o555)))
             (list #$(local-file "../dwl/dwl-session")
                   #$(local-file "../dwl/dwl-status"))
             '("dwl-session" "dwl-status"))))))
    (synopsis "dwl session launcher and status feeder")
    (description
     "Installs @command{dwl-session}, which sets the Wayland environment, runs
the per-machine autostart hook, starts the session daemons and execs
@code{dwl-status | dwl}; and @command{dwl-status}, which feeds dwl's built-in
bar.")
    (home-page "https://suckless.org/")
    (license license:expat)))
