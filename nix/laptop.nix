# Hardware compatibility for this machine.
#
#   Intel i5-1135G7 (TigerLake-LP), 8 threads
#   Iris Xe Graphics                       [8086:9a49]
#   Intel Wi-Fi 6 AX201                    [8086:a0f0]
#   Intel Bluetooth 9460/9560 Jefferson Peak [8087:0aaa]
#   Intel HD Audio, 500 series             [8086:a0c8]
#   NVMe SSD, BAT1, intel_backlight
#
# HARDWARE ONLY. Nothing here describes an installation: no partitions, no
# filesystems, no swap, no bootloader, no users, no hostname, no
# stateVersion. Those are yours -- they come from the
# hardware-configuration.nix that `nixos-generate-config` writes on the
# installed machine, and from your own configuration next to it. This module
# is imported alongside them:
#
#   imports = [
#     ./hardware-configuration.nix    # generated: disks, initrd modules
#     suckless.nixosModules.laptop    # this file: the Intel bits + desktop
#   ];
#
# Monitor layout and pointer warp are session state, not system
# configuration: they go in ~/.config/suckless/autostart.sh, which the dwm
# launcher sources. For THIS machine:
#
#   xrandr --output eDP-1 --mode 1920x1080 --rate 60 --pos 0x0 \
#          --output DP-1 --primary --mode 1920x1080 --rate 180 --pos 1920x0
#   xdotool mousemove 2880 540
{
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./module.nix ];

  # The desktop itself.
  programs.suckless-environment.enable = true;

  # ------------------------------------------------------------------
  # Firmware -- the one thing this laptop is unusable without
  # ------------------------------------------------------------------
  # The AX201 (iwlwifi), the Jefferson Peak bluetooth adapter (ibt-*) and
  # the Iris Xe GuC/HuC all load their microcode from linux-firmware at
  # runtime. NixOS ships NONE of it unless this is on, and a hand-written
  # hardware block does not turn it on the way a generated one does --
  # nixos-generate-config gets it through installer/scan/not-detected.nix.
  # Without this line: no WiFi, no bluetooth, no GuC.
  hardware.enableRedistributableFirmware = true;

  # CPU microcode. A separate package from linux-firmware, hence a separate
  # switch.
  hardware.cpu.intel.updateMicrocode = true;

  # ------------------------------------------------------------------
  # Intel TigerLake / Iris Xe
  # ------------------------------------------------------------------
  # Kernel modesetting is the right driver for Gen12; the old
  # xf86-video-intel is not.
  services.xserver.videoDrivers = [ "modesetting" ];

  # iHD is the VA-API driver for Gen12: hardware video decode in Brave, mpv
  # and ffmpeg.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver ];
  };

  boot.kernelModules = [ "kvm-intel" ];

  # Intel's thermal daemon -- throttling protection beyond what
  # power-profiles-daemon does.
  services.thermald.enable = true;

  # Weekly TRIM for the NVMe SSD.
  services.fstrim.enable = true;

  # Firmware updates: `fwupdmgr refresh && fwupdmgr update`.
  services.fwupd.enable = true;

  # ------------------------------------------------------------------
  # Flatpak
  # ------------------------------------------------------------------
  # NixOS asserts on services.flatpak without portals. GTK is the backend a
  # dwm session needs: without it Flatpak apps get no file chooser and no
  # screen sharing.
  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "gtk";
  };

  # ------------------------------------------------------------------
  # Login
  # ------------------------------------------------------------------
  # Nothing to do here: nix/module.nix turns Ly on, themes it and makes dwm
  # its default session. Worth knowing on this machine specifically -- Ly is
  # a TUI on the console, so the password is typed on the br-abnt2 console
  # keymap the module sets, not on X's layout.
  #
  # For a TTY login and `startx` instead:
  #
  #   services.displayManager.ly.enable = false;

  # ------------------------------------------------------------------
  # Flakes
  # ------------------------------------------------------------------
  # Not hardware, but this repository is only reachable through a flake:
  # without it `nixos-rebuild switch --flake ...` fails on the installed
  # system with "experimental Nix feature 'nix-command' is disabled".
  # mkDefault, so your own configuration wins if it says otherwise.
  nix.settings.experimental-features = lib.mkDefault [
    "nix-command"
    "flakes"
  ];
}
