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

  nativeBuildInputs = [ makeWrapper ] ++ nativeBuildInputs;
  inherit buildInputs;

  # GNU make gives command-line variables precedence over assignments
  # inside config.mk, so these cleanly replace the hardcoded defaults.
  makeFlags = [
    "PREFIX=${placeholder "out"}"
    "MANPREFIX=${placeholder "out"}/share/man"
  ]
  ++ extraMakeFlags;

  enableParallelBuilding = true;

  inherit preInstall postInstall;
}
