# ladmin

Current desktop. Package list is captured from `/var/lib/portage/world`.

Current baseline:

- Gentoo Base System release 2.18
- Kernel: 7.0.3-gentoo-gentoo-dist
- Profile: default/linux/amd64/23.0/desktop

Shared desktop/session behavior:

- Manual night mode is installed from `packages/common.txt` via
  `x11-misc/gammastep` and toggled through the shared Mango binding
  `SUPER+SHIFT+O`.
- Shared user applications from the desktop package set, including
  `net-im/vesktop-bin::guru`, live in `packages/common.txt` so ladmin and the
  laptop converge on the same day-to-day app set.

Host-bound files such as `fstab`, dracut root UUIDs, drive layout, monitor
layout, and kernel build output are not applied by `setup.sh`.
