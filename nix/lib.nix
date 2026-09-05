# Shared builder for the vendored suckless tools.
#
# Every tool keeps its own Makefile and customized config.h next to its
# sources; this wrapper simply runs that Makefile with sane flags:
#
#   * PREFIX/MANPREFIX point into the Nix store instead of /usr/local.
#   * Hardcoded paths from config.mk (/usr/X11R6, /usr/include/freetype2)
#     are deliberately NOT overridden: the stdenv compiler wrapper adds
#     -isystem and -L flags for every package listed in buildInputs, so
#     plain `buildInputs` is enough to satisfy includes and linking.
{
  stdenv,
  makeWrapper,
  patchelf,
}:

{
  name,
  version,
  src,
  buildInputs ? [ ],
  nativeBuildInputs ? [ ],
  extraMakeFlags ? [ ],
  preInstall ? "",
  postInstall ? "",
}:

stdenv.mkDerivation {
  pname = name;
  inherit version src;

  nativeBuildInputs = [
    makeWrapper
    patchelf
  ]
  ++ nativeBuildInputs;
  inherit buildInputs;

  # `src` is a directory of the working tree, so anything built there by
  # hand -- a `make` run on another distribution, a leftover from a branch
  # switch -- is copied into the store next to the sources. GNU make then
  # finds the target newer than its prerequisites, skips the compile
  # entirely, and `make install` ships that FOREIGN binary: one asking for
  # /lib64/ld-linux-x86-64.so.2, a loader NixOS does not have.
  #
  # This is not hypothetical. It is what this repository did, and the
  # symptom was the whole desktop dying at startx with "Could not start
  # dynamically linked executable" -- dwm, slstatus and battery-notify all
  # of them. Every vendored Makefile has a `clean` that removes exactly the
  # binaries and objects and leaves config.h alone.
  preBuild = "make clean";

  # GNU make gives command-line variables precedence over assignments
  # inside config.mk, so these cleanly replace the hardcoded defaults.
  makeFlags = [
    "PREFIX=${placeholder "out"}"
    "MANPREFIX=${placeholder "out"}/share/man"
  ]
  ++ extraMakeFlags;

  enableParallelBuilding = true;

  inherit preInstall postInstall;

  # ...and the seatbelt for the same bug. If a binary that was not built
  # here ever reaches the store again, fail loudly at build time instead of
  # quietly at someone's login. Shell scripts (dmenu_run, the st wrapper)
  # have no interpreter to print and are skipped.
  postFixup = ''
    foreign=""
    find "$out" -type f -print > interpreter-check-files
    while read -r f; do
      interp=$(patchelf --print-interpreter "$f" 2>/dev/null) || continue
      case "$interp" in
        ${builtins.storeDir}/*) ;;
        *) foreign="$foreign$f -> $interp"$'\n' ;;
      esac
    done < interpreter-check-files
    rm -f interpreter-check-files
    if [ -n "$foreign" ]; then
      echo "ERROR: these were not compiled by this derivation --" >&2
      echo "a prebuilt binary leaked in through src:" >&2
      printf '%s' "$foreign" >&2
      exit 1
    fi
  '';
}
