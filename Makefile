# Suckless Environment — Guix entry points.
#
# This file is the ergonomics layer the nixos branch got from flake.nix:
# every target passes `-L .' so that (suckless packages) and (suckless
# desktop) resolve, and the host is chosen by FILE, never by editing a line.
#
#   make check        type/service check for both hosts, builds nothing extra
#   make vm           boot the desktop in QEMU (from a host with QEMU)
#   make vm-install   reconfigure the machine you are ON as the VM host
#   make home         apply the user configuration
#   make laptop       reconfigure THIS machine (asks for sudo)
#
# Anything that fails `make check' must never reach `make laptop'.

GUIX      ?= guix
LOADPATH  := -L .
LOCK      ?= channels-lock.scm

# Once channels-lock.scm exists, everything runs through the time machine, so
# the VM and the laptop build the same store items.
ifneq ($(wildcard $(LOCK)),)
  GUIXRUN := $(GUIX) time-machine -C $(LOCK) --
else
  GUIXRUN := $(GUIX)
endif

.PHONY: help check check-vm check-laptop vm vm-image vm-install home laptop \
        dwl utils session lock pull clean

help:
	@sed -n 's/^#   //p' $(firstword $(MAKEFILE_LIST))

## --- validation (changes nothing) ------------------------------------
check: check-vm check-laptop

check-vm:
	$(GUIXRUN) system build $(LOADPATH) hosts/vm.scm

check-laptop:
	$(GUIXRUN) system build $(LOADPATH) hosts/laptop.scm

## --- individual packages ---------------------------------------------
dwl:
	$(GUIXRUN) build $(LOADPATH) -e '(@ (suckless packages) suckless-dwl)'

utils:
	$(GUIXRUN) build $(LOADPATH) -e '(@ (suckless packages) suckless-utils)'

session:
	$(GUIXRUN) build $(LOADPATH) -e '(@ (suckless packages) dwl-session)'

## --- the test VM ------------------------------------------------------
# Boots the real configuration in QEMU. Log in as `you' / `test'.
vm:
	$(GUIXRUN) system vm $(LOADPATH) hosts/vm.scm

# A standalone disk image, for VirtualBox and friends.
vm-image:
	$(GUIXRUN) system image --image-type=qcow2 $(LOADPATH) hosts/vm.scm

# Run this INSIDE an existing Guix guest (the VirtualBox `guix-btw' box) to
# turn that guest into the test host.  hosts/vm.scm's file systems already
# match it: sda1 ESP, sda2 swap, sda3 root.
vm-install: check-vm
	sudo -E $(GUIXRUN) system reconfigure $(LOADPATH) hosts/vm.scm

## --- applying ---------------------------------------------------------
home:
	$(GUIXRUN) home reconfigure $(LOADPATH) home.scm

laptop: check-laptop
	sudo -E $(GUIXRUN) system reconfigure $(LOADPATH) hosts/laptop.scm

## --- channels ---------------------------------------------------------
pull:
	$(GUIX) pull -C channels.scm

# Freeze the current channel commits; commit the result.
lock:
	$(GUIX) describe -f channels > $(LOCK)
	@echo "wrote $(LOCK) — commit it"

clean:
	$(MAKE) -C utils clean
	rm -f result
