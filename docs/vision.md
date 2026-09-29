# Vision

Willow Lite explores what a phone interface looks like when it is designed for a touchscreen first and for an agent-assisted workflow second. It is deliberately not a copy of Android or iOS.

## Principles

- **Minimalist.** Few elements, strong hierarchy, generous space. Every control must earn its place.
- **Innovative, experimental.** Prefer new interaction ideas over convention, and keep them cheap to change. The shell is QML files that reload live.
- **Familiar only where it helps.** Some gestures follow Android because muscle memory is free (Back, screenshot, recents). The look and the rest of the interaction model are ours.
- **Precise feedback.** Gestures are live and cancelable: the interface shows what will happen before the finger lifts.
- **Cheap to draw.** Animations and effects must hold their frame rate on the Adreno 610; measure, don't assume.
- **Sway-independent shell.** Keep compositor-specific calls (`swaymsg`, `Quickshell.I3`, or Hyprland equivalents) in one small layer so the UI ports easily.

## Visual direction (to be designed)

The current UI is a functional placeholder. A redesign covers: a design language (palette, type, spacing, corner radius, blur or glass where affordable), a status bar with clock, battery and connectivity, a home surface and launcher, the overview cards, transitions, and gesture feedback. It follows the principles above and reuses ideas from the reference repos ([references.md](references.md)). Screenshots are reviewed before anything is deployed to the phone.
