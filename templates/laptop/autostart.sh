#!/usr/bin/env bash
#
# ~/.config/suckless/autostart.sh — machine-specific session setup.
#
# Installed into the user's home by the `suckless-autostart' activation
# script in configuration.nix, so the layout is declarative even though the
# file itself lives in $HOME. Edit THIS file, not the copy in ~/.config:
# that one is overwritten on every switch.
#
# Sourced by the dwm launcher after the wallpaper is painted and before the
# window manager starts, so anything here can override the wallpaper too.
#
# Nothing below is required. An empty file is a valid answer.

# --- Monitors ---
#   eDP-1 1920x1080@60  at 0,0     (internal)
#   DP-1  1920x1080@180 at 1920,0  (external, PRIMARY)
#
# `xrandr --query' with the cable plugged in tells you the real names,
# modes and refresh rates; `arandr' (installed) draws it with a mouse and
# prints the xrandr line to paste here.
#
# The guard is what makes one file work in both places: with no external
# monitor attached, the internal layout is left exactly as X set it up.
if xrandr --query | grep -q '^DP-1 connected'; then
  xrandr --output eDP-1 --mode 1920x1080 --rate 60 --pos 0x0 \
         --output DP-1 --primary --mode 1920x1080 --rate 180 --pos 1920x0
  # Pointer to the centre of the primary (right-hand) monitor, so the first
  # dmenu and the first window land where you are looking.
  xdotool mousemove 2880 540
fi
