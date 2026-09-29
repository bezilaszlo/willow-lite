# Changelog

## 2026-09-29

- Make `codex` on the phone run with `--no-daemon`, since the native build reports an incomplete package for the shared background server.
- Keep the terminal below the 92 px Quickshell top bar and reduce the on-screen keyboard to a 310 px reserved area while it is visible.
- Add a desktop Sway preview at the phone's logical screen size, running the same Quickshell UI in a tiled native viewer that preserves its portrait aspect ratio, with a local screenshot command.
- Use the EBBG touch firmware in the Willow Lite RAM boot image for this Shenchao device. Physical nine-point and two-finger checks passed without userspace correction.
- Keep the original Tianma boot image as a local recovery artifact. The phone's boot partition is unchanged.
- Remove the provisional libinput touch remap and start Sway normally.

## 2026-09-28

- Boot the first Arch Linux ARM Willow Lite trial with Sway, Quickshell, foot, wvkbd, SSH, and a native AArch64 Codex binary.
