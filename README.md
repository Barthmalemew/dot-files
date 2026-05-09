# dot-files

Simple setup repo for Gentoo machines. A base Gentoo install is assumed to
already exist; this repo does not try to perfectly maintain every system detail.

The main entrypoint is `setup.sh`.

## Layout

- `dotfiles/`: shared user config copied from this desktop.
- `packages/common.txt`: shared package atoms captured from this desktop.
- `packages/ladmin.txt`: desktop-only package additions.
- `packages/laptop.txt`: future laptop-only package additions.
- `portage/common/`: shared Portage snippets.
- `portage/hosts/<host>/`: host-specific Portage notes/examples.
- `openrc/hosts/<host>/services.txt`: OpenRC service/runlevel pairs.
- `hosts/<host>/`: host-specific notes.

## Review

```bash
./setup.sh --host ladmin --check
./setup.sh --host ladmin --install-packages --dry-run
./setup.sh --host ladmin --apply-dotfiles --dry-run
./setup.sh --host ladmin --apply-openrc --dry-run
```

## Apply

```bash
./setup.sh --host ladmin --install-packages
./setup.sh --host ladmin --apply-dotfiles
./setup.sh --host ladmin --apply-portage
./setup.sh --host ladmin --apply-openrc
```

The laptop starts from the desktop OpenRC list and can add laptop-only packages,
firmware, Quickshell pieces, and host-specific Portage config later.

## Exclusions

Do not commit SSH private keys, Wi-Fi secrets, browser state, Obsidian runtime
files, Copilot tokens, Pulse cookies, logs, caches, or UUID-bound boot/storage
configuration. Drive-specific setup and monitor/output layout are intentionally
left out of the shared setup because they are desktop-only.
