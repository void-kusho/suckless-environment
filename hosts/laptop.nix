# The real machine.
#
#   * Intel TigerLake i5-1135G7 (8 threads), Iris Xe graphics
#   * 16 GiB RAM, NVMe SSD
#   * BAT1, intel_backlight; Intel WiFi + Bluetooth
#   * eDP-1 1920x1080@60 on the left, DP-1 1920x1080@180 on the right
#
# This file holds HARDWARE facts only; every desktop decision comes from
# programs.suckless-environment in nix/module.nix.
#
#   nix build .#nixosConfigurations.laptop.config.system.build.toplevel
#   sudo nixos-rebuild switch --flake .#laptop
#
# It is a complete, evaluable host on purpose: a template that cannot be
# built is a template nobody ever checks. Run `nixos-generate-config` on the
# real install and reconcile the block below with its output before
# switching -- the module list here is the usual Intel/NVMe set, not a
# reading of your hardware.
{
  config,
  pkgs,
  ...
}:

{
  imports = [ ../nix/module.nix ];

  networking.hostName = "artix-btw";

  # ------------------------------------------------------------------
  # Disks — read from the machine (`lsblk -f`, 2026-08-29)
  # ------------------------------------------------------------------
  #   nvme0n1p1 vfat ESP  D5A8-D954                            -> /boot/efi
  #   nvme0n1p2 swap SWAP 4697d7c2-e298-4e46-b97d-197fd4a96039
  #   nvme0n1p3 ext4 ROOT 6852d602-61ce-43fb-9c28-91ecf89adccc -> /
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/6852d602-61ce-43fb-9c28-91ecf89adccc";
    fsType = "ext4";
  };

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/D5A8-D954";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/4697d7c2-e298-4e46-b97d-197fd4a96039"; }
  ];

  # The ESP is shared with the existing Artix GRUB. systemd-boot installs
  # alongside it rather than over it, but it will claim the default entry.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint = "/boot/efi";
  };

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # ------------------------------------------------------------------
  # Intel platform (TigerLake)
  # ------------------------------------------------------------------
  hardware.cpu.intel.updateMicrocode = true;

  # Iris Xe uses the iHD driver (VA-API in browsers, mpv, ffmpeg...).
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver ];
  };

  # Kernel modesetting is the right choice for Iris Xe; do NOT install the
  # old xf86-video-intel.
  services.xserver.videoDrivers = [ "modesetting" ];

  # Intel's thermal daemon: throttling protection beyond power-profiles-daemon.
  services.thermald.enable = true;

  # Weekly TRIM for the NVMe SSD.
  services.fstrim.enable = true;

  # Firmware updates (`fwupdmgr refresh && fwupdmgr update`).
  services.fwupd.enable = true;

  # ------------------------------------------------------------------
  # Flatpak
  # ------------------------------------------------------------------
  # NixOS asserts on services.flatpak without portals, so this host did not
  # evaluate at all before. GTK is the backend a dwm session needs: without
  # it, Flatpak apps get no file chooser and no screen sharing.
  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "gtk";
  };

  # ------------------------------------------------------------------
  # Desktop + user
  # ------------------------------------------------------------------
  programs.suckless-environment.enable = true;

  users.users.void = {
    isNormalUser = true;
    description = "void";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video" # brightness keys (intel_backlight)
      "input" # input devices
      "dialout" # serial — the Arduino toolchain
    ];
  };

  # Boot straight into Ly instead of startx from the TTY:
  # services.displayManager.ly.enable = true;

  # Machine-specific session setup goes in ~/.config/suckless/autostart.sh,
  # which the dwm launcher sources. For THIS machine:
  #
  #   xrandr --output eDP-1 --mode 1920x1080 --rate 60 --pos 0x0 \
  #          --output DP-1 --primary --mode 1920x1080 --rate 180 --pos 1920x0
  #   xdotool mousemove 2880 540
  #   feh --no-fehbg --bg-fill ~/wallpapers/sushi_original.png

  # Set to the NixOS release you FIRST installed; do not bump it.
  system.stateVersion = "25.05";
}
