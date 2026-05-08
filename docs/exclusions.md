# Exclusions

Do not commit these categories:

- SSH private keys or agent state.
- Wi-Fi profiles and network secrets.
- Browser profiles, cookies, local storage, or cache.
- Obsidian runtime/cache files.
- GitHub Copilot tokens or account state.
- Pulse/PipeWire cookies and runtime state.
- Logs, caches, lock files, generated package build output.
- UUID-bound boot/storage configuration such as `fstab`, initramfs command lines, and dracut root UUIDs.

Host-bound values belong under `hosts/<host>/`, `packages/<host>.txt`,
`openrc/hosts/<host>/services.txt`, or `portage/hosts/<host>/`.
