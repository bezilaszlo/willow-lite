# Willow Lite

A small, writable Arch Linux ARM system for the Redmi Note 8T (willow). The goal is to edit the desktop and most of the operating system while the phone is running, with short transfers over USB.

## Design

- Keep the device kernel, device tree, and early boot files in a small boot image. Use RAM boot during development.
- Install the Arch Linux ARM root filesystem once, then update packages and files in place over USB networking and SSH.
- Run a minimal Wayland compositor with Quickshell for the desktop UI. Keep the Quickshell configuration in a normal writable directory so QML changes reload without rebuilding an image.
- Keep SSH and a visible text console available while the graphical display path is being worked out.

The trial uses Sway with an explicit touchscreen-to-panel mapping, a pinned build of the small wlroots keyboard wvkbd, and a Quickshell top bar. The bar opens/closes foot, toggles the keyboard, and maps horizontal swipes to terminal/home navigation. A systemd unit restores the panel backlight to maximum only when needed, before tty1 autologin starts the graphical session.

Raw evdev measurements found that touch coordinates in the right third arrive with vertical position reversed. Left-column and center-column primary points mapped normally, but center taps also produced an approximately mirrored extra contact. The Sway preload shim corrects Y on the right third before apps receive touch events; it does not filter the extra contact. The shim applies only to `NVTCapacitiveTouchScreen`, and physical validation remains pending. `scripts/configure-trial.sh` builds the shim with ARM64-targeting Clang and LLD. LLD can be installed on the host or extracted under `out/toolchain/usr`. `tests/touch-map/run.sh` replays the recorded taps against a mock libinput. To disable the live shim safely, run `sudo /usr/local/sbin/willow-touch-map-rollback`; it removes the shim and restarts tty1 with the direct Sway launcher.

## First milestones

1. Install the package manifest into a new trial directory on userdata with a separate pacman database; keep the current `/` intact.
2. Install the pinned native AArch64 Codex CLI and prove it runs on the device.
3. Prove a small compositor and Quickshell can show a usable image on the physical display, with SSH and console recovery.
4. Keep package and device configuration in this repository, and build a small RAM boot image with `scripts/build-trial-boot.sh`.
5. Install a root filesystem only after the trial system is usable and the existing userdata has been accounted for.

The trial package root is `/var/lib/willow-lite-trial` on the phone. Packages are installed directly with Arch ARM pacman into that directory, so no generic 829 MB rootfs archive is sent over USB. The initial package transaction resolved to 262 packages (271 MiB of repository archives); the installed tree was 1.7 GiB before removing Node/npm for the native Codex binary. The existing installed root remains the fallback when the RAM boot image cannot find the trial directory.

`scripts/install-codex.sh` fetches the pinned upstream AArch64 musl release, checks its SHA-256, and installs it under the trial root. `scripts/build-trial-boot.sh` combines the known-good Willow kernel and DTB with this repository's initramfs init. `mini/boot-it.sh` in the `moarchy-willow` checkout performs the fastboot RAM boot while preserving the current system image.

See [docs/architecture.md](docs/architecture.md) for the proposed layout and iteration loop.

This repository describes the local Willow Lite trial, not a bootable release. `scripts/configure-trial.sh` configures the staged trial root, and `scripts/build-trial-boot.sh` creates the RAM boot image.
