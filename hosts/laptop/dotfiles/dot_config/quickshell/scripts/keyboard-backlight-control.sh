#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

led="/sys/class/leds/tpacpi::kbd_backlight"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/keyboard-backlight"
state_file="$state_dir/level"

[ -d "$led" ] || exit 1

max="$(cat "$led/max_brightness" 2>/dev/null || printf '2')"
current="$(cat "$led/brightness" 2>/dev/null || printf '0')"

case "${1:-toggle}" in
    up)
        next=$((current + 1))
        [ "$next" -le "$max" ] || next="$max"
        ;;
    down)
        next=$((current - 1))
        [ "$next" -ge 0 ] || next=0
        ;;
    toggle)
        if [ "$current" -gt 0 ]; then
            next=0
        else
            next="$max"
        fi
        ;;
    set)
        next="${2:-$current}"
        ;;
    status)
        printf '%s\n' "$current"
        exit 0
        ;;
    *)
        echo "Usage: $0 [up|down|toggle|set LEVEL|status]" >&2
        exit 2
        ;;
esac

case "$next" in
    ''|*[!0-9]*)
        echo "Invalid keyboard backlight level: $next" >&2
        exit 2
        ;;
esac

[ "$next" -le "$max" ] || next="$max"

mkdir -p "$state_dir"
printf '%s\n' "$next" > "$state_file"

if [ -w "$led/trigger" ]; then
    printf '%s\n' none > "$led/trigger" 2>/dev/null || true
fi

if [ -w "$led/brightness" ]; then
    printf '%s\n' "$next" > "$led/brightness"
else
    pkexec /usr/local/sbin/keyboard-backlight-helper set "$next" >/dev/null
fi

printf '%s\n' "$next"
