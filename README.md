# suckless-environment

A minimal Wayland desktop — **dwl** + **foot** + **wmenu** + a small suite of
C utilities — built declaratively for **GNU Guix**.

This is the Wayland port of the X11 dwm/st/dmenu/slstatus setup on the
`origin/artix` branch, and it aims at parity with it: the same Tokyo Night
palette, the same Iosevka face, the same 一二三 tags, the same keybindings,
the same status line.

| Role | Tool |
|------|------|
| Compositor | **dwl** 0.8, patched (`bar`, `snail`, `dwindle`) |
| Status bar | dwl's bar from the `bar` patch, fed by `dwl-status` |
| Terminal | **foot** |
| Menus | **wmenu**, reached through a `dmenu(1)` shim |
| Editor | **Doom Emacs** on `emacs-pgtk` (native Wayland) |
| Clipboard | wl-clipboard + `dmenu-clipd` / `dmenu-clip` |
| Screenshot | grim + slurp → `wl-copy` |
| Lock / idle | swaylock + swayidle |
| Wallpaper | swaybg |
| Notifications | dunst |
| Input method | fcitx5 + anthy |
| Login | greetd + tuigreet |

## Layout

```
Makefile              every guix invocation, with -L . wired up
channels.scm          channel definitions (nonguix, for laptop firmware)
channels-lock.scm     the frozen commits — `make lock`, then commit it

suckless/packages.scm what this repo builds: suckless-dwl, suckless-utils, dwl-session
suckless/desktop.scm  the whole desktop: packages + services + the OS builder
hosts/laptop.scm      the real machine — hardware facts only
hosts/vm.scm          the disposable test VM
home.scm              guix home: shell, audio, ~/.config seeds

dwl/config.h          compositor configuration (needs dwl/patches/)
dwl/patches/          bar + snail + dwindle, in that order — see its README
dwl/dwl-session       the one session launcher, for greetd AND for a TTY
dwl/dwl-status        the status line piped into dwl's bar
utils/                the C utilities and the dmenu→wmenu shim
doom/                 $DOOMDIR: init.el, config.el, packages.el
bash/ dunst/ fcitx5/ foot/    configuration deployed by home.scm
```

Hosts are chosen by **file**, never by editing a line in a shared config.

## Usage

```bash
cp channels.scm ~/.config/guix/channels.scm && guix pull
make lock            # freeze the channel commits; commit channels-lock.scm

make check           # type/service check both hosts — changes nothing
make vm              # boot the real desktop in QEMU; log in as you / test
make home            # apply the user configuration
make laptop          # reconfigure this machine (runs make check-laptop first)
```

`make help` lists the rest. **Nothing that fails `make check` should ever
reach `make laptop`.**

Machine-specific state — wallpaper, extra outputs, pointer warp — belongs in
`~/.config/suckless/autostart.sh`, which `dwl-session` sources. The monitor
*layout* is declarative, in `dwl/config.h`'s `monrules`.

## Doom Emacs

`doom/` holds `init.el`, `config.el` and `packages.el` — a byte-for-byte copy
of `~/.config/doom` on the reference machine, and the whole of `$DOOMDIR`
there. `make home` deploys them to `~/.config/doom`, so the configuration is
identical by construction.

Doom's *framework* is a git checkout and stays imperative. After `make home`:

```bash
git clone https://github.com/doomemacs/core ~/.config/emacs
~/.config/emacs/bin/doom install
~/.config/emacs/bin/doom doctor      # should be quieter than on Artix
```

That remote is the one the reference machine tracks. `make home` puts
`~/.config/emacs/bin` on `PATH`, and `EDITOR` is `emacsclient -a emacs`.

Every system dependency `doom doctor` reports, and every binary an enabled
module actually uses on the reference machine, is installed by
`suckless/desktop.scm`: git, ripgrep, **fd**, cmake + libtool + gcc-toolchain
(`:term vterm`), poppler + autoconf + automake (`:tools pdf`), tmux, gnupg,
sqlite, python, rust + rust-analyzer, clang (clangd), and
**Symbols Nerd Font Mono**. The two in bold are *missing* on Artix today —
`doom doctor` complains about both — so this is a small upgrade, not a
regression.

Three deliberate version deltas:

