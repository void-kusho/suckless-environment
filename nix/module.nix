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
#               brightnessctl, picom, xdotool, pactl, appimage-run ...
#   * System:   br/abnt2 keyboard, backlight udev rules,
#               power-profiles-daemon (for dmenu-cpupower), bluetooth,
#               PipeWire audio, NetworkManager, CJK/Nerd fonts
#
# Login: Ly, on tty1, themed Tokyo Night, with dwm as its default session.
# Set services.displayManager.ly.enable = false for the other flow -- a TTY
# login and `startx` -- which the module wires up automatically in that case.
# Another greeter (greetd, SDDM) works too; see displayManagerEnabled below.
#
# Machine-specific bits (monitor layouts, pointer warp) do NOT belong here:
# the session sources ~/.config/suckless/autostart.sh if present. The
# wallpaper used to be left there too, but nothing ever created that file, so
# it is an option now -- see programs.suckless-environment.wallpaper.
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
  #   * monitor layout lives in ~/.config/suckless/autostart.sh
  dwm = pkgs.writeShellScriptBin "dwm" ''
    ${lib.optionalString (cfg.wallpaper != null) ''
      # Wallpaper. Painted before the autostart hook runs, so a hook that sets
      # its own overrides this rather than fighting it.
      ${pkgs.feh}/bin/feh --no-fehbg --bg-fill ${cfg.wallpaper} || true
    ''}

    # Machine-specific setup (monitor layout, pointer warp, a different
    # wallpaper). Nothing creates this file; it is yours to write.
    if [ -f "$HOME/.config/suckless/autostart.sh" ]; then
      . "$HOME/.config/suckless/autostart.sh"
    fi

    start_daemon() {
      command -v "$1" >/dev/null || return 0
      # Match the full store path rather than the process name. A package
      # built with makeWrapper runs as `.dunst-wrapped` (and comm is capped
      # at 15 characters, so flameshot is `.flameshot-wrap`), which
      # `pgrep -x dunst` can never match -- four of the six daemons below
      # are wrapped, and the guard silently did nothing for all of them.
      # The wrapper keeps argv[0], so the full path is still in cmdline.
      pgrep -f "^$1" >/dev/null || "$@" &
    }

    # Session daemons (idempotent across dwm restarts / re-logins).
    ${pkgs.procps}/bin/pkill -x slstatus 2>/dev/null || true
    start_daemon ${pkgs.lxsession}/bin/lxpolkit
    start_daemon ${config.i18n.inputMethod.package}/bin/fcitx5 -d
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

  # True when a display manager is enabled. Used to decide whether X should
  # start at boot. Ly is on by default (see below), so this is normally
  # true; turn Ly off and the module falls back to startx from a TTY.
  #
  # lightdm is deliberately absent from the list. The reason recorded here
  # used to be that recent nixpkgs enables it as a fallback whenever X11 is
  # on -- on 26.05 that is no longer true (it evaluates to false with and
  # without Ly), but an implicit fallback still cannot signal intent, so
  # leaving it out costs nothing. Greeters outside this list need
  # `services.xserver.autorun = true;`.
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

  # Adapter between st and exo's fallback calling convention.
  #
  # exo 4.20 delegates "run this in the preferred terminal" to
  # `xfce4-mime-helper', which ships in xfce4-settings -- a 1.5 GiB
  # closure for one 30 KiB binary, so it is not installed here. Without
  # it exo_execute_preferred_application_on_screen() takes its fallback
  # path, which resolves the helpers.rc value with g_find_program_in_path
  # and then spawns exactly
  #
  #     <that binary> "<the whole command line, as ONE argv entry>"
  #
  # with no -e and no shell. st reads that single string as argv[0] and
  # dies with "child exited with status 1", which is what Thunar's error
  # dialog was reporting: *nothing* could be run in a terminal from the
  # file manager -- a compiled binary, a script, a Terminal=true desktop
  # entry, any of them. The real helper framework would have used the
  # `X-XFCE-CommandsWithParameter=%B -e %s' line of an X-XFCE-Helper
  # file; this does the same job in three lines.
  stExoHelper = pkgs.writeShellScriptBin "st-exo-helper" ''
    # No argument: plain terminal (Thunar's "Open Terminal Here", which
    # passes the directory through exo's --working-directory instead).
    [ "$#" -eq 0 ] && exec ${packages.st}/bin/st
    exec ${packages.st}/bin/st -e ${pkgs.bash}/bin/sh -c "$*"
  '';

  # st is not shipped with a .desktop file upstream; gio needs one to list
  # st among the applications that can open a file.
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

  # Doom Emacs: $DOOMDIR is read-only configuration, and Doom honours the
  # environment variable, so it can point straight into the store -- no seed
  # copy, no first-run hook, nothing to drift. Doom's mutable state lives in
  # ~/.config/emacs and ~/.local/share/doom, both untouched by this.
  #
  # The framework itself stays a git checkout (`doom install'); pinning it
  # here would mean vendoring Doom, which is not this repository's job.
  doomDir = pkgs.runCommand "doom-config" { } ''
    mkdir -p $out
    install ${../doom/init.el} $out/init.el
    install ${../doom/config.el} $out/config.el
    install ${../doom/packages.el} $out/packages.el
  '';

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
      enable =
        lib.mkEnableOption "the picom compositor (vsync + subtle open/close animations), started with the session"
        // {
          default = true;
        };
    };

    wallpaper = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = ../wallpapers/sushi_original.png;
      description = ''
        Image painted onto the root window by feh when the session starts.

        This used to be left to ~/.config/suckless/autostart.sh, which nothing
        in this repository ever created -- so every fresh install, the test VM
        included, came up on a bare X root window. Set to null to paint
        nothing and handle it from the autostart hook yourself.
      '';
      example = lib.literalExpression "./my-wallpaper.png";
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
        feh # paints the wallpaper; also available to the autostart hook
        brightnessctl # brightness engine used by brightness-notify
        xdotool # pointer warp (autostart hook)
        xclip
        xsel
        picom # compositor (installed; launch from autostart hook if wanted)
        pulseaudio # provides pactl for the volume media keys
        pamixer # slstatus' volume segment shells out to it (slstatus/config.h)
        libnotify # notify-send -- battery-notify and brightness-notify call it
        betterlockscreen # lock screen used by dmenu-session

        # applications bound in dwm/config.h
        brave

        # gtk-launch: dmenu_run_desktop pipes the selection into it, so
        # Super+d lists applications and launches nothing without this.
        gtk3

        # Thunar itself comes from programs.thunar below, which is what wires
        # up its D-Bus services; these are the backends its plugins call.
        #   * "Open Terminal Here" goes through exo-open -> helpers.rc (below)
        #     -> st-exo-helper (above).
        #   * "Extract Here" delegates to xarchiver.
        xfce4-exo
        xarchiver
        p7zip
        zip
        unzip

        # Look and feel. dwm draws nothing but window borders, so without a
        # GTK theme every GTK app -- Thunar, Brave's dialogs, lxappearance
        # itself -- comes up in raw light Adwaita against a Tokyo Night
        # desktop. lxappearance is the GUI that changes it.
        # Configuring the system without a desktop environment. TUI where one
        # exists, GUI only where it does not.
        wifitui # TUI: wifi -- the same 0.13.0 the reference machine runs
        # nmtui also ships with networkmanager, and covers wired and VPN.
        pulsemixer # TUI: audio devices, volume, default sink
        bluetuith # TUI: bluetooth pairing
        arandr # GUI: monitor layout, writes an xrandr line for autostart.sh
        lxappearance # GUI: GTK theme, icons, cursor, UI font
        arc-theme # Arc-Dark, the theme the reference machine uses
        papirus-icon-theme
        adwaita-icon-theme # cursor fallback, and what GTK expects to exist
        qt6Packages.fcitx5-configtool # GUI: input methods and switch keys

        # nixpkgs dropped neofetch as unmaintained. hyfetch ships neowofetch,
        # the maintained fork, which reads the same ~/.config/neofetch/config.conf
        # -- so the greeting is the one from the reference machine, not a
        # different tool with a different config format.
        hyfetch

        # Doom Emacs and what `doom doctor' asks for. Language servers and
        # compilers are deliberately absent: `nix shell nixpkgs#rust-analyzer'
        # in the project that needs one beats installing every toolchain on
        # every machine.
        emacs
        git
        ripgrep
        fd
        cmake
        libtool
        gnumake
        pkg-config
        poppler-utils
        autoconf
        automake

        # desktop entry so gio can offer st as an application
        stDesktopEntry
        # ...and the shim exo's helpers.rc points at (see below)
        stExoHelper
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

      # Brazilian ABNT2, pinned declaratively at the X server level -- no
      # /etc/X11/xorg.conf.d snippets needed. `abnt2` is both the model and
      # the default xkb_symbols section of layout br, so naming the variant
      # is redundant; it is spelled out because this keyboard is the whole
      # reason the block exists.
      xkb = {
        layout = "br";
        model = "abnt2";
        variant = "abnt2";
      };

      # Key repeat. X's defaults (660 ms before the first repeat, ~40 ms
      # between them) are slow enough to be felt in a tiling window manager,
      # where navigation is held keys. These are the reference machine's.
      autoRepeatDelay = lib.mkDefault 200;
      autoRepeatInterval = lib.mkDefault 35;
    };
    services.displayManager.defaultSession = lib.mkDefault "none+dwm";

    # Ly is this desktop's display manager. dwm is registered as `none+dwm`
    # just above and set as the default session, so Ly lists it and starts
    # it: the .desktop it reads execs NixOS's xsession wrapper, which runs
    # `dwm` from PATH -- the launcher at the top of this file, daemons and
    # all.
    #
    # mkDefault, so a host that sets this to false gets the other flow
    # instead: displayManagerEnabled goes false, xserver.autorun follows it
    # down and the startx pseudo-DM comes back on. hosts/vm.nix does exactly
    # that.
    services.displayManager.ly.enable = lib.mkDefault true;
    services.displayManager.ly.settings = {
      # Tokyo Night, the palette everything else here uses. Ly takes
      # 0xAARRGGBB where the top byte is an ATTRIBUTE rather than alpha:
      # 0x01 is bold, which is why the upstream default error colour is
      # 0x01FF0000 and the rest are 0x00.
      bg = "0x001a1b26";
      fg = "0x00a9b1d6";
      border_fg = "0x00414868";
      error_fg = "0x01f7768e";

      # ASCII on purpose. slstatus prints 年月日 and it is tempting to match
      # it, but Ly draws on the Linux console, whose font has no CJK -- the
      # greeter would show tofu before X ever starts.
      clock = "%Y-%m-%d %H:%M";
    };

    # The virtual terminals. services.xserver.xkb above only reaches X, so
    # the TTYs stayed on the US map -- and with startx as the default login
    # flow, the password prompt is a TTY. br-abnt2 is kbd's own name for
    # this keyboard.
    console.keyMap = lib.mkDefault "br-abnt2";

    # A console font with Latin-1/Latin-2 coverage, so accented Portuguese
    # is readable at the Ly greeter and on a TTY. The kernel's built-in font
    # is ASCII, which is fine right up to the first "ç".
    console.font = lib.mkDefault "Lat2-Terminus16";

    # Bash: the user's interactive shell configuration (history, shopts,
    # Tokyo Night colors/prompt, aliases, neofetch greeting). Injected
    # into every interactive bash via /etc/bashrc.
    programs.bash = {
      interactiveShellInit = builtins.readFile ../bash/bashrc;
      completion.enable = true;

      # NixOS's stock prompt, silenced. Both of these land in /etc/bashrc,
      # and promptInit is emitted AFTER interactiveShellInit -- so the stock
      # block reassigned PS1 over the Tokyo Night prompt that bash/bashrc
      # sets, unconditionally, on every terminal where TERM is not "dumb".
      # The result was NixOS's green [user@host:dir]$ on a desktop where
      # everything else is Tokyo Night, and nothing in bash/bashrc could
      # have fixed it: the overwrite happens later in the same file.
      #
      # Emptying it is also what keeps parity: bash/bashrc is byte-identical
      # to origin/artix, and no such default exists there. The one thing
      # given up with it is the xterm title escape, which that prompt sets
      # and this one never did -- on Artix too, so st has always been
      # titled "st" rather than the working directory.
      promptInit = "";
    };
    # NixOS defaults EDITOR to nano at the same priority. emacsclient reuses a
    # running daemon and falls back to a fresh emacs when there is none.
    environment.variables = {
      EDITOR = lib.mkForce "emacsclient -a emacs";
      DOOMDIR = "${doomDir}";
    };

    # Japanese input: fcitx5 + mozc. The option exports GTK_IM_MODULE /
    # QT_IM_MODULE / XMODIFIERS for every session, so no .xprofile is
    # needed.
    i18n.inputMethod = {
      # `type` alone is inert: without `enable` the module installs no
      # fcitx5, no mozc, and exports none of GTK_IM_MODULE / QT_IM_MODULE /
      # XMODIFIERS -- so nothing could ever type Japanese. (The option pair
      # replaced the old `i18n.inputMethod.enabled = "fcitx5"` string.)
      enable = true;
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

    # tmux, with the reference machine's configuration: Tokyo Night Moon,
    # C-Space as the prefix, vi copy-mode piping through xclip, Alt+hjkl and
    # Alt+1..9 for panes and windows. programs.tmux writes /etc/tmux.conf,
    # which tmux reads before anything in $HOME.
    #
    # One papercut: the file's own `bind r' reloads
    # $HOME/.config/tmux/tmux.conf, which nothing here creates -- on NixOS the
    # config is read-only and changes come from a rebuild, exactly like
    # $DOOMDIR. The binding is left as-is so tmux/tmux.conf stays byte
    # identical to the Arch/Artix build.
    programs.tmux = {
      enable = true;
      extraConfig = builtins.readFile ../tmux/tmux.conf;
    };

    # Thunar through its own NixOS module rather than as a bare package: the
    # module is what registers thunar's D-Bus services and loads the plugins.
    # A Thunar dropped into systemPackages -- which is what this module used
    # to do -- has no thumbnails, no trash and cannot mount removable media.
    programs.thunar = {
      enable = true;
      plugins = with pkgs; [
        thunar-archive-plugin # "Extract Here" / "Create Archive..."
        thunar-volman # removable media; moved out of xfce. in 26.05
      ];
    };
    services.gvfs.enable = true; # trash, mounting, network shares
    services.tumbler.enable = true; # thumbnails

    # Disks. udisks2 is what actually mounts them; gvfs and thunar-volman
    # are the front ends. No filesystem is declared anywhere in this
    # repository on purpose -- partitions belong to the installation, not to
    # a desktop module.
    services.udisks2.enable = true;

    # ...and this is what makes clicking a disk in Thunar work. udisks2
    # treats anything not hot-pluggable as "system internal", and that
    # polkit action defaults to auth_admin_keep -- so a fixed second drive
    # asks for a password on every login, where a USB stick does not. Let
    # wheel mount and unmount without the prompt; the mount itself still
    # goes through udisks2 (nosuid, nodev, /run/media/$USER/<label>).
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
             action.id == "org.freedesktop.udisks2.filesystem-mount" ||
             action.id == "org.freedesktop.udisks2.filesystem-unmount-others") &&
            subject.isInGroup("wheel") && subject.local && subject.active) {
          return polkit.Result.YES;
        }
      });
    '';

    # AppImages, run the way every other distribution runs them.
    # `programs.appimage` installs appimage-run, an FHS sandbox carrying the
    # graphics, audio and font libraries an AppImage expects to find in
    # /usr/lib and which NixOS does not have. `binfmt` registers that runner
    # with the kernel, so an executable .AppImage starts from `./Foo.AppImage`
    # in a shell or from a double click in Thunar -- not only from an explicit
    # `appimage-run ./Foo.AppImage`.
    #
    # That sandbox's stock library set is not quite enough: a GTK/Flutter
    # AppImage stops at `libepoxy.so.0: cannot open shared object file'
    # before it draws anything.
    programs.appimage = {
      enable = true;
      binfmt = true;
      package = pkgs.appimage-run.override {
        extraPkgs = p: [ p.libepoxy ];
      };
    };

    # The same problem one layer down, for a plain ELF binary that was not
    # built by Nix -- something compiled on another distribution, or on this
    # machine before it was reinstalled.
    #
    # nix-ld answers /lib64/ld-linux-x86-64.so.2, which NixOS otherwise does
    # not have, so such a binary starts at all; but it hands the program only
    # the libraries listed here, and the stock list is libc, libstdc++, zlib,
    # openssl, curl and systemd. Anything with a window or a terminal UI dies
    # one step later with `error while loading shared libraries', naming
    # whichever of these it wanted first -- libgdk-3 for a Tauri app, libX11
    # for Blender, and so on.
    #
    # The list is long and costs almost nothing: every one of these is
    # already in this system's closure, because the desktop itself is GTK and
    # X11 and drags in the same GTK, cairo, pango, fontconfig, Xlib -- and
    # webkitgtk, which is what a Tauri binary links against. Measured against
    # the same system without it, this whole block plus the libepoxy override
    # above adds **238 KiB**: nix-ld itself and a symlink farm.
    #
    # Listing a direct dependency is enough. Each library found here carries
    # its own RUNPATH into the store, so its transitive dependencies resolve
    # without appearing in this list.
    programs.nix-ld = {
      enable = lib.mkDefault true;
      libraries = with pkgs; [
        # GTK and webkit: Tauri, Electron and anything GTK-based
        glib
        gtk3
        gdk-pixbuf
        cairo
        pango
        atk
        at-spi2-atk
        at-spi2-core
        harfbuzz
        webkitgtk_4_1
        libsoup_3
        dbus
        libepoxy

        # X11, and the extensions toolkits actually ask for
        libx11
        libxext
        libxrender
        libxi
        libxfixes
        libxcursor
        libxrandr
        libxcomposite
        libxdamage
        libxxf86vm
        libxcb
        libxkbcommon
        libxtst
        libxinerama
        libxscrnsaver
        libsm
        libice

        # OpenGL/Vulkan, and the Wayland stubs a binary may link even when
        # it ends up running under X
        libglvnd
        mesa
        libgbm
        libdrm
        vulkan-loader
        wayland
        libdecor

        # audio
        alsa-lib
        libpulseaudio

        # fonts and images
        fontconfig
        freetype
        libpng
        libjpeg

        # terminal UIs and the usual suspects
        ncurses
        readline
        sqlite
        nss
        nspr
        expat
        libxml2
        zlib
        openssl
        cups
        libnotify
      ];
    };

    # Preferred applications for exo-open, which is how Thunar opens a
    # terminal and how it runs anything marked "run in a terminal".
    #
    # Two things about this file are not what they look like.
    #
    # The values are *binary names*, not desktop-file ids: exo's fallback
    # feeds them straight to g_find_program_in_path. `brave-browser' was
    # therefore a dead entry -- the binary is `brave' -- and `st' pointed
    # at a terminal that cannot be called the way exo calls it, hence
    # st-exo-helper above.
    #
    # And exo reads it from g_get_user_config_dir() only. Not
    # XDG_CONFIG_DIRS, so not /etc/xdg: this /etc copy is where the
    # content lives, and the tmpfiles rule below is what actually puts it
    # somewhere exo will look. Removing the ~/.config symlink and writing
    # a real file there overrides it; tmpfiles never touches a path that
    # already exists.
    environment.etc."xdg/xfce4/helpers.rc".text = ''
      TerminalEmulator=st-exo-helper
      WebBrowser=brave
    '';

    systemd.user.tmpfiles.rules = [
      "L %h/.config/xfce4/helpers.rc - - - - /etc/xdg/xfce4/helpers.rc"
    ];

    # Thunar's custom actions -- which is where its "Open Terminal Here"
    # actually comes from; Thunar ships no such entry of its own. This one
    # lived only in the reference machine's home directory, so every fresh
    # install of this desktop had a file manager that could not open a
    # terminal. Unlike helpers.rc above, Thunar does search XDG_CONFIG_DIRS
    # for it, so /etc/xdg is enough and no tmpfiles rule is needed.
    environment.etc."xdg/Thunar/uca.xml".source = ../thunar/uca.xml;

    # Timezone. Was never set, so the system -- the test VM included -- ran
    # in UTC.
    time.timeZone = lib.mkDefault "America/Sao_Paulo";

    # Language: Japanese, falling back to English wherever a program has no
    # Japanese translation. That fallback is LANGUAGE, gettext's priority
    # list -- LANG alone would leave untranslated programs in the C locale
    # rather than in English.
    #
    # LC_TIME follows suit, which also matches the status bar: slstatus
    # already prints 年月日.
    #
    # There is no TUI or GUI for this on NixOS: /etc/locale.conf is a symlink
    # into the store, so `localectl set-locale' cannot write to it. The
    # english specialisation below is the switch.
    i18n.defaultLocale = lib.mkDefault "ja_JP.UTF-8";
    i18n.supportedLocales = lib.mkDefault [
      "C.UTF-8/UTF-8"
      "ja_JP.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
      "pt_BR.UTF-8/UTF-8"
    ];
    i18n.extraLocaleSettings = lib.mkDefault {
      LANGUAGE = "ja:en";
    };

    # A whole second system in English, built alongside the Japanese one.
    # Both live in the store at once, so switching costs no rebuild and no
    # network: pick "english" in the boot menu, or
    #
    #   sudo /run/current-system/specialisation/english/bin/switch-to-configuration switch
    #
    # then log out and back in -- a running session keeps the environment it
    # started with. For one session only, none of this is needed:
    # `LANG=en_US.UTF-8 startx' is enough, because the locale is already
    # generated.
    #
    # Note this is the *interface* language. TYPING Japanese is fcitx5 + mozc
    # below, which toggles with a hotkey and needs no system change at all.
    specialisation.english.configuration = {
      i18n.defaultLocale = lib.mkForce "en_US.UTF-8";
      i18n.extraLocaleSettings = lib.mkForce { LANGUAGE = "en"; };
    };

    # System-wide GTK defaults. A user ~/.config/gtk-3.0/settings.ini -- which
    # is exactly what lxappearance writes -- overrides all of this.
    environment.etc."xdg/gtk-3.0/settings.ini".text = ''
      [Settings]
      gtk-theme-name=Arc-Dark
      gtk-icon-theme-name=Papirus-Dark
      gtk-cursor-theme-name=Adwaita
      gtk-font-name=Noto Sans CJK JP 11
      gtk-application-prefer-dark-theme=1
      gtk-xft-antialias=1
      gtk-xft-hinting=1
      gtk-xft-hintstyle=hintmedium
    '';

    # Fonts: Iosevka Nerd Font everywhere in the configs; Noto Sans is the
    # GTK interface font above; Noto CJK covers the Japanese tag glyphs and
    # status text; emoji for notifications.
    # Noto Sans CJK JP is the interface font: it covers Latin and Japanese in
    # one family, which a Japanese-first desktop needs everywhere, not just in
    # the tag names.
    fonts.packages = with pkgs; [
      nerd-fonts.iosevka
      # nerd-icons.el -- the icons in Doom's modeline, dashboard and dired --
      # looks up the family "Symbols Nerd Font Mono" by that exact name. A
      # patched Iosevka does not answer to it: nerd-fonts.iosevka installs
      # "Iosevka Nerd Font", so `doom doctor' reported the symbols font
      # missing and every icon fell back to tofu.
      nerd-fonts.symbols-only
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
    ];
    fonts.fontconfig.defaultFonts = {
      monospace = [
        "Iosevka Nerd Font Mono"
        "Noto Sans Mono CJK JP"
      ];
      sansSerif = [ "Noto Sans CJK JP" ];
      serif = [ "Noto Serif CJK JP" ];
      emoji = [ "Noto Color Emoji" ];
    };

    # Backlight access for the video/input groups (brightnessctl +
    # brightness-notify). Add your user to those groups!
    services.udev.extraRules = backlightUdevRules;

    # CPU profile switching for dmenu-cpupower (Super+p).
    services.power-profiles-daemon.enable = lib.mkDefault true;

    # Bluetooth stack (pairing tools: bluetoothctl, bluetuith,
    # blueman-manager). services.blueman is what registers
    # blueman-mechanism, the privileged half; blueman as a bare package --
    # which is what this module used to install -- has no way to pair or
    # trust a device. The service brings its own copy, so blueman is no
    # longer in the package list above.
    hardware.bluetooth.enable = lib.mkDefault true;
    services.blueman.enable = lib.mkDefault true;

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
