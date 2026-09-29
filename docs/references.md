# References

Local checkouts (read-only, mine for ideas):

- `/home/bezi/Work/omarchy-mobile`: Omarchy on phones with Hyprland and a touch Quickshell shell, proven on Adreno 640 and Mali-G710. Useful: `docs/mobile-architecture.md`, `overlay/mobile/` (gestures, settings, themes), `devices/*/adapter/`.
- `/home/bezi/Work/moarchy-willow`: the same Redmi Note 8 on Sway, with kernel, firmware and device notes. Useful: `PLAN.md`, `moarchy/` (helpers such as `moarchy-capture-screenshot`), `pkgbuilds/moarchy-device-*`. Its Mali-400 remarks concern another device.

Facts learned from them: Sway's `bindgesture` is touchpad-only; per-window previews via toplevel export exist on Hyprland but not Sway; `Toplevel.activate()` does nothing on Sway 1.12, so use Sway commands by window id.
