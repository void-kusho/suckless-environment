# /etc/nixos/configuration.nix — what belongs to THIS installation.
#
# The window manager, terminal, menus, status bar, utilities, session
# daemons, fonts, fcitx5/mozc, Ly and the Intel hardware bits all come from
# suckless-env.nixosModules.laptop, imported in flake.nix. This file holds
# only boot, identity and the user.
#
# Everything the module declares is lib.mkDefault, so a plain assignment
# here outranks it. That is how the language block below works.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # --------------------------------------------------------------------
  # Boot.
  #
  # systemd-boot needs an EFI system partition mounted at /boot — which is
  # what `nixos-generate-config' will have written into
  # hardware-configuration.nix if you installed in UEFI mode. On a BIOS/MBR
  # install, delete these two lines and use
  # `boot.loader.grub = { enable = true; device = "/dev/sda"; }' instead.
  # --------------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --------------------------------------------------------------------
  # Identity.
  # --------------------------------------------------------------------
  # EDIT: letters, digits, - and _ only.
  networking.hostName = "nixos-btw";
  networking.networkmanager.enable = true;

  # EDIT: yours. `timedatectl list-timezones' has the full list.
  time.timeZone = "America/Sao_Paulo";

  # --------------------------------------------------------------------
  # The user.
  #
  #   wheel          -> sudo, and the polkit rule that mounts internal disks
  #   networkmanager -> nmcli/nmtui without sudo
  #   video, input   -> the backlight udev rules the module installs
  #
  # Ly asks for a password, and an account without one cannot log in at
  # all. initialPassword applies only when the account is created, so it is
  # ignored on every rebuild after the first; change it with `passwd' once
  # you are in, and delete the line.
  # --------------------------------------------------------------------
  # EDIT: your username. It must also match flake.nix (home-manager) and
  # the paths in the activation script at the bottom of this file.
  users.users.void = {
    isNormalUser = true;
    description = "void";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
    initialPassword = "change-me";
    packages = with pkgs; [ tree ];
  };

  # --------------------------------------------------------------------
  # Interface language.
  #
  # The module makes this desktop Japanese-first — ja_JP.UTF-8 with
  # LANGUAGE=ja:en, so anything without a Japanese translation falls back
  # to English rather than to the C locale. It declares both with
  # mkDefault precisely so an installation can decide otherwise.
  #
  # Delete this block to keep Japanese. Keep it for an English desktop.
  #
  # This is the *interface* language and nothing else: the keyboard is a
  # separate set of options (br/abnt2 on X, br-abnt2 on the TTYs) and stays
  # with the module, and fcitx5 + mozc stay installed either way, so typing
  # Japanese is still one hotkey (Ctrl+Alt+Space) away.
  #
  # en_US.UTF-8 is already in i18n.supportedLocales, so this generates no
  # new locale and rebuilds no glibc-locales: it changes /etc/locale.conf
  # and nothing else.
  # --------------------------------------------------------------------
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings.LANGUAGE = "en";

  # ...and the way back, kept symmetric. The module ships
  # `specialisation.english', a second system built alongside this one; with
  # the block above it would be identical to its own parent — two English
  # entries in the boot menu, one named for the thing that no longer
  # distinguishes it. mkForce replaces the whole attribute set, so this
  # installation owns the specialisations: the parent is English, and there
  # is exactly one alternative.
  #
  # mkForce on the values too, and that part is not optional: the parent now
  # declares both at normal priority, and a specialisation merges as just
  # another module, so without it the definitions collide.
  #
  # Switch without rebooting, then log out and back in (a running session
  # keeps the LANG it started with):
  #
  #   sudo /run/current-system/specialisation/japanese/bin/switch-to-configuration switch
  #
  # For one program none of this is needed: `LANG=ja_JP.UTF-8 emacs' works
  # as-is, because the locale is generated either way.
  specialisation = lib.mkForce {
    japanese.configuration = {
      i18n.defaultLocale = lib.mkForce "ja_JP.UTF-8";
      i18n.extraLocaleSettings = lib.mkForce { LANGUAGE = "ja:en"; };
    };
  };

  # --------------------------------------------------------------------
  # Monitor layout, declaratively persisted.
  #
  # The dwm launcher sources ~/.config/suckless/autostart.sh on every login.
  # Nothing creates that file — it is machine state, which is exactly why
  # the repository refuses to carry it. This activation script installs it
  # from ./autostart.sh on every switch, so the layout is part of the
  # configuration and cannot drift from it.
  #
  # The consequence: edits to ~/.config/suckless/autostart.sh are
  # overwritten. Edit ./autostart.sh instead, and apply it without
  # rebooting with `sudo /nix/var/nix/profiles/system/activate'.
  #
  # Delete this block and the file if you have one monitor and nothing to
  # set up at login.
  # --------------------------------------------------------------------
  system.activationScripts.suckless-autostart = {
    deps = [ "users" ];
    text = ''
      install -D -m 0644 -o void -g users \
        ${./autostart.sh} /home/void/.config/suckless/autostart.sh
    '';
  };

  # --------------------------------------------------------------------
  # Unfree licences.
  #
  # This lives here rather than in home.nix for a mechanical reason: the
  # flake sets home-manager.useGlobalPkgs, so home-manager receives this
  # same finished pkgs and never evaluates nixpkgs again — `nixpkgs.config'
  # inside home.nix would be ignored in silence. This is the only place the
  # option has any effect.
  #
  # Named one by one rather than a blanket allowUnfree: a typo or a future
  # dependency does not get in for free. Brave, which looks like it would
  # need to be here, is MPL-2.0 and does not.
  # --------------------------------------------------------------------
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "spotify"
      "obsidian"
    ];

  # A convenience alias. It goes here and not into home-manager on purpose:
  # declaring `programs.bash' for the user would make home-manager write its
  # own ~/.bashrc, which does not load the /etc/bashrc where the module
  # injects history, shopts, the Tokyo Night prompt, the aliases and the
  # hyfetch greeting. One alias is not worth trading the whole shell for.
  programs.bash.interactiveShellInit = lib.mkAfter ''
    alias btw='echo I use nixos, btw'
  '';

  # Brave is this desktop's browser; Firefox is here because it is useful to
  # have a second engine. Delete if you disagree.
  programs.firefox.enable = true;

  # --------------------------------------------------------------------
  # EDIT: the NixOS release you INSTALLED, not the one you are running.
  #
  # This is not a version to keep current. It pins the defaults the
  # configuration was written against, so upgrading nixpkgs does not
  # silently turn on new behaviour underneath you. Change it deliberately,
  # after reading the release notes, or never.
  # --------------------------------------------------------------------
  system.stateVersion = "26.05";
}
