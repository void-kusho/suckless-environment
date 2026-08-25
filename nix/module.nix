# NixOS module: the whole desktop behind a single toggle.
#
#   programs.suckless-environment.enable = true;
#
# What it provides:
#
#   * Tools:    dwm (+ Fibonacci, systray, ...), dmenu (+ desktoponly),
#               st (+ kitty-graphics, ligatures, ...), slstatus
#   * Utils:    battery-notify, brightness-notify, dmenu-session,
#               dmenu-cpupower, dmenu-clip, dmenu-clipd
#   * Session:  dunst, clipboard daemon, polkit agent, fcitx5 (mozc),
#               battery monitor loop, slstatus supervisor loop --
#               all started by the dwm launcher
#   * Desktop:  thunar, brave, flameshot, feh, betterlockscreen,
#               brightnessctl, picom, xdotool, pactl ...
#   * System:   br/abnt2 keyboard, backlight udev rules,
#               power-profiles-daemon (for dmenu-cpupower), bluetooth,
#               PipeWire audio, NetworkManager, CJK/Nerd fonts
#
# Login flows supported:
#   * Display manager (Ly/greetd/sddm/...): dwm is the default session.
#   * No display manager: log into a TTY and run `startx`.
#
# Machine-specific bits (monitor layouts, wallpaper) do NOT belong here:
# the session sources ~/.config/suckless/autostart.sh if present -- see
# README ("Autostart hook").
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.suckless-environment;

  packages = import ./packages.nix { inherit pkgs; };

  # dwm launcher: starts the session daemons and supervisor loops, then
  # execs the real window manager. Used by BOTH login flows (display
  # managers see it as the "none+dwm" session; startx reaches it through
  # the generated xinitrc).
  #
  # Design notes:
  #   * no manual pipewire/pulse/wireplumber: systemd user services do it
  #   * monitor layout + wallpaper live in ~/.config/suckless/autostart.sh
  dwm = pkgs.writeShellScriptBin "dwm" ''
    # Machine-specific setup first (monitors, wallpaper, pointer warp).
    if [ -f "$HOME/.config/suckless/autostart.sh" ]; then
      . "$HOME/.config/suckless/autostart.sh"
    fi

    start_daemon() {
      command -v "$1" >/dev/null || return 0
      # pgrep matches process names only -> strip any directory prefix.
      pgrep -x "''${1##*/}" >/dev/null || "$@" &
    }

    # Session daemons (idempotent across dwm restarts / re-logins).
    ${pkgs.procps}/bin/pkill -x slstatus 2>/dev/null || true
    start_daemon ${pkgs.lxsession}/bin/lxpolkit
    start_daemon ${pkgs.fcitx5}/bin/fcitx5 -d
    start_daemon ${packages.utils}/bin/dmenu-clipd
    start_daemon ${pkgs.dunst}/bin/dunst
    start_daemon ${pkgs.flameshot}/bin/flameshot
    ${lib.optionalString cfg.compositor.enable ''
      # Compositor: vsync + subtle open/close animations (picom/picom.conf).
      start_daemon ${pkgs.picom}/bin/picom -b
    ''}

    # Battery monitor: 30 second tick.
    (
      while :; do
        ${packages.utils}/bin/battery-notify
        sleep 30
      done
    ) &

    # Status bar supervisor: relaunch slstatus if it ever dies.
    (
      while :; do
        ${packages.slstatus}/bin/slstatus
        sleep 1
      done
    ) &

    exec ${packages.dwm}/bin/dwm
  '';

  # True when an explicitly chosen display manager is enabled. Used to
  # decide whether X should start at boot. NOTE: we deliberately ignore
  # services.*displayManager.lightdm here -- recent nixpkgs turns it on
  # as a fallback whenever X11 is enabled, so it cannot signal intent.
  # Greeters outside this list need `services.xserver.autorun = true;`.
  displayManagerEnabled =
    (config.services.displayManager.ly or { enable = false; }).enable
    || (config.services.displayManager.sddm or { enable = false; }).enable
    || (config.services.displayManager.cosmic-greeter or { enable = false; }).enable
    || (config.services.greetd or { enable = false; }).enable;

  # Backlight permissions for the `video` group (and kbd backlight for
  # `input`). sysfs attributes have no /dev node, hence RUN+= chgrp/chmod
  # instead of udev GROUP=/MODE= directives.
  backlightUdevRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*::kbd_backlight", RUN+="${pkgs.coreutils}/bin/chgrp input /sys/class/leds/%k/brightness"
    ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*::kbd_backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/leds/%k/brightness"
  '';

  # st is not shipped with a .desktop file upstream; exo (Thunar's
  # "Open Terminal Here") needs one advertising TerminalEmulator to be
  # able to pick it.
  stDesktopEntry = pkgs.writeTextFile {
    name = "st-desktop-entry";
    destination = "/share/applications/st.desktop";
    text = ''
      [Desktop Entry]
      Type=Application
      Name=st
      GenericName=Terminal
      Comment=Simple terminal (suckless)
      Exec=st
      Icon=utilities-terminal
      Categories=System;TerminalEmulator;
      StartupWMClass=st-256color
    '';
  };
in

