#!/bin/sh

log_file="${XDG_RUNTIME_DIR:-/tmp}/quickshell-sleep-lock.log"
pid_file="${XDG_RUNTIME_DIR:-/tmp}/quickshell-sleep-lock-watcher.pid"

if [ -f "$pid_file" ]; then
    old_pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        exit 0
    fi
fi

printf '%s\n' "$$" >"$pid_file" || exit 1
trap 'rm -f "$pid_file"' EXIT HUP INT TERM

lock_screen() {
    qs ipc -p "$HOME/.config/quickshell/shell.qml" call lockScreen lock >>"$log_file" 2>&1 || true
}

while :; do
    dbus-monitor --system "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'" 2>>"$log_file" |
        while IFS= read -r line; do
            case "$line" in
                *"boolean true"*)
                    date >>"$log_file"
                    lock_screen
                    ;;
            esac
        done

    sleep 2
done
