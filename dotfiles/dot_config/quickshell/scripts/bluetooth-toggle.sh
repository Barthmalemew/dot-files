#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
state_file="$runtime_dir/quickshell-bluetooth-mode"

notify() {
    qs ipc call osd showBluetoothMode "$1" >/dev/null 2>&1 || true
}

radio_is_unblocked() {
    rfkill list bluetooth 2>/dev/null | grep -q 'Soft blocked: no'
}

if ! command -v pkexec >/dev/null 2>&1; then
    notify "missing"
    exit 1
fi

if [ ! -r /usr/share/polkit-1/actions/com.local.bluetooth-toggle.policy ]; then
    notify "missing"
    exit 1
fi

if ! pgrep -u "$(id -u)" -f '(^|/)lxqt-policykit-agent($| )' >/dev/null 2>&1; then
    lxqt-policykit-agent >/dev/null 2>&1 &
fi

case "${1:-toggle}" in
    on|off)
        target="$1"
        ;;
    status)
        if radio_is_unblocked; then
            notify "on"
            printf '%s\n' on
        else
            notify "off"
            printf '%s\n' off
        fi
        exit 0
        ;;
    toggle)
        if [ -r "$state_file" ]; then
            read -r current < "$state_file"
        elif radio_is_unblocked; then
            current="on"
        else
            current="off"
        fi

        if [ "$current" = "on" ]; then
            target="off"
        else
            target="on"
        fi
        ;;
    *)
        echo "Usage: $0 [on|off|toggle|status]" >&2
        exit 2
        ;;
esac

printf '%s\n' "$target" > "$state_file"
notify "$target"

(
    state="$(pkexec /usr/local/sbin/bluetooth-toggle-helper "$target" 2>/dev/null)" || {
        if [ "$target" = "off" ] && ! radio_is_unblocked; then
            printf '%s\n' off > "$state_file"
            exit 0
        fi

        rm -f "$state_file"
        notify "failed"
        exit 1
    }

    case "$state" in
        on|off)
            printf '%s\n' "$state" > "$state_file"
            ;;
        missing)
            rm -f "$state_file"
            notify "missing"
            ;;
        *)
            rm -f "$state_file"
            notify "failed"
            exit 1
            ;;
    esac
) &
