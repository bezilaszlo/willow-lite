# Architecture sketch

## Boot boundary

The boot image contains only what the device needs to mount the root filesystem: the known working kernel and device tree, a small initramfs, and boot parameters. `scripts/build-trial-boot.sh` sets `willow_root=/var/lib/willow-lite-trial`. The initramfs mounts the existing userdata filesystem and bind-mounts that directory as `/`; if it is missing, boot falls back to the existing root. Keep a known working RAM boot image available while changing any boot component. Normal desktop edits must not require rebuilding this image.

The root filesystem is Arch Linux ARM for AArch64, installed on writable device storage. The trial is staged directly under `/var/lib/willow-lite-trial` with `pacman --root` and its own package database; this avoids downloading and unpacking the 829 MB generic rootfs archive. [packages.txt](../packages.txt) is the package manifest. Device settings live under [device/](../device/). The initial transaction used 262 packages and transferred 271 MiB of package archives; the resulting root tree measured 1.7 GiB before replacing Node/npm with the native Codex binary.

## Running system

- **System changes:** install and update packages with pacman; edit service and system configuration over SSH. Affected services may need a restart.
- **Desktop changes:** edit QML, assets, and configuration on the mounted root filesystem. Quickshell watches its configuration files and reloads changes. Keep the UI source in Git and sync changed files over USB networking with rsync.
- **Desktop preview:** `scripts/preview-phone.sh` runs the device's Quickshell QML in a headless Sway session at 540×1170 logical pixels and shows it in a native VNC viewer tiled beside the terminal on Omarchy. `scripts/capture-preview.sh` captures the full-size output. Use the phone for hardware and physical touch checks.
- **Kernel and early boot changes:** rebuild only the small boot image and RAM boot it again.
- **Recovery:** retain SSH access and a text console independently of the graphical session. Start the compositor explicitly until the display path is reliable.
- **Touch:** Sway maps the touchscreen to the single DSI output. This phone's Shenchao variant needs the EBBG firmware payload embedded in the RAM boot kernel. Physical 1–9 and two-finger checks now produce correctly placed raw contacts without a userspace remap.
- **Keyboard controls:** wvkbd provides basic typing for this trial. Its 310 logical pixel layer reserves space only while shown, leaving the terminal visible above it. The Quickshell top bar reserves 92 logical pixels so the terminal starts below the controls. The planned replacement is a programmable Quickshell bottom panel whose model can define buttons, labels, icons, modes, contextual options, and actions such as typing text, sending keys, or launching apps.

## Decisions to prove on the existing system

1. **Agent harness:** verify a native AArch64 Codex CLI installation, sign-in, and an actual command. Official Linux support alone does not establish that this device and architecture work.
2. **Compositor:** use Sway, whose input mapping is explicit and whose Wayland interfaces match the target CUA workflow. Keep the backlight at maximum before tty1 autologin; the current Hyprland path loses the backlight.
3. **Package footprint:** measure installed size and transfer size of the chosen package set. Do not copy the existing desktop's full package set into the new root filesystem.
4. **Storage:** inspect the current userdata layout and save anything needed before replacing it. Root filesystem installation will be planned separately from RAM boot experiments.

## Install and iteration sequence

1. Install the manifest into a new trial directory with an isolated pacman database; leave the existing userdata root untouched.
2. Configure USB networking, SSH, and the trial user from the versioned files under `device/`.
3. Run `scripts/install-codex.sh` to install the pinned native AArch64 Codex binary, and `scripts/install-gpu-firmware.sh` to install the Adreno 610 firmware (see [hardware.md](hardware.md#gpu)).
4. Build the small trial boot image and RAM boot it with the known-good fastboot workflow. Keep the current boot image ready for recovery.
5. Iterate over USB networking: sync changed files, use pacman on the device, and reload Quickshell or restart only the affected service.
6. Once boot, recovery, Codex, and the GUI work, prepare a deliberate install to userdata.

The final partition layout and persistent boot installation remain open while this RAM-boot trial is validated.

The borrowed kernel image embeds Tianma touch firmware even though this phone's bootloader identifies a Shenchao panel. The downstream driver maps Shenchao to EBBG. `scripts/build-trial-boot.sh` first preserves a Tianma recovery image, then `scripts/build-ebbg-trial-boot.sh` replaces the unique embedded firmware payload with the equally sized EBBG blob in the default RAM boot image. The ramdisk and device tree are preserved byte for byte. The EBBG kernel loaded successfully as touch firmware PID 5923; nine physical single-finger taps produced nine correctly located raw contacts, and a two-finger check produced two overlapping contacts. The boot partition remains unchanged.

## References

- [Arch Linux ARM generic AArch64 root filesystem](https://archlinuxarm.org/platforms/armv8/generic)
- [Arch Linux ARM Quickshell package](https://archlinuxarm.org/packages/aarch64/quickshell)
- [Arch Linux ARM Sway package](https://archlinuxarm.org/packages/aarch64/sway)
- [Quickshell configuration file watching](https://quickshell.org/docs/v0.3.1/types/Quickshell/Quickshell/)
