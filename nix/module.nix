# NixOS module: the whole desktop behind a single toggle.
#
#   programs.suckless-environment.enable = true;
#
# Design notes:
#   * The X session starts with `startx` from a TTY -- no display manager.
#     Log in, type `startx`, dwm comes up.
#   * This module also pulls in everything the tools need at RUNTIME:
#       - fonts for `monospace` and the Japanese tags / status line
#       - PipeWire (+ pulse interface) so pamixer works for slstatus
#       - NetworkManager so nmcli/nmtui are usable out of the box
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.suckless-environment;

  packages = import ./packages.nix { inherit pkgs; };

  # Global xinit(1) fallback script. A bare `startx` runs ~/.xinitrc if it
  # exists, otherwise it runs this file -- which starts dwm.
  xinitrc = pkgs.writeShellScript "suckless-xinitrc" ''
    # Publish session variables (DISPLAY, ...) to systemd --user and dbus
    # so PipeWire/PulseAudio clients like pamixer can connect.
    ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY XAUTHORITY 2>/dev/null || true
    exec ${packages.dwm}/bin/dwm
  '';
in

{
  options.programs.suckless-environment.enable = lib.mkEnableOption "the suckless-environment desktop (dwm + dmenu + st + slstatus, started with startx)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      packages.dwm
      packages.dmenu
      packages.st
      packages.slstatus
      pamixer # called by slstatus for the volume readout
      xorg.xprop # inspect WM_CLASS for dwm rules
      xorg.xrandr # monitor configuration
    ];

    services.xserver = {
      enable = true;
      autorun = false; # X is started manually with `startx`
    };

    environment.etc."X11/xinit/xinitrc".source = xinitrc;

    # config.h asks for `monospace`; Noto CJK covers the Japanese tag
    # glyphs and the status line.
    fonts.packages = with pkgs; [
      jetbrains-mono
      noto-fonts-cjk-sans
    ];
    fonts.fontconfig.defaultFonts.monospace = [
      "JetBrains Mono"
      "Noto Sans Mono CJK JP"
    ];

    # Audio: slstatus reads volume through pamixer (PulseAudio protocol).
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };

    networking.networkmanager.enable = true;
  };
}
