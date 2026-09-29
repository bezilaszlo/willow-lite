# Gestures

The touchscreen is mapped to the single display. Sway's `bindgesture` is touchpad-only, so gestures are handled by Quickshell surfaces and a small evdev daemon. Any compositor change must keep this behavior.

| Gesture | Behavior | Status |
|---|---|---|
| Three fingers down | Save a full-screen PNG to `~/Pictures/Screenshots/`, flash the screen, show a "Screenshot saved" notice. Never triggers with one or two fingers. | Built (Sway), physical test pending |
| Pull from the left or right edge | Back. See below. | Built (Sway), needs the live animation |
| Swipe up from the bottom edge | Open the app overview. The overview follows the finger. Swipe up again to close it. | Built (Sway), physical test pending |

## Back

Back is a live, cancelable pull:

1. Pull inward from the left or right edge. The pull can start anywhere along the edge, and the indicator sits at the height where the finger started.
2. An animated indicator grows with the finger. Past the threshold (at least 72 px inward, mostly horizontal) it visibly arms, for example with a stretch and color change, so release is known to trigger Back.
3. Moving the finger back below the threshold disarms it and the indicator eases away. Lifting then does nothing.
4. Lifting while armed triggers Back and plays a short confirm animation.

What Back does, in order: hide the on-screen keyboard if shown; otherwise close the top visible panel (overview, Apps); otherwise send Escape to the focused app. It never closes a window.

## Overview

A carousel of app cards with a thumbnail of each running app, most recent in the center. Tap a card to switch, swipe a card up to close it, and use Close all to clear everything. Thumbnails come from per-window capture (`grim -T`) on Sway or Quickshell's `ScreencopyView` on Hyprland.

## Open points

- Feel tuning with real fingers: edge band width (24 px), Back threshold (72 px).
- The bottom strip and the side Back strips overlap at the corners.
- The three-finger swipe also reaches the app underneath, since nothing is intercepted.
