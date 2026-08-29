# CLAUDE.md — project context

Working context for AI assistants and contributors on the **`guix-wayland`** branch.
Read this before touching anything under `guix/`, `suckless/` or `dwl/`.

---

## 1. What this project is

A personal, declarative **suckless desktop**, maintained as one repo with one
branch per platform:

| Branch         | Platform                | WM / session            | Status |
|----------------|-------------------------|-------------------------|--------|
| `main`         | generic Arch-ish        | dwm + st + dmenu (X11)  | legacy |
| `origin/artix` | **Artix (the machine below)** | dwm + st + dmenu (X11) | **RUNNING TODAY — the reference** |
| `nixos`        | NixOS                   | dwm + st + dmenu (X11)  | **the architecture we like** |
| `guix`         | Guix                    | dwm + st + dmenu (X11)  | superseded |
| `guix-wayland` | **GNU Guix**            | **dwl + foot (Wayland)**| **active work — this branch** |

Goal of `guix-wayland`: reproduce the Artix/X11 desktop **exactly**, on
**GNU Guix + Wayland (dwl)**, with the **file layout and ergonomics of the
`nixos` branch**, plus a **one-command VM** to test it without touching the
laptop.

Two non-negotiables from the owner:

* **Emacs (Doom) is the editor.** No Neovim, no Helix, no Yazi anywhere in the
  final config. `EDITOR` must not be `hx`.
* **Beautiful and minimal**, in the sense the `nixos` branch achieved: few
  files, one obvious entrypoint per concern, no duplicated package lists, no
  "edit this line to switch host".

---

## 2. The reference machine (parity ground truth)

Read from the live host on 2026-08-29. **Every parity claim must be checked
against this**, not against the README.

```
Host        artix-btw — Artix Linux, OpenRC, kernel 6.18-lts
CPU         Intel i5-1135G7 (TigerLake, 8 threads)
RAM         16 GiB
GPU         Intel Iris Xe (00:02.0) — modesetting / iHD VA-API
Disk        nvme0n1  p1 vfat ESP  D5A8-D954            -> /boot/efi
                     p2 swap SWAP 4697d7c2-e298-4e46-b97d-197fd4a96039
                     p3 ext4 ROOT 6852d602-61ce-43fb-9c28-91ecf89adccc -> /
            sda1 ext4 HD d530a687-…  (external, holds this repo)
Battery     BAT1 (+ADP1)        Backlight  intel_backlight
Net         wlan0 (Intel), eth0
Displays    eDP-1  1920x1080@60   at 0x0
            DP-1   1920x1080@180  at 1920x0  ← primary
Keyboard    br / abnt2
```

### Live X11 session (`~/.local/bin/dwm-start`, `~/.xprofile`)

```
setxkbmap -layout br -variant abnt2
xrandr eDP-1 1920x1080@60 +0+0 ; DP-1 --primary 1920x1080@180 +1920+0
xdotool mousemove 2880 540              # focus starts on DP-1
polkit-gnome-authentication-agent-1 &
fcitx5 -d                               # + mozc (Japanese)
dmenu-clipd & dunst &
pipewire & pipewire-pulse & wireplumber &
while :; do battery-notify; sleep 30; done &
while :; do slstatus;       sleep 1;  done &   # bar supervisor
flameshot &
feh --no-fehbg --bg-fill ~/wallpapers/sushi_original.png &
exec dwm
```

Display manager: **Ly**. Compositor: **picom**. Lock: **betterlockscreen**.
CPU profiles: **power-profiles-daemon**. Browser: **brave** (native package).
Editor: **Doom Emacs** (`~/.config/doom`, mirrored at
`~/.config/suckless-environment/doom`).

### Live dwm look (`origin/artix:dwm/config.h`)

* Font **`Iosevka Nerd Font:size=14`** (bar *and* dmenu)
* Tags **`一 二 三 四 五 六 七 八 九`**
* Tokyo Night: bg `#1a1b26` · fg `#a9b1d6` · border `#414868` · sel `#7aa2f7`
* Patches: **status2d + systray**, attachaside, alwayscenter, restartsig,
  **fibonacci** (spiral + dwindle)
