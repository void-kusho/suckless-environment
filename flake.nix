{
  description = "Personal suckless X11 desktop (dwm, st, dmenu, slstatus) for NixOS";

  # nixos-25.05 went end of life; 26.05 is the current stable.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      forAllSystems =
        f:
        lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
        ] (system: f nixpkgs.legacyPackages.${system});
    in
    {
      nixosModules = {
        # The whole desktop behind one toggle:
        #   imports = [ suckless-env.nixosModules.default ];
        #   programs.suckless-environment.enable = true;
        default = import ./nix/module.nix;

        # The desktop plus the Intel TigerLake hardware this repository was
        # written on. Combine it with the hardware-configuration.nix that
        # nixos-generate-config writes on the installed machine:
        #
        #   imports = [
        #     ./hardware-configuration.nix
        #     suckless-env.nixosModules.laptop
        #   ];
        #
        # Deliberately NOT a nixosConfiguration: this repository describes a
        # desktop and a chipset, never a disk. Partitions, bootloader, users
        # and stateVersion belong to the installation.
        laptop = import ./nix/laptop.nix;
      };

      # The installation, as something you can run rather than transcribe:
      #
      #   cd /etc/nixos && sudo nix flake init -t github:void-kusho/suckless-environment#laptop
      #
      # writes flake.nix, configuration.nix, home.nix and autostart.sh next
      # to the hardware-configuration.nix that is already there. Three lines
      # to edit, then rebuild. README walks through it.
      #
      # The template is the reference machine minus its disks: everything
      # this repository refuses to carry -- bootloader, hostname, user,
      # stateVersion, monitor layout -- lives there, in a file you own.
      templates = {
        laptop = {
          path = ./templates/laptop;
          description = "A complete /etc/nixos for the suckless-environment desktop";
          welcomeText = ''
            Wrote `flake.nix`, `configuration.nix`, `home.nix` and `autostart.sh`.

            Next:

            1. Edit the four lines marked `EDIT` in `configuration.nix`:
               hostname, username, timezone, stateVersion.

            2. Check that `hardware-configuration.nix` is still beside them.

            3. Rebuild. The `--option` is needed for this switch and no other,
               because a fresh NixOS has no flake support until the switch
               that turns it on has already happened:

               ```
               sudo nixos-rebuild switch --flake /etc/nixos#nixos-btw \
                 --option extra-experimental-features "nix-command flakes"
               ```
          '';
        };
        default = self.templates.laptop;
      };

      # Expose the tools as pkgs.suckless-env.<name>:
      #   nixpkgs.overlays = [ suckless-env.overlays.default ];
      overlays.default = final: _prev: {
        suckless-env = import ./nix/packages.nix { pkgs = final; };
      };

      #   nix build .#dwm .#dmenu .#st .#slstatus .#utils
      packages = forAllSystems (
        pkgs:
        import ./nix/packages.nix { inherit pkgs; }
        // (lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
          # A bootable QEMU image of the test host:
          #   nix run .#vm
          vm = self.nixosConfigurations.vm.config.system.build.vm;
        })
      );

      # `nix run .#vm` — no `./result/bin/run-*-vm` path to remember, and no
      # result symlink left in the working tree.
      #
      # optionalAttrs wraps the whole `vm' attribute rather than its value:
      # an app must be `{ type = "app"; program = ...; }', and an empty set
      # is not one. With the guard on the inside, `apps.aarch64-linux.vm'
      # existed and evaluated to {}, which `nix flake show' rejects with
      # "not an app definition" -- on every system, because it walks them
      # all. `nix flake check' never caught it: it skips the systems it
      # cannot build for.
      apps = forAllSystems (
        pkgs:
        lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
          vm = {
            type = "app";
            program = "${self.nixosConfigurations.vm.config.system.build.vm}/bin/run-suckless-vm-vm";
          };
        }
      );

      # The only complete system here is the disposable one: a VM owns its
      # virtual disk, so declaring it costs nothing and breaks nothing.
      # See hosts/vm.nix.
      nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./hosts/vm.nix ];
      };

      # `nix flake check` builds every one of these, so CI and a bare
      # `nix flake check` cover the same ground: all five tools build, the
      # utils test suite runs, and the VM — which imports nix/module.nix —
      # proves the module still evaluates and builds.
      checks = forAllSystems (
        pkgs:
        lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") (
          import ./nix/packages.nix { inherit pkgs; }
          // {
            vm = self.nixosConfigurations.vm.config.system.build.toplevel;

            # nixosModules.laptop has no filesystem of its own, so it cannot
            # be a nixosConfiguration. Give it a throwaway root purely to
            # prove the module evaluates and builds — the fake disk lives
            # here, in the check, and never in the module.
            laptop-module =
              (nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";
                modules = [
                  self.nixosModules.laptop
                  {
                    fileSystems."/" = {
                      device = "/dev/null";
                      fsType = "ext4";
                    };
                    boot.loader.grub.enable = false;
                    system.stateVersion = "26.05";
                  }
                ];
              }).config.system.build.toplevel;

            # The same treatment for the installation template, and for the
            # same reason: a template nobody evaluates is a template that
            # rots. This builds templates/laptop/configuration.nix on top of
            # the module, against a throwaway root standing in for the
            # generated hardware-configuration.nix.
            #
            # What it does NOT cover: templates/laptop/home.nix, which needs
            # home-manager, and adding that as an input here to check twenty
            # lines of `home.packages' is not a trade worth making. flake.nix
            # and autostart.sh in the template are checked by `nix flake
            # check' itself, which validates every `templates' entry.
            install-template =
              (nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";
                modules = [
                  self.nixosModules.laptop
                  ./templates/laptop/configuration.nix
                  {
                    fileSystems."/" = {
                      device = "/dev/null";
                      fsType = "ext4";
                    };
                    fileSystems."/boot" = {
                      device = "/dev/null";
                      fsType = "vfat";
                    };
                  }
                ];
              }).config.system.build.toplevel;
          }
        )
      );

      # `nix fmt`
      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = [ pkgs.nixfmt ];
        };
      });
    };
}
