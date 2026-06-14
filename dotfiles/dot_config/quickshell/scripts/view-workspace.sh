#!/bin/sh

tag="$1"
monitor="$2"

if [ -z "$tag" ]; then
    exit 2
fi

if [ -n "$monitor" ]; then
    mmsg dispatch "viewcrossmon,$tag,$monitor" || exit $?
    qs ipc call workspaceOverlay show "$monitor" >/dev/null 2>&1 || true
else
    mmsg dispatch "view,$tag,0" || exit $?
    qs ipc call workspaceOverlay showPrimary >/dev/null 2>&1 || true
fi

# Desktop-only output-name hooks, disabled for shared use:
# case "$monitor" in
#     DP-1)
#         qs ipc call workspaceOverlay showDp1
#         ;;
#     DP-2)
#         qs ipc call workspaceOverlay showDp2
#         ;;
# esac