* Layouts, in `layouts[]` order: `Spiral`, `Title`(tile), `Float`, `Monocle`,
  `Dwindle`
* Keys that the Wayland port currently gets **wrong or drops**:
  `Super+t`→Spiral, `Super+f`→Tile, `Super+m`→Float, `Super+r`→Monocle,
  `Super+Shift+r`→Dwindle, `Super+b`→togglebar, `Super+q`→killclient,
  `Print`→`flameshot gui`

---

## 3. Target stack (this branch)

| Role | X11 (live) | Wayland (target) | Guix package | Verified |
|------|-----------|------------------|--------------|----------|
| Compositor | dwm | **dwl** | `dwl` **0.8** | ✅ exists |
| Terminal | st | **foot** | `foot` | ✅ |
| Menu | dmenu | **wmenu** (+ `dmenu` shim) | `wmenu` **0.2.0** | ✅ exists |
| Bar | slstatus + status2d + systray | **dwl `bar` patch** | built from source | ✅ verified, §5.1 |
| Screenshot | flameshot | grim + slurp + wl-copy | `grim`,`slurp` | ✅ |
| Clipboard | xclip/xsel | wl-clipboard | `wl-clipboard` | ✅ |
| Lock | betterlockscreen | swaylock | `swaylock` | ✅ |
| Idle | — | swayidle | `swayidle` | ✅ |
| Wallpaper | feh | swaybg | `swaybg` | ✅ |
| Monitors | xrandr | wlr-randr | `wlr-randr` | ✅ |
| Compositing | picom | native (dwl) | — | n/a |
| Systray | dwm systray patch | **no equivalent** | — | ❌ Wayland has no XEmbed tray |
| DM | Ly | greetd + tuigreet | `tuigreet` **0.9.1** | ✅ |
| CPU profiles | power-profiles-daemon | cpupower | `cpupower` **7.1.10** | ✅ (**no** `power-profiles-daemon` in Guix) |
| Fonts | Iosevka Nerd Font | `font-iosevka` **33.3.0** + `font-nerd-symbols` **3.4.0**, or `font-nerd-jetbrains-mono` **3.4.0** | | ✅ (no `font-nerd-iosevka`) |
| Editor | Doom Emacs | **Doom Emacs** (`emacs-pgtk` for native Wayland) | | to decide |

The six C utilities in `utils/` are **display-server agnostic** already
(`dmenu-clipd` uses `wl-paste --watch`; `dmenu-session` defaults to
`swaylock`; `dmenu-cpupower` has a `USE_CPUPOWER` switch). They reach a menu
through `utils/dmenu-shim/dmenu`, a `dmenu(1)`-CLI → `wmenu` translator
installed as `$PREFIX/bin/dmenu`. **Keep that design** — it is why no C code
needed a Wayland rewrite.

---

## 4. Why this branch keeps failing

`git log` on this branch is a chain of single-error fixes:

```
fix: drop missing (gnu packages bluetooth) import
fix: drop missing (gnu packages sound) import
fix: drop missing (gnu packages desktop) and (gnu services bluetooth)
fix: make (suckless packages) loadable without -L
refactor: split guix/system.scm into hosts + services
revert: keep simple single-file system.scm, undo split that broke reconfigure
fix: cpupower not linux-tools on guix-btw
fix: remove xwayland unbound variable on guix-btw
fix: make package list resilient to channel renames
fix: use /dev/sda* for VM, avoid uuid invalid on guix-btw
```

**Root cause: there is no local feedback loop.** Guix is not installed on the
Artix host (`no /gnu`, `no /var/guix`, no `qemu`), so the only way to learn
that a symbol is unbound is to copy the repo into the VirtualBox VM
(`3-Resources/VirtualMachines/Guix`, hostname `guix-btw`) and run
`guix system reconfigure`, which surfaces **one** error per round trip.
Everything else in this file follows from that.

The second-order damage: to stop the bleeding, `guix/system.scm` grew

```scheme
(define (try-spec spec) (catch #t (lambda () (specification->package spec))
                                  (lambda _ #f)))
```

which **silently drops any package Guix cannot resolve**. A typo or a rename
no longer fails the build — it produces a desktop that is missing `foot`, or
missing the Nerd font, with no error anywhere. This must go.

