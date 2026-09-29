# Roadmap

Updated 2026-09-29.

## Done

- Trial boot with Sway, Quickshell, foot, wvkbd, SSH, native AArch64 Codex (`--no-daemon` wrapper).
- Phone-sized desktop preview and screenshot capture.
- Apps overview, edge-swipe Back, three-finger screenshot (built on separate branches, not yet merged).

## Now

1. **GPU health and Hyprland.** Audit the Adreno stack (firmware, GMU, clocks, thermals, compositor on GPU, Vulkan), benchmark, then decide Sway versus Hyprland. Hyprland gives window animations and native window previews. Reversible over SSH, boot partition untouched.
2. **Merge the three gesture features** and deploy for physical touch testing.
3. **Port gestures** to the chosen compositor, with the live cancelable Back animation ([gestures.md](gestures.md)).

## Next

0. **Restructure into shell / platforms / devices** with a `device.toml` per phone ([device-layout.md](device-layout.md)), in one commit after the merges above.

4. **Redesign** to the [vision](vision.md): design language, status bar, home and launcher, overview, transitions. Review screenshots before deploying.
5. **Real input model:** replace wvkbd with a programmable Quickshell panel (buttons, modes, contextual options).
6. Fix the phone clock and confirm persistence across reboots.

## Later

- Wi-Fi, audio, battery gauge, suspend and thermals under load.
- A deliberate persistent install to userdata.
- Agent workflows on the phone (Codex sign-in, network reachability, disk space).
