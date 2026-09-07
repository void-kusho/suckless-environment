#!/usr/bin/env bash
#
# ~/.config/suckless/autostart.sh — machine-specific session setup for
# nixos-btw. Persisted declaratively: this file is installed into the user's
# home by the `suckless-autostart' activation script in ./default.nix, so
# edit THIS copy and rebuild — the one in ~/.config is overwritten.
#
# Sourced by the dwm launcher after the wallpaper is painted, before the
# window manager starts. Anything here is this machine's state, which is why
# it belongs to the host and never to nix/module.nix.

# --- Monitors (reference layout) ---
#   eDP-1 1920x1080@60  at 0,0     (internal)
#   DP-1  1920x1080@180 at 1920,0  (external, PRIMARY)
#
# The guard keeps the internal monitor layout intact on laptop-only
# sessions, when no DP-1 cable is attached.
if xrandr --query | grep -q '^DP-1 connected'; then
  xrandr --output eDP-1 --mode 1920x1080 --rate 60 --pos 0x0 \
         --output DP-1 --primary --mode 1920x1080 --rate 180 --pos 1920x0
  # Pointer to the center of the primary (right) monitor.
  xdotool mousemove 2880 540
fi