{
  options.programs.suckless-environment = {
    enable = lib.mkEnableOption "the suckless-environment desktop (dwm + st + dmenu + slstatus + utils)";

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        Extra packages added to the system alongside the environment
        (personal apps like discord, steam, editors, ...).
      '';
      example = lib.literalExpression "[ pkgs.discord pkgs.steam ]";
    };

    compositor = {
      enable = lib.mkEnableOption "the picom compositor (vsync + subtle open/close animations), started with the session" // {
        default = true;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      with pkgs;
      [
        dwm # session launcher (starts daemons, execs real dwm)

        packages.utils
        packages.slstatus
        packages.st
        packages.dmenu

        # session daemons & helpers referenced above or by keybinds
        dunst # notifications (battery/brightness alerts)
        lxsession # provides lxpolkit, the polkit authentication agent
        flameshot # Print-key screenshots
        feh # wallpaper (from autostart hook)
        brightnessctl # brightness engine used by brightness-notify
        xdotool # pointer warp (autostart hook)
        xclip
        xsel
        picom # compositor (installed; launch from autostart hook if wanted)
        pulseaudio # provides pactl for the volume media keys
        betterlockscreen # lock screen used by dmenu-session

        # applications bound in dwm/config.h
        xfce.thunar
        brave

        # thunar integrations
        #   * "Open Terminal Here": exo-open resolves the terminal through
        #     helpers.rc (seeded below) -> the st desktop entry also added
        #     below.
        #   * "Extract Here" / "Create Archive...": thunar-archive-plugin
        #     delegates to xarchiver; p7zip/zip/unzip are its backends.
        xfce.exo
        xfce.thunar-archive-plugin
        xarchiver
        p7zip
        zip
        unzip

        # bluetooth stack (blueman available; pair via cli or blueman-manager)
        blueman

        # desktop entry so exo/gio can find st as a TerminalEmulator
        stDesktopEntry
      ]
      ++ lib.optionals (cfg.extraPackages != [ ]) cfg.extraPackages;

    services.xserver = {
      enable = true;
      # Start X at boot only when a display manager will show a session
      # picker; otherwise the user logs into a TTY and runs `startx`.
      autorun = lib.mkDefault displayManagerEnabled;

      # Register dwm as a selectable session for display managers.
      windowManager.dwm = {
        enable = true;
        package = dwm;
      };

      # Without any display manager, use NixOS's official startx
      # pseudo-DM: it provides the `startx` command (xorg.xinit) and
      # generates a sane system-wide xinitrc.
      displayManager.startx = {
        enable = lib.mkDefault (!displayManagerEnabled);
        generateScript = lib.mkDefault true;
      };

      # Brazilian ABNT2 layout, pinned declaratively at the X server
      # level -- no /etc/X11/xorg.conf.d snippets needed.
      xkb = {
        layout = "br";
        model = "abnt2";
        variant = "abnt2";
      };
    };
    services.displayManager.defaultSession = lib.mkDefault "none+dwm";

    # Japanese input: fcitx5 + mozc. The option exports GTK_IM_MODULE /
    # QT_IM_MODULE / XMODIFIERS for every session, so no .xprofile is
    # needed.
    i18n.inputMethod = {
      type = "fcitx5";
      fcitx5.addons = with pkgs; [ fcitx5-mozc ];
    };
    # Seed configuration (rest on br keyboard, mozc on demand). Deployed
    # system-wide; fcitx5 copies/rewrites these into ~/.config on change.
    environment.etc."xdg/fcitx5/profile".source = ../fcitx5/profile;
    environment.etc."xdg/fcitx5/config".source = ../fcitx5/config;

    # Notification daemon settings (urgency levels, geometry, theme).
    environment.etc."xdg/dunst/dunstrc".source = ../dunst/dunstrc;

    # Compositor settings: vsync + subtle open/close animations. Deployed
    # system-wide; a user ~/.config/picom/picom.conf overrides it.
    environment.etc."xdg/picom/picom.conf".source = ../picom/picom.conf;

    # Preferred applications for Xfce helpers (exo-open, used by Thunar's
    # native "Open Terminal Here"). Values are desktop-file ids. A user
    # ~/.config/xfce4/helpers.rc overrides this.
    environment.etc."xdg/xfce4/helpers.rc".text = ''
      TerminalEmulator=st
      TerminalEmulatorDismissed=true
      WebBrowser=brave-browser
      WebBrowserDismissed=true
    '';

    # Fonts: Iosevka Nerd Font everywhere in the configs; Noto CJK covers
    # the Japanese tag glyphs and status text; emoji for notifications.
    fonts.packages = with pkgs; [
      nerd-fonts.iosevka
      noto-fonts-cjk-sans
      noto-fonts-emoji
    ];
    fonts.fontconfig.defaultFonts.monospace = [
      "Iosevka Nerd Font Mono"
      "Noto Sans Mono CJK JP"
    ];

    # Backlight access for the video/input groups (brightnessctl +
    # brightness-notify). Add your user to those groups!
    services.udev.extraRules = backlightUdevRules;

    # CPU profile switching for dmenu-cpupower (Super+p).
    services.power-profiles-daemon.enable = lib.mkDefault true;

    # Bluetooth stack (pairing tools: bluetoothctl, blueman-manager).
    hardware.bluetooth.enable = lib.mkDefault true;

    # Audio: pamixer/pactl talk PulseAudio; PipeWire implements it.
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };

    networking.networkmanager.enable = true;
  };
}
