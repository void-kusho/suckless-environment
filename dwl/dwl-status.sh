#!/bin/sh
# dwl-status.sh — status bar for dwl
#
# dwl reads status text from the stdin of the compositor process.  This
# script is piped into dwl by dwl-session; every line it prints becomes the
# bar content (last line wins).  We loop producing updates on an interval,
# mirroring the data slstatus exposed: battery, volume, cpu, memory, wifi,
# date & time.
#
# Keep it lightweight (plain text; dwl's stock bar has no pango colours).

INTERVAL=1

# battery (percent) — /sys/class/power_supply/BAT*
battery() {
    local bat dir
    for dir in /sys/class/power_supply/BAT*; do
        [ -d "$dir" ] || continue
        bat=$(cat "$dir/capacity" 2>/dev/null)
        [ -n "$bat" ] && echo "${bat}%"
        return
    done
}

# cpu usage percent (delta of /proc/stat jiffies)
cpu() {
    local i1 i2 i3 i4 o1 o2 o3 o4 d1 d2 idle1 idle2
    read -r _ o1 o2 o3 o4 < /proc/stat
    sleep 0.2
    read -r _ i1 i2 i3 i4 < /proc/stat
    idle1=$((o4)); idle2=$((i4))
    d1=$((o1+o2+o3+o4)); d2=$((i1+i2+i3+i4))
    echo $(( (100 * ((d2 - idle2) - (d1 - idle1))) / (d2 - d1) ))
}

# memory used percent
mem() {
    local total avail used
    total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
    avail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
    [ -n "$total" ] && [ -n "$avail" ] && echo $(( 100 * (total - avail) / total ))
}

# wifi signal percent — best-effort via /proc/net/wireless
wifi() {
    awk 'NR==3 { printf "%d%%", $3 }' /proc/net/wireless 2>/dev/null
}

# volume percent via pactl
volume() {
    pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null \
        | awk -F'/' '/Volume:/{gsub(/[ \%]/, "", $2); print $2"%"}'
}

while true; do
    line=""
    b=$(battery);  [ -n "$b" ]   && line="$line  ﮤ $b"
    c=$(cpu);      [ -n "$c" ]   && line="$line   $c%"
    m=$(mem);      [ -n "$m" ]   && line="$line   $m%"
    v=$(volume);   [ -n "$v" ]   && line="$line   $v"
    w=$(wifi);     [ -n "$w" ]   && line="$line   $w"
    line="$line  $(date '+%a %b %d  %H:%M')"

    printf '%s\n' "$line"
    sleep "$INTERVAL"
done
