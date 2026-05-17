#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

action=${1:-}

case "$action" in
    up)
        timeout 2 wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ 2>/dev/null || timeout 2 pactl set-sink-volume @DEFAULT_SINK@ +5% 2>/dev/null
        ;;
    down)
        timeout 2 wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- 2>/dev/null || timeout 2 pactl set-sink-volume @DEFAULT_SINK@ -5% 2>/dev/null
        ;;
    mute)
        timeout 2 wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null || timeout 2 pactl set-sink-mute @DEFAULT_SINK@ toggle 2>/dev/null
        ;;
esac

status=$(sh "$HOME/.config/quickshell/scripts/launcher-status.sh" 2>/dev/null)
volume=$(printf '%s\n' "$status" | awk -F= '$1 == "VOL" { print $2; exit }')
muted=$(printf '%s\n' "$status" | awk -F= '$1 == "VOL_MUTED" { print $2; exit }')

if [ -z "$volume" ]; then
    volume=0
fi

qs ipc call osd showVolume "$volume" "$muted" >/dev/null 2>&1 || true
