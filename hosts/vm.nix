# Throwaway VM configuration for TESTING the environment.
#
# This is a SEPARATE host -- production configurations (hosts/laptop.nix,
# hosts/minimal.nix, nix/module.nix) are not modified by anything here,
# and nothing in the VM leaks back into them.
#
# Build & run (any machine with Nix + flakes):
#
#   nix build .#vm
#   ./result/bin/run-nixos-vm
#
# Log in as `you` with password `test`, then run: startx
#
# NOTE for VM runs only:
#   * no battery/backlight hardware -> slstatus battery segment shows
#     errors and battery-notify exits; expected, ignore it
#   * graphics are emulated (virtio-gpu): VA-API/real-monitor behavior
#     can only be validated on bare metal

{
  config,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    ../nix/module.nix
    # The NixOS VM builder: provides virtualisation.* options, virtio
    # guest drivers, serial/graphical consoles and system.build.vm.
    (modulesPath + "/virtualisation/qemu-vm.nix")
  ];

  networking.hostName = "suckless-vm";

  # ------------------------------------------------------------------
  # Virtual hardware definition (stand-in for hardware-configuration.nix)
  # ------------------------------------------------------------------
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoFormat = true;
    autoResize = true;
  };
  boot.growPartition = true;
  boot.loader.grub.device = "/dev/vda";

  virtualisation = {
    memorySize = 3072; # MiB
    diskSize = 10240; # MB -- root fs only; /nix/store is shared from host
    graphics = true; # open a QEMU window (false = serial-only headless)
  };

  # ------------------------------------------------------------------
  # The desktop under test
  # ------------------------------------------------------------------
  programs.suckless-environment.enable = true;

  users.users.you = {
    isNormalUser = true;
    description = "you";
    initialPassword = "test"; # throwaway credentials, VM only
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
  };

  system.stateVersion = "25.05";
}
