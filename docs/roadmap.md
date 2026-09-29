# Roadmap

Updated 2026-09-29.

## Done

- Trial boot with Sway, Quickshell, foot, wvkbd, SSH, native AArch64 Codex (`--no-daemon` wrapper).
- Phone-sized desktop preview and screenshot capture.
- Apps overview, edge-swipe Back, three-finger screenshot (built on separate branches, not yet merged).
- GPU audit: the Adreno 610 stack is healthy and composites on the GPU under both compositors ([hardware.md](hardware.md#gpu)).
- Hyprland 0.56 session beside Sway, selected with `willow-compositor` and falling back to Sway.

## Now

1. **Compositor: Hyprland, with Sway kept as the fallback.** Hyprland runs on the phone at a steady 60 fps. Its panel only lights when it inherits the console's mode ([hardware.md](hardware.md#hyprland-and-the-dsi-panel-willow)), so `willow-session` checks every start. Before Sway's config and the fallback can be removed: test a cold boot straight into Hyprland, see the retry path work once, and ideally fix the panel re-prepare in the kernel.
2. **Merge the three gesture features** and deploy for physical touch testing.
3. **Port gestures** to Hyprland, with the live cancelable Back animation ([gestures.md](gestures.md#porting-between-sway-and-hyprland)). This includes window focus by Hyprland address and `ScreencopyView` thumbnails in the overview.

## Next

0. **Restructure into shell / platforms / devices** with a `device.toml` per phone ([device-layout.md](device-layout.md)), in one commit after the merges above.

4. **Redesign** to the [vision](vision.md): design language, status bar, home and launcher, overview, transitions. Review screenshots before deploying.
5. **Real input model:** replace wvkbd with a programmable Quickshell panel (buttons, modes, contextual options).
6. Fix the phone clock and confirm persistence across reboots.

## Later

- Wi-Fi, audio, battery gauge, suspend and thermals under load.
- A deliberate persistent install to userdata.
- Agent workflows on the phone (Codex sign-in, network reachability, disk space).
