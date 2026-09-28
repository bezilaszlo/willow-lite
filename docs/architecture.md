# Architecture sketch

## Boot boundary

The boot image contains only what the device needs to mount the root filesystem: the known working kernel and device tree, a small initramfs, and boot parameters. Keep a known working RAM boot image available while changing any boot component. Normal desktop edits must not require rebuilding this image.

The root filesystem is Arch Linux ARM for AArch64, installed on writable device storage. It contains the package manager, network and SSH services, a compositor, Quickshell, development tools, and the agent harness. We will derive an explicit package list after checking what actually works on willow.

## Running system

- **System changes:** install and update packages with pacman; edit service and system configuration over SSH. Affected services may need a restart.
- **Desktop changes:** edit QML, assets, and configuration on the mounted root filesystem. Quickshell watches its configuration files and reloads changes. Keep the UI source in Git and sync changed files over USB networking with rsync.
- **Kernel and early boot changes:** rebuild only the small boot image and RAM boot it again.
- **Recovery:** retain SSH access and a text console independently of the graphical session. Start the compositor explicitly until the display path is reliable.

## Decisions to prove on the existing system

1. **Agent harness:** verify a native AArch64 Codex CLI installation, sign-in, and an actual command. Official Linux support alone does not establish that this device and architecture work.
2. **Compositor:** try labwc as a small Wayland compositor with layer shell support, then launch Quickshell. Confirm that the screen stays physically lit through launch and exit. The current Hyprland path loses the backlight.
3. **Package footprint:** measure installed size and transfer size of the chosen package set. Do not copy the existing desktop's full package set into the new root filesystem.
4. **Storage:** inspect the current userdata layout and save anything needed before replacing it. Root filesystem installation will be planned separately from RAM boot experiments.

## Install and iteration sequence

1. Run the compatibility checks on the current Arch system without changing its partitions.
2. Assemble a minimal Arch Linux ARM root filesystem on the host and keep its package manifest in this repository.
3. Transfer that root filesystem once to a trial location and RAM boot against it.
4. Iterate over USB networking: sync changed files, use pacman on the device, and reload Quickshell or restart only the affected service.
5. Once boot, recovery, Codex, and the GUI work, prepare a deliberate install to userdata.

The exact storage path, package manifest, and boot configuration remain open until the compatibility checks are complete.

## References

- [Arch Linux ARM generic AArch64 root filesystem](https://archlinuxarm.org/platforms/armv8/generic)
- [Arch Linux ARM Quickshell package](https://archlinuxarm.org/packages/aarch64/quickshell)
- [Arch Linux ARM labwc package](https://archlinuxarm.org/packages/aarch64/labwc)
- [labwc integration and layer shell support](https://labwc.github.io/integration.html)
- [Quickshell configuration file watching](https://quickshell.org/docs/v0.3.1/types/Quickshell/Quickshell/)
