# Architecture sketch

## Boot boundary

The boot image contains only what the device needs to mount the root filesystem: the known working kernel and device tree, a small initramfs, and boot parameters. `scripts/build-trial-boot.sh` sets `willow_root=/var/lib/willow-lite-trial`. The initramfs mounts the existing userdata filesystem and bind-mounts that directory as `/`; if it is missing, boot falls back to the existing root. Keep a known working RAM boot image available while changing any boot component. Normal desktop edits must not require rebuilding this image.

The root filesystem is Arch Linux ARM for AArch64, installed on writable device storage. The trial is staged directly under `/var/lib/willow-lite-trial` with `pacman --root` and its own package database; this avoids downloading and unpacking the 829 MB generic rootfs archive. [packages.txt](../packages.txt) is the package manifest. Device settings live under [device/](../device/). The initial transaction used 262 packages and transferred 271 MiB of package archives; the resulting root tree measured 1.7 GiB before replacing Node/npm with the native Codex binary.

## Running system

- **System changes:** install and update packages with pacman; edit service and system configuration over SSH. Affected services may need a restart.
- **Desktop changes:** edit QML, assets, and configuration on the mounted root filesystem. Quickshell watches its configuration files and reloads changes. Keep the UI source in Git and sync changed files over USB networking with rsync.
- **Kernel and early boot changes:** rebuild only the small boot image and RAM boot it again.
- **Recovery:** retain SSH access and a text console independently of the graphical session. Start the compositor explicitly until the display path is reliable.
- **Touch:** Sway maps the touchscreen to the single DSI output. Raw samples showed a reversed Y coordinate in the right third, so a provisional libinput preload remaps that region before apps receive touch events. Two center samples also contained an approximately mirrored second contact; the current shim leaves it untouched because slot filtering could break real gestures. Physical validation of the remap is pending.
- **Keyboard controls:** wvkbd provides basic typing for this trial. The planned replacement is a programmable Quickshell bottom panel whose model can define buttons, labels, icons, modes, contextual options, and actions such as typing text, sending keys, or launching apps.

## Decisions to prove on the existing system

1. **Agent harness:** verify a native AArch64 Codex CLI installation, sign-in, and an actual command. Official Linux support alone does not establish that this device and architecture work.
2. **Compositor:** use Sway, whose input mapping is explicit and whose Wayland interfaces match the target CUA workflow. Keep the backlight at maximum before tty1 autologin; the current Hyprland path loses the backlight.
3. **Package footprint:** measure installed size and transfer size of the chosen package set. Do not copy the existing desktop's full package set into the new root filesystem.
4. **Storage:** inspect the current userdata layout and save anything needed before replacing it. Root filesystem installation will be planned separately from RAM boot experiments.

## Install and iteration sequence

1. Install the manifest into a new trial directory with an isolated pacman database; leave the existing userdata root untouched.
2. Configure USB networking, SSH, and the trial user from the versioned files under `device/`.
3. Run `scripts/install-codex.sh` to install the pinned native AArch64 Codex binary.
4. Build the small trial boot image and RAM boot it with the known-good fastboot workflow. Keep the current boot image ready for recovery.
5. Iterate over USB networking: sync changed files, use pacman on the device, and reload Quickshell or restart only the affected service.
6. Once boot, recovery, Codex, and the GUI work, prepare a deliberate install to userdata.

The final partition layout and persistent boot installation remain open while this RAM-boot trial is validated.

`scripts/configure-trial.sh` builds the AArch64 touch shim with Clang and LLD and installs it at `/usr/local/lib/willow-touch-map.so`. Sway has the `cap_sys_nice` file capability, which makes glibc ignore `LD_PRELOAD`; the tty1 launcher therefore invokes Sway through `/lib/ld-linux-aarch64.so.1 --preload`. This trial path does not retain Sway's file capability. Run `sudo /usr/local/sbin/willow-touch-map-rollback` to restore the direct Sway launcher and restart tty1.

The current kernel image embeds Tianma touch firmware even though this phone's bootloader identifies a Shenchao panel. The downstream driver maps Shenchao to the EBBG firmware variant, but that does not prove the variant will fix touch. `scripts/build-ebbg-trial-boot.sh` prepares a separate RAM boot image by replacing the one embedded firmware payload with the equally sized EBBG blob. It preserves the working image and does not flash or boot the alternate image. A controlled device trial and physical taps are still needed.

## References

- [Arch Linux ARM generic AArch64 root filesystem](https://archlinuxarm.org/platforms/armv8/generic)
- [Arch Linux ARM Quickshell package](https://archlinuxarm.org/packages/aarch64/quickshell)
- [Arch Linux ARM Sway package](https://archlinuxarm.org/packages/aarch64/sway)
- [Quickshell configuration file watching](https://quickshell.org/docs/v0.3.1/types/Quickshell/Quickshell/)
