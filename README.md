# Willow Lite

A small, writable Arch Linux ARM system for the Redmi Note 8T (willow). The goal is to edit the desktop and most of the operating system while the phone is running, with short transfers over USB.

## Design

- Keep the device kernel, device tree, and early boot files in a small boot image. Use RAM boot during development.
- Install the Arch Linux ARM root filesystem once, then update packages and files in place over USB networking and SSH.
- Run a minimal Wayland compositor with Quickshell for the desktop UI. Keep the Quickshell configuration in a normal writable directory so QML changes reload without rebuilding an image.
- Keep SSH and a visible text console available while the graphical display path is being worked out.

The trial runs Hyprland 0.56 or Sway, chosen on the phone with `willow-compositor hyprland` or `willow-compositor sway`. The command restarts the tty1 session within seconds, and SSH stays up. From the host, `ssh moarchy@172.16.42.1 willow-compositor sway` is the one-command rollback. Hyprland starts are checked: if Hyprland does not light the panel after two tries, the session falls back to Sway ([hardware notes](docs/hardware.md#hyprland-and-the-dsi-panel-willow)). Hyprland is the default; Sway stays as the fallback until a cold boot into Hyprland and the retry path have been tested, then it can be removed. `bash scripts/sync-session.sh` copies changed session, Hyprland, Sway, Quickshell and foot files to the running phone.

Both compositors use an explicit touchscreen-to-panel mapping, a pinned build of the small wlroots keyboard wvkbd, and a Quickshell top bar. The bar reserves its 92 logical pixels at the top of the workspace, keeping the terminal below it. The hidden keyboard reserves its 310 logical pixels only while shown, leaving more room for terminal output. The bar opens/closes foot, toggles the keyboard, and maps horizontal swipes to terminal/home navigation. A systemd unit restores the panel backlight to maximum only when needed, before tty1 autologin starts the graphical session.

The phone's bootloader identifies a Shenchao panel, while the borrowed kernel image embedded Tianma touch firmware. That mismatch caused reversed Y coordinates on the right and mirrored extra contacts near the center. The trial now embeds the EBBG firmware variant, which the downstream driver associates with Shenchao. With EBBG and no software remapping, a physical 1–9 grid check registered every tap in order with one raw contact per tap; a two-finger check registered two overlapping contacts at the intended positions. The boot image is still RAM booted, not flashed to a partition.

## First milestones

1. Install the package manifest into a new trial directory on userdata with a separate pacman database; keep the current `/` intact.
2. Install the pinned native AArch64 Codex CLI and prove it runs on the device.
3. Prove a small compositor and Quickshell can show a usable image on the physical display, with SSH and console recovery.
4. Keep package and device configuration in this repository, and build a small RAM boot image with `scripts/build-trial-boot.sh`.
5. Install a root filesystem only after the trial system is usable and the existing userdata has been accounted for.

The trial package root is `/var/lib/willow-lite-trial` on the phone. Packages are installed directly with Arch ARM pacman into that directory, so no generic 829 MB rootfs archive is sent over USB. The initial package transaction resolved to 262 packages (271 MiB of repository archives); the installed tree was 1.7 GiB before removing Node/npm for the native Codex binary. The existing installed root remains the fallback when the RAM boot image cannot find the trial directory.

`scripts/install-codex.sh` fetches the pinned upstream AArch64 musl release, checks its SHA-256, and installs it under the trial root. `scripts/build-trial-boot.sh` combines the Willow kernel and DTB with this repository's initramfs init, then substitutes the EBBG firmware payload. It also retains a Tianma image under `out/` for recovery. `mini/boot-it.sh` in the `moarchy-willow` checkout performs the fastboot RAM boot while preserving the current system image.

See [docs/architecture.md](docs/architecture.md) for the proposed layout and iteration loop.

For desktop GUI iteration on Omarchy, install the preview dependencies with `omarchy pkg add sway wayvnc gtk-vnc python-gobject`, then run `bash scripts/preview-phone.sh`. It runs the same Quickshell QML as the device on an isolated 540×1170 logical pixel Sway output and opens a native viewer tiled beside your terminal. The viewer keeps the phone's portrait aspect ratio. Run `bash scripts/capture-preview.sh` to save a full-size screenshot under `out/`. The preview exercises layout and pointer-driven interactions; panel, backlight, and physical touch behavior still require the phone.

This repository describes the local Willow Lite trial, not a bootable release. `scripts/configure-trial.sh` configures the staged trial root, and `scripts/build-trial-boot.sh` creates the RAM boot image.
