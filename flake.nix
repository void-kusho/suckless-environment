{
  description = "Personal suckless environment (dwm, dmenu, st, slstatus) packaged for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
        ] (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # Optional: expose the tools as pkgs.suckless-env.<name>
      #   nixpkgs.overlays = [ suckless-env.overlays.default ];
      overlays.default = final: _prev: {
        suckless-env = import ./nix/packages.nix { pkgs = final; };
      };

      #   nix build .#dwm .#dmenu .#st .#slstatus
      packages = forAllSystems (pkgs: import ./nix/packages.nix { inherit pkgs; });

      #   imports = [ suckless-env.nixosModules.default ];
      #   programs.suckless-environment.enable = true;
      nixosModules.default = import ./nix/module.nix;

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = with pkgs; [ nixfmt-rfc-style ];
        };
      });
    };
}
