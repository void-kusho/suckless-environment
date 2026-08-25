# Classic (non-flake) entrypoint.
#
# Import this directory from /etc/nixos/configuration.nix:
#
#   imports = [ ./suckless-environment ];
#   programs.suckless-environment.enable = true;
import ./nix/module.nix
