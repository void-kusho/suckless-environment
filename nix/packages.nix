# All tools of this environment as Nix derivations, built from the
# vendored sources in this repository (each uses its own Makefile and the
# customized config.h sitting next to it).
#
# Standalone usage:
#   nix-build nix/packages.nix -A st        # build one tool
#   nix-build nix/packages.nix -A dwm --no-out-link && ls result/bin

{
  pkgs ? import <nixpkgs> { },
}:

let
  mkSuckless = pkgs.callPackage ./lib.nix { };
in

{
  dwm = mkSuckless {
    name = "dwm";
    version = "6.8";
    src = ../dwm;
    buildInputs = with pkgs; [
      xorg.libX11
      xorg.libXinerama
      xorg.libXft # pulls in Xrender
      fontconfig # included directly by drw.c
      freetype # included directly by drw.c
    ];
  };

  dmenu = mkSuckless {
    name = "dmenu";
    version = "5.4";
    src = ../dmenu;
    buildInputs = with pkgs; [
      xorg.libX11
      xorg.libXinerama
      xorg.libXft
      fontconfig
      freetype
    ];
  };

  st = mkSuckless {
    name = "st";
    version = "0.9.3";
    src = ../st;
    nativeBuildInputs = with pkgs; [
      pkg-config # config.mk queries pkg-config for imlib2/fonts/harfbuzz
      ncurses # provides `tic`, used to compile st.info
    ];
    buildInputs = with pkgs; [
      xorg.libX11
      xorg.libXft
      xorg.libXrender # kitty-graphics patch links -lXrender
      imlib2 # kitty-graphics patch (graphics.c)
      harfbuzz # ligatures patch (hb.c)
      fontconfig
      freetype
    ];
    preInstall = ''
      # The Makefile compiles st.info with `tic` during install. Redirect
      # it into our own output instead of $HOME.
      mkdir -p $out/share/terminfo
      export TERMINFO=$out/share/terminfo
    '';
    postInstall = ''
      # st sets TERM=st-256color, so at runtime it must be able to find
      # its own terminfo entry.
      wrapProgram $out/bin/st --set TERMINFO $out/share/terminfo
    '';
  };

  slstatus = mkSuckless {
    name = "slstatus";
    version = "1.1";
    src = ../slstatus;
    buildInputs = with pkgs; [ xorg.libX11 ];
  };

  # Custom C utilities: battery-notify, brightness-notify, dmenu-session,
  # dmenu-cpupower, dmenu-clip, dmenu-clipd. Built by utils/Makefile.
  utils = mkSuckless {
    name = "suckless-utils";
    version = "1.0";
    src = ../utils;
    buildInputs = with pkgs; [
      xorg.libX11 # dmenu-clipd
      xorg.libXfixes # dmenu-clipd
    ];
  };
}
