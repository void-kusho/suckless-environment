# /etc/nixos/home.nix — what belongs to the USER, not to the machine.
#
# Optional. Delete this file and the blocks marked HOME-MANAGER in
# flake.nix, and declare applications in configuration.nix instead
# (`users.users.<name>.packages' or `environment.systemPackages').
#
# home-manager enters as a NixOS module with useGlobalPkgs, so it uses the
# SAME pkgs as the system and the allowUnfreePredicate from
# configuration.nix applies here too. With useUserPackages the packages go
# to /etc/profiles/per-user/$USER and are part of the system closure: one
# `nixos-rebuild switch' applies everything, with no `home-manager switch'
# to remember.
{ pkgs, ... }:

{
  # EDIT: your username and home directory.
  home.username = "void";
  home.homeDirectory = "/home/void";

  # Plain packages: things with no home-manager module worth using.
  home.packages = with pkgs; [
    spotify
    pavucontrol # per-application volume and routing; the desktop already
    # has pulsemixer (TUI) and pamixer (what slstatus calls)
    dosfstools
    ntfs3g

    # Toolchains. These are deliberately absent from the system module —
    # `nix shell nixpkgs#rust-analyzer' in the project that needs one beats
    # installing every toolchain on every machine — but a language you use
    # daily is a different question, and it is the user's to answer.
    rustc
    cargo
    rust-analyzer
    zig
    zls
  ];

  # OBS through its module, not as a package: the module builds the wrapper
  # that can find plugins, which a bare package cannot. Plugins go here:
  #
  #   programs.obs-studio.plugins = with pkgs.obs-studio-plugins; [ obs-vkcapture ];
  #
  # The virtual camera is not from here — it is a kernel module
  # (v4l2loopback) gated behind the SYSTEM obs-studio module, so turning it
  # on would install a second OBS beside this one. If you need it, declare
  # the kernel module in configuration.nix directly.
  programs.obs-studio.enable = true;

  # Obsidian through its module for one concrete reason: it writes
  # `updateDisabled = true' into ~/.config/obsidian/obsidian.json. Obsidian's
  # built-in updater cannot work on NixOS — the binary is in the read-only
  # store — and without this it keeps trying and failing. Activation merges
  # with jq into the existing file, so vaults you create in the UI survive
  # a rebuild.
  programs.obsidian.enable = true;

  # Deliberately NOT declaring `programs.bash' here: it would write its own
  # ~/.bashrc, which does not load the /etc/bashrc where the desktop module
  # injects history, shopts, the Tokyo Night prompt, the aliases and the
  # hyfetch greeting.

  # Same meaning as system.stateVersion: the defaults this was written
  # against. Not a version to keep current.
  home.stateVersion = "26.05";
}
