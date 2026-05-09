#!/bin/sh

tag="$1"
monitor="$2"

if [ -z "$tag" ] || [ -z "$monitor" ]; then
    exit 2
fi

mmsg -s -d "viewcrossmon,$tag,$monitor"

# Desktop-only output-name hooks, disabled for shared use:
# case "$monitor" in
#     DP-1)
#         qs ipc call workspaceOverlay showDp1
#         ;;
#     DP-2)
#         qs ipc call workspaceOverlay showDp2
#         ;;
# esac
