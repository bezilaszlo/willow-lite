# Willow Lite

A small, writable Arch Linux ARM system for the Redmi Note 8T (willow). The goal is to edit the desktop and most of the operating system while the phone is running, with short transfers over USB.

## Design

- Keep the device kernel, device tree, and early boot files in a small boot image. Use RAM boot during development.
- Install the Arch Linux ARM root filesystem once, then update packages and files in place over USB networking and SSH.
- Run a minimal Wayland compositor with Quickshell for the desktop UI. Keep the Quickshell configuration in a normal writable directory so QML changes reload without rebuilding an image.
- Keep SSH and a visible text console available while the graphical display path is being worked out.

The current Hyprland session can turn off the physical backlight even while the desktop continues to render. A different compositor is a candidate to investigate, not a confirmed fix.

## First milestones

1. Prove the Codex CLI can install, authenticate, and run on the phone's AArch64 Arch system.
2. Prove a small compositor and Quickshell can show a usable image on the physical display, with SSH and console recovery.
3. Define a minimal, reproducible Arch Linux ARM package set from those results.
4. Build and RAM boot a small boot image against a trial root filesystem.
5. Install the root filesystem only after the trial system is usable and the existing userdata has been accounted for.

See [docs/architecture.md](docs/architecture.md) for the proposed layout and iteration loop.

This repository is local for now. It does not contain a bootable release or a phone installation script yet.