| | reference machine | Guix | consequence |
|---|---|---|---|
| Emacs | 31.1 | `emacs-pgtk` 30.2 | `doom doctor` calls 31.1 an unsupported development build, so 30.2 is the safer of the two. Swap in `emacs-next-pgtk` (31.0.91) if you want to stay on 31. |
| Zig | 0.16.0 | 0.11.0 | five breaking releases apart, and `zig-zls` 0.15 matches neither — **not installed**; get it from ziglang.org (its releases are static and run fine on Guix) |
| Node | 26.7.0 | 10.24.1 | **not installed**; use a `guix shell` with a newer channel, or an upstream build |

Rust is the exception that *must* come from Guix: the rustup toolchain in
`~/.cargo` is prebuilt against `/lib64/ld-linux`, which does not exist on Guix.

**Editing:** `~/.config/doom/*.el` are symlinks into the store, so editing them
in place fails. Edit `doom/` in this repository and re-run `make home`. That is
what makes the configuration reproducible; if it gets in the way, swap the
service in `home.scm` for a seed-if-absent activation.


## Keybindings

MODKEY is **Super**. These mirror `origin/artix:dwm/config.h` one for one.

| Key | Action |
|-----|--------|
| `Super+d` / `Super+Return` | `wmenu-run` / `foot` |
| `Super+e` / `Super+Shift+b` | Thunar / Brave |
| `Super+v` / `Super+p` | clipboard history / CPU profile |
| `Super+j` `Super+k` | focus down / up in the stack |
| `Super+i` | more windows in the master area |
| `Super+h` `Super+l` | shrink / grow the master area |
| `Super+z` | zoom to master |
| `Super+b` | toggle the bar |
| `Super+q` | close window |
| `Super+t` `Super+f` `Super+m` `Super+r` `Super+Shift+r` | Spiral / Title / Float / Monocle / Dwindle |
| `Super+space` / `Super+Shift+space` | cycle layout / toggle floating |
| `Super+[1-9]` | view tag (`Ctrl` toggles, `Shift` sends the window) |
| `Super+0` / `Super+Shift+0` | view / tag all |
| `Super+,` `Super+.` | focus the output left / right (`Shift` sends) |
| `Super+Tab` | last tag |
| `Print` | region screenshot → clipboard |
| `Ctrl+Alt+Delete` | session menu (lock / logout / reboot / shutdown) |
| `Super+Shift+q` | quit dwl |
| Brightness / Volume keys | `brightness-notify`, `pactl` |

## Utilities (`utils/`)

Plain POSIX C, no display-server dependency, one `config.h` each.

- **battery-notify** — low/critical battery notifications, on a 30 s tick
- **brightness-notify** — brightnessctl plus an OSD notification
- **dmenu-clipd** — clipboard daemon watching `wl-paste --watch`, LRU-bounded
- **dmenu-clip** — browse and restore clipboard history
- **dmenu-cpupower** — CPU governor selector, via `cpupower`
- **dmenu-session** — lock / logout / reboot / shutdown, via `swaylock`
- **dmenu-shim** — installed as `dmenu`, translates the X11-era dmenu command
  line into `wmenu`, which is why none of the above needed a Wayland rewrite

`make -C utils test` runs the suite.

## Differences from the X11 setup

Honest list; see `CLAUDE.md` for the reasoning.

- **The status line is monochrome.** The `bar` patch draws it with a single
  colour scheme and no dwl patch implements dwm's status2d `^c#rrggbb^`
  escapes. Glyphs, order and the 年月日 date are identical.
- **No system tray.** Wayland has no XEmbed.
- **Japanese input is Anthy, not Mozc** — mozc is not packaged in Guix.
- **`wmenu-run` lists executables**, where `dmenu_run_desktop` listed
  applications.
- **CPU profiles go through `cpupower`**, since Guix has no
  power-profiles-daemon.
- **Zig and Node are not installed** — Guix's versions are far behind the ones
  in use. See the Doom Emacs section.
- **The 180 Hz mode on DP-1 is not declarable.** dwl picks each output's
  preferred mode; a refresh rate would need the `monitorconfig` patch.

## Contributing

`CLAUDE.md` holds the project context: the reference machine, the parity
matrix, verified defects and the validation workflow.

## License

See the LICENSE files in each subdirectory.
