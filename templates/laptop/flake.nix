# /etc/nixos/flake.nix — one machine running the suckless-environment desktop.
#
# Written by `nix flake init -t github:void-kusho/suckless-environment#laptop'.
# Three files, three layers, one rebuild:
#
#   suckless-env.nixosModules.laptop   the desktop and the chipset (the repo)
#   ./configuration.nix                this installation: boot, disk, identity
#   ./home.nix                         this user: their applications
#
# hardware-configuration.nix is the fourth, and it is not in this template:
# `nixos-generate-config' wrote it when you installed, it holds the UUIDs of
# your disks, and nothing here should ever touch it.
#
# EDIT before the first rebuild: the three lines marked `EDIT' in
# configuration.nix. Nothing in this file needs changing to boot.
{
  description = "NixOS running the suckless-environment desktop";

  inputs = {
    # Pin a release, not `nixos-unstable'. The desktop is built against
    # 26.05; an older release is worse than a newer one, because a release
    # that has gone end of life stops getting the renames that a rebuild
    # will otherwise hit all at once.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # The desktop itself, from the `nixos' branch.
    suckless-env = {
      url = "github:void-kusho/suckless-environment/nixos";
      # Not cosmetic: without this you evaluate and download a SECOND
      # nixpkgs, the one pinned inside the environment's own flake.lock.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- HOME-MANAGER (optional) -----------------------------------------
    # Delete this input, the two `home-manager' lines in `outputs' below,
    # the module block at the end of `modules', and ./home.nix, and the
    # system still builds — you just declare user applications in
    # configuration.nix instead.
    #
    # The branch MUST match nixpkgs. home-manager's modules are written
    # against a specific nixpkgs release, and pairing release-25.05 with
    # nixos-26.05 is how options break quietly.
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ---------------------------------------------------------------------
  };

  outputs =
    {
      nixpkgs,
      suckless-env,
      home-manager,
      ...
    }:
    {
      # EDIT: this name is what you rebuild. Keep it in step with
      # networking.hostName in configuration.nix — they are allowed to
      # differ, but there is no reason for them to.
      nixosConfigurations.nixos-btw = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          # Generated on this machine: disks, initrd modules. Do not edit.
          ./hardware-configuration.nix

          # The desktop, plus the Intel TigerLake hardware facts. Use
          # `nixosModules.default' instead on other hardware.
          suckless-env.nixosModules.laptop

          # This installation: boot, hostname, user, stateVersion.
          ./configuration.nix

          # --- HOME-MANAGER (optional) ---------------------------------
          # As a NixOS module rather than a standalone profile, so one
          # `nixos-rebuild switch' applies the system and the home
          # together and there is no second command to forget.
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              # Use the system's pkgs, so nixpkgs.config from
              # configuration.nix applies here too and nixpkgs is not
              # evaluated a second time.
              useGlobalPkgs = true;
              # Into /etc/profiles/per-user/$USER: part of the system
              # closure, so it rolls back with the system.
              useUserPackages = true;
              # EDIT: your username, same as in configuration.nix.
              users.void = import ./home.nix;
              # Rename a colliding file instead of aborting activation.
              backupFileExtension = "backup";
            };
          }
          # --------------------------------------------------------------
        ];
      };
    };
}
