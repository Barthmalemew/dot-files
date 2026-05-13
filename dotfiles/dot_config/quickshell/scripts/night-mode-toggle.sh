#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

temperature="${NIGHT_MODE_TEMP:-3900}"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
state_file="$runtime_dir/quickshell-night-mode"
pid_file="$runtime_dir/quickshell-night-mode.pid"

notify() {
    qs ipc call osd showNightMode "$1" >/dev/null 2>&1 || true
}

if ! command -v gammastep >/dev/null 2>&1; then
    notify "missing"
    exit 1
fi

reset_gamma() {
    if [ -r "$pid_file" ]; then
        read -r pid < "$pid_file"

        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    fi

    pkill -u "$(id -u)" -x gammastep >/dev/null 2>&1 || true
    rm -f "$pid_file"

    if command -v timeout >/dev/null 2>&1; then
        timeout 1 gammastep -x >/dev/null 2>&1 || true
    else
        gammastep -x >/dev/null 2>&1 &
    fi
}

enable_night_mode() {
    printf '%s\n' "$temperature" > "$state_file"
    notify "on"

    (
        if [ -r "$pid_file" ]; then
            read -r old_pid < "$pid_file"

            if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
                kill "$old_pid" 2>/dev/null || true
            fi
        fi

        pkill -u "$(id -u)" -x gammastep >/dev/null 2>&1 || true
        [ -e "$state_file" ] || exit 0

        gammastep -O "$temperature" >/dev/null 2>&1 &
        printf '%s\n' "$!" > "$pid_file"
    ) &
}

disable_night_mode() {
    rm -f "$state_file"
    notify "off"

    reset_gamma &
}

case "${1:-toggle}" in
    on)
        enable_night_mode
        ;;
    off)
        disable_night_mode
        ;;
    toggle)
        if [ -e "$state_file" ]; then
            disable_night_mode
        else
            enable_night_mode
        fi
        ;;
    *)
        echo "Usage: $0 [on|off|toggle]" >&2
        exit 2
        ;;
esac
