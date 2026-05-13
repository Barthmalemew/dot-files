# laptop

Gentoo laptop profile for the Lenovo ThinkPad X9-14 Gen 1 (`21QA0036US`).
Use `--host laptop` for this hardware profile even if the installed hostname is
temporarily something else.

## Observed Hardware

- CPU: Intel Core Ultra 7 268V / Lunar Lake.
- GPU: Intel Lunar Lake Arc 130V/140V graphics; use Intel userspace and the
  kernel `xe` driver path.
- Display: internal eDP panel at 2880x1800; Mango needs 1.5 compositor scaling.
- Wireless: Intel BE201 320MHz Wi-Fi through `iwlwifi`.
- Bluetooth: Intel PCIe Bluetooth through `btintel_pcie`.
- Audio: Lunar Lake HD Audio exposes `sof-soundwire`; it requires SOF firmware.
- Backlight: `intel_backlight`; brightness keys use `brightnessctl`.
- Other platform devices: IPU7 camera, Intel NPU, Thunderbolt 4, integrated
  sensor hub, SK hynix PVC10 NVMe storage.

## Required Laptop Deviations

These are hardware or laptop-session requirements and should not be forced onto
the desktop unless the desktop independently needs them.

- Packages in `packages/laptop.txt`:
  `sys-firmware/sof-firmware`, `media-sound/alsa-utils`,
  `media-plugins/alsa-plugins`, `net-wireless/bluez`, `app-misc/brightnessctl`,
  `sys-power/tlp`, `sys-power/upower`, `sys-power/powertop`,
  `sys-apps/lm-sensors`, and `sys-apps/smartmontools`.
- OpenRC laptop services add `bluetooth default` and `tlp default`.
- `portage/hosts/laptop/make.conf.example` sets `VIDEO_CARDS="intel"` and
  `INPUT_DEVICES="libinput"` for this laptop.
- `portage/hosts/laptop/package.use/00cpu-flags` captures the Lunar Lake CPU
  flags for package builds.
- `portage/hosts/laptop/package.accept_keywords/brightnessctl` accepts
  `app-misc/brightnessctl ~amd64`.
- `dotfiles/dot_config/mango/monitor.conf` includes the laptop `eDP-1`
  2880x1800 scale rule. Desktop monitor placement should remain commented.
- Mango trackpad defaults and native `gesturebind` are required for the
  touchpad. There is no separate gesture daemon or OpenRC service.

## Shared Source Of Truth

These should stay identical between laptop and desktop unless there is a clear
host-specific reason to split them.

- Common package atoms live in `packages/common.txt`.
- Shared Mango behavior lives under `dotfiles/dot_config/mango/`, with
  host-specific monitor placement kept as explicit monitor rules.
- Quickshell modules and scripts are shared; media keys call the shared
  `volume-control.sh` and `brightness-control.sh` helpers.
- PipeWire, WirePlumber, and PipeWire Pulse are started as OpenRC user services
  from Mango so Quickshell, pavucontrol, and the session see the same audio
  server.
- Logging standard is `sysklogd`.
- `cronie` and `syslog-ng` are intentionally not part of this laptop profile.

## Current Mango Input

Trackpad defaults in `dotfiles/dot_config/mango/config.conf`:

- `disable_trackpad=0`
- `tap_to_click=1`
- `tap_and_drag=1`
- `drag_lock=1`
- `disable_while_typing=1`
- `trackpad_natural_scrolling=1`
- `scroll_method=1`
- `click_method=2`

Native Mango gestures in `dotfiles/dot_config/mango/bind.conf` use inverted,
natural-feeling 3-finger swipes to focus within the current workspace only:

- swipe left focuses right
- swipe right focuses left
- swipe up focuses down
- swipe down focuses up

No trackpad gesture switches workspaces/tags.

## Setup Order

1. Preview changes with `./setup.sh --host laptop --check --dry-run`.
2. Stabilize OpenRC services before applying desktop dotfiles.
3. Install common packages plus `packages/laptop.txt`.
4. Merge Portage snippets carefully; do not blindly replace local
   `/etc/portage` entries without reviewing the diff.
5. Install `ble.sh` with `./setup.sh --install-ble-sh`.
6. Apply dotfiles after the service and package layer is healthy.
7. Validate greetd, MangoWM, Quickshell, portals, audio, Wi-Fi, Bluetooth,
   suspend/resume, brightness keys, and battery reporting.

## Root Steps

Run these manually from a root shell or with sudo after reviewing the dry-run:

```bash
cd /home/barthmalemew/dot-files
cp -a /etc/portage "/etc/portage.backup.$(date +%Y%m%d-%H%M%S)"
./setup.sh --host laptop --apply-portage
./setup.sh --host laptop --install-packages
rc-update del cronie default
rc-update del syslog-ng default
emerge --ask --noreplace app-admin/sysklogd
emerge --ask --depclean sys-process/cronie app-admin/syslog-ng
./setup.sh --host laptop --apply-openrc
rc-update add sysklogd default
rc-service dbus start
rc-service NetworkManager restart
rc-service sysklogd start
rc-service bluetooth start
rc-service tlp start
rc-service greetd start
rc-status -a
```

## Laptop Audio

Lunar Lake audio needs SOF firmware before ALSA can expose a real sound card.
If Quickshell shows `No sink`, pavucontrol has no devices, and
`cat /proc/asound/cards` prints `--- no soundcards ---`, install the laptop
package set and reboot so the kernel can load the firmware during probe.

```bash
cd /home/barthmalemew/dot-files
./setup.sh --host laptop --install-packages
reboot
```

After reboot, verify the stack from the user session:

```bash
ls /dev/snd
cat /proc/asound/cards
aplay -l
rc-service --user dbus status
rc-service --user pipewire status
rc-service --user wireplumber status
rc-service --user pipewire-pulse status
wpctl status
pactl list short sinks
sh ~/.config/quickshell/scripts/launcher-status.sh
```

If `/dev/snd` is still missing after `sys-firmware/sof-firmware` is installed
and the machine has rebooted, the next useful data is root `dmesg` output for
`sof`, `snd`, `hda`, and `audio`.

## Exclusions

Do not commit UUID-bound boot/storage state, Wi-Fi secrets, display-output
state that only applies to one dock/desk, browser state, logs, caches, or local
tokens.
