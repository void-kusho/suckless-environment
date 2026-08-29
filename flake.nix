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
      # The whole desktop behind one toggle:
      #   imports = [ suckless-env.nixosModules.default ];
      #   programs.suckless-environment.enable = true;
      nixosModules.default = import ./nix/module.nix;

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
      apps = forAllSystems (pkgs: {
        vm = lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
          type = "app";
          program = "${self.nixosConfigurations.vm.config.system.build.vm}/bin/run-suckless-vm-vm";
        };
      });

      nixosConfigurations = {
        # The real machine. `sudo nixos-rebuild switch --flake .#laptop`
        laptop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./hosts/laptop.nix ];
        };

        # Disposable test host — see hosts/vm.nix.
        vm = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./hosts/vm.nix ];
        };
      };

      # `nix flake check` builds every one of these, so CI and a bare
      # `nix flake check` cover the same ground: both hosts evaluate, all five
      # tools build, and the utils test suite runs.
      checks = forAllSystems (
        pkgs:
        lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") (
          import ./nix/packages.nix { inherit pkgs; }
          // {
            laptop = self.nixosConfigurations.laptop.config.system.build.toplevel;
            vm = self.nixosConfigurations.vm.config.system.build.toplevel;
          }
        )
      );

      # `nix fmt`
      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = with pkgs; [ nixfmt-rfc-style ];
        };
      });
    };
}
