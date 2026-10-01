# Roadmap

Updated 2026-10-01.

## Baseline and current state

The user's historical baseline is that the original/community kernel with Sway worked; they moved to Hyprland for animations before the own-kernel effort. Compare the same image and configuration before attributing a black display to the low-level kernel. Hyprland panel starts had mixed outcomes, not universal failure.

The own-kernel CTM/DSPP-preallocation image is the current working checkpoint. The user confirmed visible desktop, touch, and keyboard after two RAM boots, a ten-minute session, and one CTM-enabled DPMS off/on cycle. This does not establish repeatability, cold-boot reliability, or arbitrary CTM value changes. Keep Sway as a fallback.

## Done

- Trial boot with Sway, Quickshell, foot, wvkbd, SSH, and native AArch64 Codex (`--no-daemon` wrapper).
- Phone-sized desktop preview and screenshot capture.
- GPU audit: the Adreno 610 stack composites on the GPU under both compositors ([hardware](hardware.md#gpu)).
- Hyprland 0.56 beside Sway, selected with `willow-compositor` and falling back to Sway.
- Own-kernel touchscreen-enabled RAM image with working Hyprland and CTM/DSPP-preallocation on two user-confirmed boots, a 10-minute interaction check, and one successful DPMS cycle. Repeated modesets, VT switches, cold boots, and nonidentity/night-light CTM changes remain unverified.
- Physical power-key menu deployed: short press toggles display, two-second hold opens Restart/Shut down/Cancel. Physical menu interaction is still unverified; normal Restart follows the installed boot path rather than the RAM-boot wrapper.
- Redesigned Quickshell home, installed-app launcher, status-only top bar, cancellable Back, running-app selector, and exactly-three-finger screenshot source deployed to the live Hyprland session. Host 540x1170 home preview and QML load succeeded; user physical gesture validation is pending.

## Now

1. Get the user's first physical check of the live shell: home/status, bottom-swipe selector, tap-to-focus, card swipe-to-close, Home return, edge Back, and screenshot finger count.
2. Verify the source-preserved Sway fallback before switching to it. `willow-sway.qml` retains the previous UI, but the matching path change is not deployed to the phone yet.
3. Complete physical validation of touch interaction and card thumbnails on Hyprland 0.56. The new screenshot reader is running; the screenshot gesture itself and power-menu coexistence remain untested.

## Next

1. Restructure into shell/platform/device layers with a per-device `device.toml` after shell interaction is validated ([device layout](device-layout.md)).
2. Replace wvkbd with a programmable Quickshell keyboard panel.
3. Correct the phone clock and verify persistence across reboots.

## Later

- Wi-Fi, audio, battery gauge, suspend, and thermals under load.
- A deliberate persistent install to userdata.
- Phone agent workflows (sign-in, network reachability, and disk space).
