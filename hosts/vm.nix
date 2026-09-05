# Throwaway VM configuration for TESTING the environment.
#
# A SEPARATE host: nothing here touches hosts/laptop.nix or nix/module.nix,
# and nothing in the VM leaks back into them.
#
# Build & run (any machine with Nix + flakes):
#
#   nix run .#vm
#
# It boots straight into dwm -- no login, no startx.
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

  # Both the host and the guest are a dwm whose MODKEY is Super. Without an
  # input grab every Super+... goes to the HOST window manager before QEMU
  # sees it, so the guest looks like it has no keybindings at all -- which is
  # exactly how a working VM appears broken. grab-on-hover hands the keyboard
  # over as soon as the pointer is on the window; Ctrl+Alt+G toggles it by
  # hand, and Ctrl+Alt+F releases it.
  virtualisation.qemu.options = [ "-display gtk,grab-on-hover=on,zoom-to-fit=on" ];

  virtualisation = {
    memorySize = 3072; # MiB
    diskSize = 10240; # MB -- root fs only; /nix/store is shared from host
    graphics = true; # open a QEMU window (false = serial-only headless)
  };

  # ------------------------------------------------------------------
  # The desktop under test
  # ------------------------------------------------------------------
  programs.suckless-environment.enable = true;

  # Boot straight into the desktop. This host exists to be looked at, and
  # typing a password into a throwaway VM proves nothing.
  #
  # nix/module.nix turns Ly on by default; switching it off here is what
  # brings back the autologin + startx path, because the module's
  # displayManagerEnabled follows it and hands services.xserver.autorun and
  # the startx pseudo-DM back over.
  services.displayManager.ly.enable = false;
  services.getty.autologinUser = "you";
  programs.bash.loginShellInit = ''
    if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
      exec startx
    fi
  '';

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
