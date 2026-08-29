# Testing the Suckless Guix Configuration in a VirtualBox VM

The declarative Guix config in `guix/` (a real desktop) can be validated in a
VirtualBox VM before touching the laptop — without installing Guix locally.
This is the fastest way to compile-check `guix/system.scm`, `suckless/packages.scm`
and `guix/home.scm` and to smoke-test the dwl/greetd desktop.

## Why a VM

- **No local Guix binary**: Guix is not installed on this repo's host machines,
  so the `.scm` files cannot be compiled locally. A VM gives a real Guix System
  to run `guix system reconfigure`.
- **Blast radius**: the config touches the bootloader, fstab (by UUID), and
  display manager. Testing in a VM keeps the laptop's boot partition safe.
- **Reproducibility**: the VM is the ground truth that the `.scm` files are
  syntactically valid and bootable.

## Prerequisites

- VirtualBox 7.x with the Extension Pack (for shared folders / USB, optional).
- The **base GNU Guix System ISO** (not the graphical installer; the base ISO
  boots to a console and gives a manual install path closest to a reconfigure).

## 1. Create the VM

| Setting        | Value                                        |
|----------------|----------------------------------------------|
| Type           | Linux / Arch Linux (64-bit)                  |
| Base memory    | 4096 MB                                      |
| CPUs           | 2                                            |
| Video memory   | 64 MB (VMSVGA or VBoxSVGA)                   |
| Virtual disk   | 30 GB VDI (dynamic)                          |

CPU acceleration is required for a usable experience (enable VT-x/AMD-V in the
System → Acceleration tab). EFI is fine, but the config targets GRUB with the
provided UUIDs.

## 2. Install Guix System (mirrors the real install plan)

Boot the base ISO and follow the manual install:

1. Partition: a single root partition (`/dev/sda1`) as ext4 (or a separate
   `/boot/efi` if using EFI). Note the partition's file-system UUID:
   ```bash
   blkid   # record the UUID of your root partition
   ```
2. Mount and create the OS:
   ```bash
   mount /dev/sda1 /mnt
   mkdir -p /mnt/etc
   vi /mnt/etc/config.scm   # see below
   guix system init /mnt/etc/config.scm /mnt && reboot
   ```

For the VM, use a **minimal** `/mnt/etc/config.scm` targeted at the `vm` host
(no laptop-specific udev/backlight, slimmer file systems). You can extract the
`operating-system` for the VM host from `guix/system.scm` in this repo and point
its traceability/file-system targets at the VM partition UUID.

## 3. Apply this repo's config

After the VM boots to a console, `guix/system.scm` must be pointed at the VM
host first. Edit its **last line** (the "which host to build" block) and switch
`%suckless-laptop` to `%suckless-vm` — `guix system reconfigure` and
`guix system vm` both build whatever that final value is.

```bash
# 1. Get the repo (needs network — set up DHCP first)
ip link set <iface> up
dhcpcd
git clone <this-repo-url> suckless-environment
cd suckless-environment

# 2. Point the config at the VM host (last line of guix/system.scm):
#      %suckless-laptop  ->  %suckless-vm

# 3. Pull channels (Nonguix) — optional for the free-only core
cp guix/channels.scm ~/.config/guix/channels.scm
guix pull

# 4. Reconfigure the system (compiles system.scm + packages.scm; desktop)
sudo guix system reconfigure guix/system.scm

# 5. Reconfigure home (checks home.scm + seeds)
guix home reconfigure guix/home.scm

# 6. Build the suckless C utils into ~/.local (dmenu->wmenu shim included)
make -C utils install PREFIX="$HOME/.local"
```

To build an ephemeral QEMU VM image instead of installing, run
`guix system vm guix/system.scm` (again after flipping the final value); it
emits a script that boots the configured OS in QEMU.

## 4. What to verify

- **Reconfigure succeeds**: `guix system reconfigure` compiles
  `suckless/packages.scm` and `guix/system.scm`. Any unknown package/service/field
  name fails here, so it is the primary syntax gate.
- **Boots to a greeter**: `greetd` runs the `tuigreet` console greeter on
  tty1 (no X server). Logging in launches the dwl session via `dwl-session`.
- **dwl session starts**: dwl + the status bar (piped into dwl's stdin) and the
  session daemons (dunst, fcitx5, pipewire, dmenu-clipd) launch via
  `dwl-session`. `foot` opens from the terminal keybind.
- **Wayland end-to-end**: `wl-copy/wl-paste` clipboard works, `wmenu` driven
  menus open, and the Print key takes a `grim`/`slurp` screenshot into the
  clipboard. `swaylock` locks on idle.
- **PipeWire audio**: `pw-cli info` reports the pulse + ALSA implementations.
- **Input method**: fcitx5 config and IM env vars are exported; a GUI app shows
  the fcitx toolbar.
- **Keys**: brightness/screenshot notifiers and dmenu-* (wmenu-backed) bindings
  work with the VM's virtual backlight/display as available.

## 5. Iterating

Reconfigure is incremental — after editing any `.scm` file, rerun:

```bash
sudo guix system reconfigure guix/system.scm   # after editing system.scm/packages.scm
guix home reconfigure guix/home.scm            # after editing home.scm
```

Snapshot the VM before the first reconfigure so you can roll back a broken
boot with a single restore.

## 6. When the VM is green

The same flow applies to the laptop, with these deltas handled by
`guix/system.scm`'s laptop host:

- real partition UUIDs (nvme) instead of the VM's `sda`
- `intel_backlight` udev rules and Intel WiFi/BT (wireless-tools, firmware)
- grub targetting the real EFI partition

The VM validates structure and syntax; only hardware-specific bits (backlight,
WiFi firmware) can't be exercised there.
