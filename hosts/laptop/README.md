# laptop

Future Gentoo laptop. Start from `packages/common.txt` plus any additions in
`packages/laptop.txt`.

The OpenRC service list currently mirrors `ladmin`; add laptop-only services as
needed after inspecting the laptop.

Keep laptop firmware, Quickshell extras, and kernel support packages here or in
`packages/laptop.txt`. Do not commit UUID-bound boot/storage state.

