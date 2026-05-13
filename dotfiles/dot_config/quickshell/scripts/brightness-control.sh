#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

action=${1:-}

case "$action" in
    up)
        brightnessctl set +5% 2>/dev/null
        ;;
    down)
        brightnessctl set 5%- 2>/dev/null
        ;;
esac

status=$(sh "$HOME/.config/quickshell/scripts/launcher-status.sh" 2>/dev/null)
brightness=$(printf '%s\n' "$status" | awk -F= '$1 == "BRI" { print $2; exit }')

if [ -z "$brightness" ]; then
    brightness=0
fi

qs ipc call osd showBrightness "$brightness" >/dev/null 2>&1 || true
