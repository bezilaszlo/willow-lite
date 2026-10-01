# Gestures

The touchscreen is mapped to the single display. Sway's `bindgesture` is touchpad-only, so gestures are handled by Quickshell surfaces and a small evdev daemon. Any compositor change must keep this behavior.

| Gesture | Behavior | Status |
|---|---|---|
| Exactly three fingers down | Save a full-screen PNG to `~/Pictures/Screenshots/`, flash the screen, show a "Screenshot saved" notice. One, two, or four fingers do not trigger it. | User confirmed screenshot worked; finger-count exclusions unverified |
| Pull from the left or right edge | Cancellable Back. See below. | User confirmed one left-edge swipe worked; cancel/right-edge behavior unverified |
| Swipe up from the bottom edge | Open the running-app selector; its panel follows the finger. Tap a card to focus it, or swipe that card up to close it. Choose Home to return to the launcher. | The first strip sat above wvkbd. It is now a 30px Overlay at the physical bottom above Top-layer wvkbd; its area overlaps the keyboard's bottom 30px. Physical swipe and bottom-row key access retest pending |

## Back

Back is a live, cancelable pull:

1. Pull inward from the left or right edge. The pull can start anywhere along the edge, and the indicator sits at the height where the finger started.
2. An animated indicator grows with the finger. Past the threshold (at least 72 px inward, mostly horizontal) it visibly arms, for example with a stretch and color change, so release is known to trigger Back.
3. Moving the finger back below the threshold disarms it and the indicator eases away. Lifting then does nothing.
4. Lifting while armed triggers Back and plays a short confirm animation.

What Back does, in order: hide the on-screen keyboard if shown; otherwise close the top visible panel (overview, Apps); otherwise send Escape to the focused app. It never closes a window.

## Overview

A horizontal carousel of running-app cards with per-window thumbnails. Tap a card to switch, swipe a card up to close it, and use Close all to clear everything. Home returns to the launcher without closing windows. Thumbnails come from per-window capture (`grim -T`) on Sway or Quickshell's `ScreencopyView` on Hyprland.

The bottom handle opens the selector from either the launcher or an app. While the selector is open, swipe down from the handle or use edge Back to dismiss it. The card gesture closes only the card being swiped; Home never terminates apps.

## Porting between Sway and Hyprland

The gesture branches were written for Sway. Most of their code uses Wayland protocols that both compositors support; only the items below are Sway-specific. Keep each compositor call in one small function so it can be swapped.

| Branch feature | Sway-specific part | Hyprland equivalent (0.56, Lua config) |
|---|---|---|
| Three-finger screenshot | Started with `exec` in the Sway config. The evdev reader and `grim` need no compositor support; grim uses wlr-screencopy, which Hyprland also offers. | `hl.exec_cmd(...)` inside `hl.on("hyprland.start", ...)` in `willow.lua` |
| Back gesture | `wtype -k Escape` (virtual-keyboard, works on both). The keyboard is detected from the band's height, which relies on the compositor shrinking non-exclusive layer surfaces by other exclusive zones. | Hyprland arranges layers the same way, but this is not yet measured with wvkbd on Hyprland. `hyprctl -j layers`, which lists the `wvkbd` namespace, is a direct test. |
| Overview | `import Quickshell.I3`, `swaymsg -r -t get_tree` for the window list and focus order, `I3.dispatch("[con_id=N] focus")` and `"[con_id=N] kill"`, thumbnails from `grim -T <foreign-toplevel id>` | `import Quickshell.Hyprland`: `Hyprland.toplevels` (focus history via `HyprlandToplevel.lastIpcObject.focusHistoryID`), `Hyprland.dispatch('hl.dsp.focus({ window = "address:0x…" })')` and `'hl.dsp.window.close({ window = "address:0x…" })'`, and thumbnails from `ScreencopyView { captureSource: hyprlandToplevel.wayland; live: false }` over Hyprland's toplevel export |
| Apps switcher on `main` | `Toplevel.activate()` does nothing on Sway 1.12 | It does nothing on Hyprland 0.56 either, even with `misc.focus_on_activate`. Focus with the `hl.dsp.focus` dispatch above. `Toplevel.close()` works. |

Checked on the phone under Hyprland: `hl.dsp.focus({ window = "address:0x…" })` switches the focused window. `Toplevel.close()` closes it. `Hyprland.toplevels` lists the same windows as `ToplevelManager`, each with a non-null `.wayland` toplevel for capture (this needs `HYPRLAND_INSTANCE_SIGNATURE`, which the session sets). The `ScreencopyView` thumbnails themselves are not built or measured yet.

Hyprland 0.56 rejects `hyprctl keyword` under a Lua config; runtime changes go through `hyprctl eval 'hl…'` or `hyprctl dispatch 'hl.dsp…'`. A Hyprland DPMS off/on re-enables DSI and can leave this phone's panel black, so a gesture must never use it.

## Open points

- Feel tuning with real fingers: edge band width (24 px), Back threshold (72 px), and bottom gesture travel.
- The bottom strip and side Back strips overlap at the corners.
- Physical validation remains pending for screenshot, Back, selector, card dismissal, launcher actions, and keyboard interaction after shell reload.
