#!/usr/bin/env bash
set -euo pipefail

dest_dir="${HOME}/Pictures/Screenshots"
mkdir -p "${dest_dir}"

timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
outfile="${dest_dir}/Screenshot_${timestamp}.png"

geometry="$(slurp)"
[ -n "${geometry}" ] || exit 0

grim -g "${geometry}" "${outfile}"
wl-copy < "${outfile}"