---

## 5. Verified defects (as of `1bd55f5`)

### 5.1 There is no status bar. At all. ❗
Upstream dwl **deliberately ships no bar** — it is an explicit non-goal. dwl
writes tag/layout/title state to the **stdin of its `-s` command**. The
current session does the opposite:

```scheme
(execl "/bin/sh" "/bin/sh" "-c" "dwl-status | dwl")   ; guix/system.scm:118
```

That pipes `dwl-status.sh` into dwl's stdin, which stock dwl never reads. So
`dwl/dwl-status.sh` runs, produces text, and nothing displays it. The
README's "Status bar | dwl's built-in bar, fed by `dwl-status`" is false.

`dwl-status | dwl` **is** correct — *but only with the `bar` patch* from
`dwl/dwl-patches` applied. Neither `somebar` nor `dwlb` is packaged in Guix.
**Settled: apply the patch** (§9.2). Vendored at `dwl/patches/bar.patch`
(main, 2026-01-05) and `dwl/patches/bar-0.7.patch`.

The patch is *"a bar identical to dwm's bar"* and restores, one for one, the
things the Wayland port lost:

| dwm (live) | after the `bar` patch |
|---|---|
| `static const char *fonts[]` | `static const char *fonts[]` — set to `Iosevka Nerd Font:size=14` |
| `colors[][3]` / `SchemeNorm` `SchemeSel` | `uint32_t colors[][3]` / `SchemeNorm` `SchemeSel` `SchemeUrg` |
| `tags[] = { "一", … }` | `static char *tags[]` — **strings again**, so the kanji tags come back |
| `showbar` / `topbar` / `Super+b` togglebar | `showbar` / `topbar` / `Super+b` togglebar |
| `ClkLtSymbol`/`ClkTagBar`/`ClkStatusText` buttons | `ClkLtSymbol`/`ClkTagBar`/`ClkStatus`/`ClkTitle`/`ClkClient` |

Two consequences:

* **Build inputs**: the patch needs `fcft` (**3.3.3**, pulls `tllist`) and
  `pixman` (**0.46.4**) — both in Guix, and `foot` already depends on `fcft`.
* **`dwl/config.h` must be rewritten from the patched `config.def.h`.** The
  patch replaces `#define TAGCOUNT (9)` with `static char *tags[]` and changes
  the `Button` struct, so the vendored config cannot survive as-is. The
  upstream README states this explicitly.

Version risk: the patch ships as `bar.patch` (tracks dwl **main**),
`bar-0.7.patch` and `bar-0.6.patch` — there is **no `bar-0.8.patch`**, and
Guix ships dwl **0.8**. Which of the two applies must be tested. The vendored
`dwl/config.h` is also stale independently: it lacks `rootcolor`, which dwl
has had since 0.7, so it was written against roughly dwl 0.5.

### 5.2 `guix/home.scm` cannot evaluate ❗
`home-environment` has fields `packages`, `services`, `essential-services` —
**there is no `files` field**. Lines 92–102 must become a service:

```scheme
(service home-xdg-configuration-files-service-type
         `(("foot/foot.ini" ,(local-file "../foot/foot.ini"))
           ("dunst/dunstrc" ,(local-file "../dunst/dunstrc"))))
```

### 5.3 greetd collides with mingetty on tty1 ❗
`greetd-terminal-configuration (terminal-vt "1")` + unmodified
`%base-services` = two services fighting for tty1. The Guix manual requires:

```scheme
(modify-services %base-services
  (delete login-service-type)
  (delete mingetty-service-type))
