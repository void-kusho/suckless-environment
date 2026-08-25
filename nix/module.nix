# NixOS module: the whole desktop behind a single toggle.
#
#   programs.suckless-environment.enable = true;
#
# Design notes:
#   * Works with ANY login flow:
#       - Display managers (Ly, greetd, sddm, ...): dwm shows up as the
#         default session ("none+dwm").
#       - No display manager: log in on a TTY and run `startx`. NixOS's
#         built-in startx pseudo-DM generates /etc/X11/xinit/xinitrc,
#         which starts systemd user services (PipeWire etc.), runs the
#         same dwm session, and cleans up on exit.
#   * X autostarts at boot only when a display manager is enabled.
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

  # dwm + its status bar as ONE launcher, so both startx and display
  # managers get identical sessions. pkill clears leftovers from a
  # previous logout/restart so bars never duplicate.
  dwm = pkgs.writeShellScriptBin "dwm" ''
    ${pkgs.procps}/bin/pkill -x slstatus 2>/dev/null || true
    ${packages.slstatus}/bin/slstatus &
    exec ${packages.dwm}/bin/dwm
  '';

  # True when an explicitly chosen display manager is enabled. Used to
  # decide whether X should start at boot. NOTE: we deliberately ignore
  # services.*displayManager.lightdm here -- recent nixpkgs turns it on
  # as a fallback whenever X11 is enabled, so it cannot signal intent.
  # Greeters outside this list need `services.xserver.autorun = true;`.
  displayManagerEnabled =
    (config.services.displayManager.ly or { enable = false; }).enable
    || (config.services.displayManager.sddm or { enable = false; }).enable
    || (config.services.displayManager.cosmic-greeter or { enable = false; }).enable
    || (config.services.greetd or { enable = false; }).enable;
in

{
  options.programs.suckless-environment.enable = lib.mkEnableOption "the suckless-environment desktop (dwm + dmenu + st + slstatus)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      dwm
      packages.dmenu
      packages.st
      packages.slstatus
      pamixer # called by slstatus for the volume readout
      xorg.xprop # inspect WM_CLASS for dwm rules
      xorg.xrandr # monitor configuration
    ];

    services.xserver = {
      enable = true;
      # Start X at boot only when a display manager will show a session
      # picker; otherwise the user logs into a TTY and runs `startx`.
      autorun = lib.mkDefault displayManagerEnabled;

      # Register dwm as a selectable session for display managers.
      windowManager.dwm = {
        enable = true;
        package = dwm;
      };

      # Without any display manager, use NixOS's official startx
      # pseudo-DM: it provides the `startx` command (xorg.xinit) and
      # generates a sane system-wide xinitrc.
      displayManager.startx = {
        enable = lib.mkDefault (!displayManagerEnabled);
        generateScript = lib.mkDefault true;
      };
    };
    services.displayManager.defaultSession = lib.mkDefault "none+dwm";

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
