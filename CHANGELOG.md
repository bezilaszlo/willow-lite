# Changelog

## 2026-10-02
- Start staging Home when an unlock swipe commits, then release the native session lock only after both the matching Home frame is presented and the lock-cover animation finishes. A timeout stops the animation and keeps the session locked. Full-shell host loading passed and the two-file update was installed through a secure-preserving Quickshell-only reload; the native secure lock reacquired successfully. Physical unlock behavior was pending at deployment.
- After deployment of `f7b8a3f`, the user reported that the physical wake/unlock “looks ok to me.” This is user-reported visual confirmation; no fresh screen recording was captured or reviewed, and secure recording behavior remains unverified.

## 2026-10-01
- Gate native lock release on an actual Home-layer `QQuickWindow.frameSwapped` after Home is staged behind `WlSessionLock`; cancel the handoff if the lock dims or the request becomes stale, and keep the session locked on timeout. The isolated 540×1170 host probe received a rendered Home frame; physical unlock behavior still needs user confirmation.
- Keep the Record button's busy state tied to the user action rather than its background status poll, and reconcile queued taps against fresh recorder state. The full shell loaded in the isolated host compositor and the change is deployed; the user should retest the button.
- Add a user-started, silent screen recorder to Control Center with a 90-second default, 120-second cap, private output, and a bounded event-timeline sidecar. It refuses to start while the native lock is already active; on-device 8-second auto-expiry and manual-stop captures produced valid video, and host analysis parsed 48 timeline events.
- Fix recorder startup detection to find the exact `wf-recorder` child through `ps`, and serialize control requests while retiring dead stale state without losing the latest completed clip.
- Keep Home foreground and block input while native session-lock acquisition is pending, then hand off after `WlSessionLock.secure`. Add a bounded sequence-only event timeline for lock, brightness, power, and terminal/window transitions; physical behavior remains unverified.
- Route a short power-key release to wake a secure dark lock or dim an awake one; retain the two-second hold menu and expose read-only button event/action counters.
- Wake the secure lock on the first single touch, including a swipe, while consuming that contact so it cannot also unlock; add a guarded wake-only recovery IPC.
- Fix secure-lock release using Quickshell's writable lock property and use the documented SSH brightness restore when recovery is needed. Disable the manual brightness slider while the kernel backlight mapping is inconsistent. Physical wake behavior remains unverified.
- Make session sync restart and verify the new Quickshell engine, preserving the current Home view; deployments refuse to run while the session-lock marker exists.
- Deploy the redesigned native QML shell: persistent theme palettes, app drawer, control center, recents cards, gesture feedback, and session-lock visuals. The phone runs the new controller without a compositor/kernel restart; physical gestures and secure lock behavior remain unverified.
- Add a pinned wvkbd bottom-margin option and deploy it with a 30 px gap above the physical-bottom gesture strip. On the current Hyprland session, the keyboard, gesture strip, and tiled-app reservation have been measured with no overlap or extra gap; physical swipe and spacebar retests remain pending.

## 2026-09-29
- Add a Hyprland 0.56 session beside Sway: one app at a time (monocle layout), no gaps, borders, blur or shadows, and short fades. Switch with `willow-compositor hyprland|sway` over SSH. `willow-session` checks each Hyprland start: this phone's panel stays black if Hyprland enables DSI itself, so such a start is retried once and then falls back to Sway. Sessions now run with `LANG=C.UTF-8`, which removes foot's locale warning. The Quickshell shell reaches 60 fps under Hyprland. The desktop preview stays on Sway.
- Audit the Adreno 610 stack. Sway composites on the GPU, clocks scale from 320 to 950 MHz, the GPU suspends when idle, and the GMU `sync_state()` warning is harmless. Install the GPU firmware on the root filesystem with `scripts/install-gpu-firmware.sh` instead of relying only on the initramfs copy. Add `scripts/gpu-bench.sh` and `tests/fps-probe.qml`; glmark2 scores 227 and vkmark 319 at 1080×2340 on Sway (see `docs/hardware.md`).
- Add an Apps switcher to the top bar: one card per open window, tap to switch, swipe sideways or tap the x to close, plus Close all. The bar buttons were narrowed so five fit in 540 px.

- Make `codex` on the phone run with `--no-daemon`, since the native build reports an incomplete package for the shared background server.
- Keep the terminal below the 92 px Quickshell top bar and reduce the on-screen keyboard to a 310 px reserved area while it is visible.
- Add a desktop Sway preview at the phone's logical screen size, running the same Quickshell UI in a tiled native viewer that preserves its portrait aspect ratio, with a local screenshot command.
- Use the EBBG touch firmware in the Willow Lite RAM boot image for this Shenchao device. Physical nine-point and two-finger checks passed without userspace correction.
- Keep the original Tianma boot image as a local recovery artifact. The phone's boot partition is unchanged.
- Remove the provisional libinput touch remap and start Sway normally.

## 2026-09-28

- Boot the first Arch Linux ARM Willow Lite trial with Sway, Quickshell, foot, wvkbd, SSH, and a native AArch64 Codex binary.