```

`guix/system.scm:362` has a bare `(modify-services %base-services)` — a no-op.

### 5.4 The greetd session starts no daemons ❗
`dwl-start` (manual path) launches lxpolkit, fcitx5, `dmenu-clipd`, dunst,
pipewire, the battery loop and swayidle. `dwl-session` (the **only** path
greetd uses) launches **none of them** — it sources `autostart.sh` and execs
`dwl-status | dwl`. Logging in through the greeter therefore gives no
notifications, no clipboard history, no input method, no polkit agent, no
idle lock. Worse: **nothing in the Guix config installs `dwl-start` anywhere**,
so the manual path does not exist on a Guix machine either.

### 5.5 dwl never gets the br/abnt2 layout ❗
`operating-system.keyboard-layout` configures the console and GRUB, **not** a
Wayland compositor, and there is no `setxkbmap` under Wayland. The vendored
`config.h` set every `xkb_rule_names` field to `NULL`, so dwl fell back to `us`.

Two separate mistakes, both verified against `/usr/share/X11/xkb/rules/base.lst`
on the live host:

* **`abnt2` is an xkb MODEL, not a layout variant and not an option.** It is
  listed under `! model`; `br` has no `abnt2` variant. So `.variant = "abnt2"`
  (and the live machine's `setxkbmap -variant abnt2`) silently degrades to
  plain `br`, and `system.scm`'s `(keyboard-layout "br" #:options '("abnt2"))`
  is wrong twice over. Correct: `#:model "abnt2"`.
* **The shifted number row is not the US one.** `xmodmap -pke` on the live
  keyboard gives `keycode 15 = 6 dead_diaeresis` — Shift+6 is `¨`, not `^`.
  dwl matches on the *translated* keysym, so `TAGKEYS(XKB_KEY_6,
  XKB_KEY_asciicircum, 5)` meant **Super+Shift+6 did nothing**: no window
  could be sent to tag 6. Every other digit does match US. Letter case is
  irrelevant — `keybinding()` compares through `xkb_keysym_to_lower`.

### 5.6 Probable service-graph errors (confirm locally)
* `elogind-service-type` extends `polkit-service-type`; `polkit-service-type`
  is **never instantiated** → likely `missing-target-service-error`.
* `supplementary-groups` includes `"realtime"`, which is not in Guix's
  `%base-groups`.
* No `udisks-service-type` (Thunar cannot mount), no `upower-service-type`.
* `swaylock` needs `screen-locker-service-type` (PAM) or it cannot
  authenticate — a lock-out risk on real hardware.
* `fwupd-service-type`, `greetd-terminal-configuration.extra-shepherd-requirement`
  and `greetd-user-session.xdg-session-type` are all unverified field/symbol
  names.

### 5.7 Structural problems
* **Host selection by editing the last line of `system.scm`.** Every VM test
  dirties the working tree. The `nixos` branch solved this with
  `nixosConfigurations.vm`; Guix's equivalent is separate `hosts/*.scm` files.
* **Two disagreeing package lists**: `guix/manifest.scm` (90 lines: neovim,
  vim, tmux, btop, gvfs, polkit-gnome, resvg…) vs
  `%suckless-system-packages` in `system.scm` (helix, librewolf, blueman,
  fonts…). Neither is authoritative.
* `guix/manifest.scm` and `guix/home.scm` still install/seed **helix**, and
  `bash/bashrc` sets `EDITOR=hx` and `alias nv="nvim"` — contradicts the
  Emacs-only requirement.
* `suckless-dwl` overlays `dwl/config.h` onto whatever version Guix ships
  (0.8). The vendored `config.h` was written against an older dwl. **Version
  drift here is a silent, hard-to-debug breakage.** Pin the channel.
* `foot.ini` asks for `JetBrainsMono Nerd Font`, `dunstrc` too, while the
  system installs `font-iosevka` *and* `font-nerd-jetbrains-mono`, and the
  live machine uses `Iosevka Nerd Font`. Three different answers.

---

## 6. The architecture to copy (`nixos` branch)

What makes that branch pleasant, and the Guix analogue:

| `nixos` | purpose | Guix analogue |
|---------|---------|---------------|
| `nix/lib.nix` | one shared builder for vendored tools | a `mkSuckless`-style helper in `suckless/packages.scm` |
| `nix/packages.nix` | one derivation per vendored tool | `suckless/packages.scm` (already close) |
| `nix/module.nix` | **the whole desktop behind one toggle** | `guix/desktop.scm` — packages + services as two exported values |
| `hosts/laptop.nix` | hardware only | `hosts/laptop.scm` |
| `hosts/vm.nix` | **disposable VM, imports the same module** | `hosts/vm.scm` |
| `flake.nix` `nixosConfigurations.vm` | `nix build .#vm && ./result/bin/run-nixos-vm` | `guix system vm hosts/vm.scm` — **no file editing** |
| `programs.suckless-environment.extraPackages` | personal apps ride along | keyword arg on the OS builder |

Note `hosts/vm.nix` is a **separate file** — testing never touches the laptop
config. That is the property to reproduce.

---

## 7. The local feedback loop (host setup / teardown)

Guix's error classes and where each is caught:

| Error class | Caught by | Cost before this loop existed |
|---|---|---|
| unbound variable, unknown field, bad module import | `guix repl` / `guix system build` | full VM round trip |
| missing package spec | `guix build <name>` | full VM round trip (or silently swallowed) |
| service-graph (`missing-target-service-error`, duplicate shepherd provision) | `guix system build` | full VM round trip |
| boots? greeter? dwl starts? | `guix system vm` | manual VirtualBox install |
| backlight, WiFi firmware, dual monitor, VA-API | real hardware only | — |

The first three are **90% of this branch's commit history** and all are
catchable in seconds once `guix` exists on the Artix host. Guix installs on a
foreign distro as an ordinary package manager (`/gnu/store` + `guix-daemon`);
it does not touch Artix's boot, init or `/usr`.

**This install is temporary — it is development tooling, and the owner wants
it removed once the config is finished. AUR is forbidden; use only the
official GNU script and Artix's own repositories.**

### Setup (needs root — run by the owner)

```bash
# QEMU, from Artix's own world/extra repos (NOT the AUR)
sudo pacman -S --needed qemu-desktop

# Guix 1.5.0, official upstream installer; it detects OpenRC on its own
cd /tmp
curl -sSfL https://git.savannah.gnu.org/cgit/guix.git/plain/etc/guix-install.sh \
     -o guix-install.sh
sudo bash guix-install.sh
```

The installer is interactive:

* *"Permit downloading pre-built package binaries…"* → **yes** (without
  substitutes every package is compiled from source).
* *"Customize users Bash shell prompt for Guix?"* → **NO**. It appends to
  `~/.bashrc` and would clobber the Tokyo Night prompt in `bash/bashrc`.

What it creates: `/gnu`, `/var/guix`, `/etc/guix`, `/var/log/guix`,
`/etc/profile.d/zzz-guix.sh`, `/etc/init.d/guix-daemon` (OpenRC, `rc-update add
… default`), `/usr/local/bin/guix`, shell completions, the `guixbuild` group
and `guixbuilder1..10` users.

Then, as the normal user: `guix pull` (slow, once), and pin the result into
`guix/channels.scm` so the VM and the laptop build byte-identical systems.

### Teardown (when the config is done)

```bash
cd /tmp
curl -sSfL https://git.savannah.gnu.org/cgit/guix.git/plain/etc/guix-install.sh \
     -o guix-install.sh
sudo bash guix-install.sh --uninstall     # built-in, official
sudo pacman -Rns qemu-desktop
```

`--uninstall` removes the daemon + OpenRC service, `/gnu`, `/var/guix`,
`/etc/guix`, `/var/log/guix`, `/etc/profile.d/zzz-guix.sh`, the build users
and group, and the shell completions. It does **not** touch per-user state, so
finish with:

```bash
rm -rf ~/.config/guix ~/.guix-profile ~/.guix-home ~/.cache/guix
```

Verify nothing is left: `ls -d /gnu /var/guix /etc/guix 2>&1`,
`getent group guixbuild`, `rc-update show | grep guix`.

## 8. Conventions

* Comments and docs in **English**; conversation with the owner in
  **Portuguese**.
* Tokyo Night everywhere: `#1a1b26` `#a9b1d6` `#414868` `#7aa2f7` `#565f89`
  `#f7768e` `#9ece6a` `#e0af68` `#bb9af7` `#7dcfff`.
* Machine-specific state (monitor layout, wallpaper, pointer warp) belongs in
  `~/.config/suckless/autostart.sh`, **never** in the declarative config.
  (It does not exist on the live machine yet — `dwm-start` still hardcodes it.)
* `utils/` stays plain POSIX C with per-tool `config.h`; committed `config.h`
  for most, generated from `config.def.h` for `dmenu-session` /
  `dmenu-cpupower` (both gitignored).
* Never `sudo guix system reconfigure` the laptop with a config that has not
  booted in the VM first.

## 9. Decisions (settled 2026-08-29)

1. **Feedback loop** — Guix + QEMU installed on the Artix host, via the
   official installer only (no AUR). **Temporary**: removed via
   `guix-install.sh --uninstall` when the config is finished. See §7.
2. **Bar** — apply the `bar` patch from `dwl/dwl-patches` to our
   `suckless-dwl` package. Built-in bar (drwl), status fed through stdin, so
   `dwl-status | dwl` becomes correct. No external bar daemon. Requires a
   pinned channel so patch and dwl version cannot drift.
3. **Editor** — `emacs-pgtk` (native Wayland, no XWayland) plus Doom's
   dependencies from Guix; `~/.config/doom` versioned in the repo and seeded
   by `guix home`; `doom install` / `doom sync` stay imperative.
   `EDITOR=emacsclient`. **Remove every trace of helix / neovim** from
   `manifest.scm`, `home.scm`, `bash/bashrc` and the `helix/` directory.
4. **Login** — keep greetd + tuigreet, fixed: delete `login-service-type` and
   `mingetty-service-type` from `%base-services`, and make `dwl-session`
   actually start the session daemons (§5.4).

---

## 10. Progress

### Done and verified locally (no Guix needed)

* **Patch stack**, vendored in `dwl/patches/` with a README fixing the order.
  Applied to a pristine dwl 0.8 tarball: `bar.patch` → `snail-0.8.patch` →
  `dwindle.patch`, **zero rejects**, all four layout functions present
  (`tile`, `monocle`, `snail`, `dwindle`), `drwl.h` created, and the Makefile
  gains `pixman-1 fcft` in `PKGS`.
  - `bar-0.7.patch` fails 3 hunks on 0.8 and was dropped.
  - upstream `dwindle.patch` conflicts with `snail`; `dwl/patches/dwindle.patch`
    is a rebase onto bar+snail that touches `dwl.c` only.
* **`dwl/config.h` rewritten** against the patched `config.def.h` and
  cross-checked symbol by symbol against the patched tree: every function,
  enum (`SchemeUrg`, `Clk*`) and struct field order (`Key`, `Rule`,
  `MonitorRule`, `Layout`, `Button`) matches. Restores kanji tags, the dwm
  layout order (Spiral/Title/Float/Monocle/Dwindle on `t f m r Shift+r`),
  `Super+b`, `Super+q` killclient, the ABNT2 model and shifted keysyms, and
  declares the dual-monitor layout in `monrules` instead of shelling out to
  `wlr-randr`.
* **`dwl/dwl-status`** (replaces `dwl-status.sh`): reproduces the X11 bar byte
  for byte. Glyphs decoded from the running `WM_NAME` and confirmed identical —
  U+F4BC cpu, U+EFC5 ram, U+F242 battery, U+F028 volume — plus the `年月日`
  date. Run on the live machine, output matches. Also fixes a real bug: the old
  `cpu()` did `read _ o1 o2 o3 o4 < /proc/stat`, which swallows
  `iowait..guest_nice` into `o4` and makes `$((o4))` an arithmetic error.
* **`dwl/dwl-session`** (replaces `dwl-start`): the single entry point for both
  greetd and TTY login, so §5.4 cannot recur. Starts lxpolkit, fcitx5,
  `dmenu-clipd`, dunst, the battery loop and swayidle idempotently, then
  `exec sh -c 'dwl-status | dwl'`. PipeWire is left to Guix Home's Shepherd
  service. Both scripts pass `sh -n`.
* **Font ground truth** taken from the live machine, not the README:
  st `Iosevka Nerd Font Mono:size=16`, dwm bar/dmenu `Iosevka Nerd Font:size=14`,
  dunst `Iosevka Nerd Font 11`. The repo said `JetBrainsMono Nerd Font 11`
  everywhere. `foot.ini`, `dunstrc` and `config.h` now match, with
  `font-nerd-symbols` + `font-google-noto-sans-cjk` as fallback entries since
  Guix has no Nerd-patched Iosevka.
* **Emacs**: `doom/{init,config,packages}.el` vendored from `~/.config/doom`.
  `bash/bashrc` now sets `EDITOR='emacsclient -a emacs'`, drops the nvim alias,
  and triggers neofetch on `TERM=foot*`. `helix/` and `guix/manifest.scm`
  deleted.

### Known remaining gaps

* **No status2d colours.** The `bar` patch draws `stext` with a single scheme;
  `bar-recolr` is about runtime theme reloading, not `^c#rrggbb^` escapes, and
  nothing else in the collection adds them. `dwl-status` therefore emits plain
  text (escapes would be printed literally). Closing this means writing and
  owning a small `drawbar` patch.
* **No systray.** Wayland has no XEmbed; the dwm systray patch has no analogue.
* **`wmenu-run` lists PATH binaries**, while dwm used `dmenu_run_desktop`
  (desktop-file names). `fuzzel` is the Wayland tool that reads `.desktop`
  files, at the cost of a second launcher to theme.
* **Zig and Node** are five and sixteen major versions behind in Guix
  (0.11.0 vs 0.16.0; 10.24.1 vs 26.7.0) and are deliberately not installed.
* **Refresh rate**: dwl picks each output's preferred mode; DP-1's 180 Hz is
  not expressible in `monrules` without the `monitorconfig` patch.

### Done: the Scheme rewrite

The repository now has the shape of the `nixos` branch. `guix/` is gone.

| file | role | was |
|---|---|---|
| `Makefile` | every `guix` call, `-L .` wired in | (nothing — `flake.nix` had no analogue) |
| `channels.scm` + `channels-lock.scm` | channels, and the pin | `guix/channels.scm`, unpinned |
| `suckless/packages.scm` | `suckless-dwl`, `suckless-utils`, `dwl-session` | same, unpatched dwl |
| `suckless/desktop.scm` | packages + services + `suckless-system` | inside `guix/system.scm` |
| `hosts/{laptop,vm}.scm` | hardware only, one file each | `%suckless-laptop` / `%suckless-vm`, chosen by editing the last line |
| `home.scm` | shell, PipeWire, `~/.config` seeds | `guix/home.scm`, which could not evaluate |
| — | — | `guix/manifest.scm` deleted (second, disagreeing package list) |

What changed substantively:

* **Host by file, not by edit.** `make vm` / `make check-laptop`. No more
  dirty working tree to run a test.
* **`try-spec` is gone.** `specification->package` is called directly, so an
  unknown package name raises instead of silently vanishing. Names are still
  strings, which survives Guix's module churn — the churn that caused six of
  the "fix: drop missing import" commits.
* **Services build on `%desktop-services`** minus `gdm`, `login` and
  `mingetty`. That single change fixes §5.3 (the tty1 collision) and §5.6
  (polkit, udisks, upower were never instantiated) at once, and greetd now
  owns vt1–6.
* **`screen-locker-service-type` for swaylock**, so the lock screen can
  actually authenticate.
* **`udev-rules-service`** extends the existing udev service instead of
  instantiating a second one.
* **`realtime` dropped** from `supplementary-groups` — it is not in Guix's
  `%base-groups` and would fail activation.
* **`keyboard-layout "br" #:model "abnt2"`**, not `#:options`.
* **`home-xdg-configuration-files-service-type`** replaces the `files` field
  that does not exist, and now also seeds `doom/`.
* **`utils` tests run during the build** (`make test`, 11/11 locally).

Checked locally: all six `.scm` files read cleanly under Guile with gexps
desugared (`#~`→`` ` ``, `#$`→`,`), parens balanced. That kills the reader-error
class before the VM; it says nothing about field names.

### Verification round (2026-08-29, before the first VM run)

* **Every package name checked against the real index.** Downloaded
  `guix.gnu.org/packages.json` (27 MB uncompressed, 32 076 packages) and
  matched all 64 specifications. Two defects found and fixed; see item 3
  below. This removes the single largest source of VM round trips.
* **`doom/` is byte-identical** to `~/.config/doom` on the reference machine,
  and that directory holds nothing else — `init.el`, `config.el`,
  `packages.el` is the whole of `$DOOMDIR`.
* **`doom doctor` was run on the reference machine** and its findings drove
  the package list rather than guesswork. It asks for two things the Artix
  install is missing and Guix will provide: the `fd` binary and the
  `Symbols Nerd Font Mono` family (`font-nerd-symbols`, already installed for
  the status line). It also wants `Symbola` as Emacs' last-resort font; Guix
  has no Symbola, so `font-gnu-unifont` fills that role.
* **Enabled Doom modules were read from `init.el`**, not assumed. A previous
  note in this file claimed `:app everywhere` was on and would break under
  Wayland — wrong: the token is the `+everywhere` flag on `:editor evil`.
  emacs-everywhere is not enabled.
* **Doom's actual toolchain use was probed on the live machine** (`command -v`
  over every binary the enabled modules touch) and the package list mirrors
  what is really there: rust + rust-analyzer, clang/clangd, python, tmux,
  gnupg, sqlite. Things absent on Artix (gopls, shellcheck, pyright, black,
  nixfmt, prettier, pandoc) are absent here too — parity, not aspiration.
* **Doom's framework remote is `https://github.com/doomemacs/core`**, not the
  older `doomemacs/doomemacs`; the README documents the bootstrap it needs.
* **Rust must come from Guix.** The reference machine's toolchain lives in
  `~/.cargo` via rustup, and those binaries are linked against
  `/lib64/ld-linux`, which does not exist on Guix.
* All six `.scm` files still read cleanly after the edits.

### What the VM has to adjudicate

In this order — each one is a name or a field that only a real Guix can
confirm. Run `make check-vm` first; it needs no VM boot and catches all of it.

1. **Field names.** `greetd-user-session` is being handed `command` +
   `command-args`; the old file also passed `xdg-session-type` and
   `extra-shepherd-requirement`, which I dropped as unverified. If greetd
   rejects the record, those are the fields to look at.
2. **`modify-services … (delete gdm-service-type)`** — confirm `gdm` is
   actually the type name in `%desktop-services` on this channel.
3. ~~Package names.~~ **Settled.** All 64 names passed to
   `specification->package` were checked against the full Guix package index
   (`guix.gnu.org/packages.json`, 32 076 packages): **0 missing**. Two were
   wrong and are fixed — `p7zip` → `7zip`, and `intel-media-driver`, which is
   not in the main channel at all and now comes from `(nongnu packages video)`
   in `hosts/laptop.scm`. The main channel only carries `intel-vaapi-driver`,
   the i965 driver, which stops at Gen9 and would have done nothing for
   Iris Xe.
4. **Does `suckless-dwl` compile?** `make dwl`. The three patches apply to a
   pristine 0.8 tree (verified), and `dwl/config.h` was cross-checked against
   the patched sources — but only the compiler settles it.
5. **`suckless-utils` tests in the build container.** `dmenu-clip`'s
   integration test shells out to `dmenu`, which is absent there. If it fails,
   `#:tests? #f` is the one-line fix.
6. **Audio.** `%desktop-services` may carry a system PulseAudio that races
   `home-pipewire-service-type`. If sound misbehaves, delete
   `pulseaudio-service-type` in `suckless/desktop.scm`.
7. **Font family names.** `fc-list | grep -i "nerd\|iosevka"` inside the VM:
   `dwl/config.h`, `foot.ini` and `dunstrc` all ask for
   `Symbols Nerd Font Mono`, which is what `font-nerd-symbols` *should*
   install. If the family is named differently, three files need the same
   one-word edit.
8. **Then boot it** — `make vm` — and walk the checklist: tuigreet on vt1,
   the bar with 一二三 and the status line, `Super+d`/`Super+Return`,
   `Super+Shift+6` reaching tag 6, `wl-copy`, `Print`, swaylock.

### Design decisions worth knowing before changing things

* `~/.config/doom` is a **store symlink**, so editing `config.el` in place
  fails; edit `doom/` here and `make home`. This is what "declarative" costs.
  Swap the service for a seed-if-absent activation if it gets in the way.
* `hosts/vm.scm` deliberately does **not** use nonguix, so a broken channel
  can never block testing.
* The Wayland and input-method environment variables live in `dwl-session`,
  not in `~/.profile`: a TTY login is not a Wayland session.
