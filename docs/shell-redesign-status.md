# Shell redesign implementation status

This task-owned status note tracks source, preview, deployment, and physical validation separately. The user-authored design brief and mockup remain the source of truth.

## Current state

- Source work is in isolated worktree `codex/willow-shell-integration`. The phone still runs the previously working Quickshell and wvkbd; none of this redesign has been deployed.
- The deployed build has the verified 30 px physical-bottom gesture strip and wvkbd bottom margin. Keep `willow-sway.qml` unchanged. ThemeStore and the instantiable Theme facade preserve that Sway QML contract.
- Combined controller previews now load under the isolated headless Sway compositor with no QML errors. Logs show only the expected missing Hyprland IPC signature in preview. The preview guards actions and status polling; host brightness, network, keyboard state, apps, and screenshot operations are not used as device state.
- Captures are in the task worktree's ignored `out/` directory: `integrated-preview-home.png`, `integrated-preview-drawer.png`, `integrated-preview-control.png`, and `integrated-preview-recents.png`. Home/drawer/CC use the integrated controller; the phone recents state is empty on the preview host. `preview-recents-final.png` renders the production card delegate with inert preview-only labels to inspect the 0.62 scale, 28 px gap, and newest centered card. The drawer inventory is from this preview host and is not a claim about installed phone apps.
- Lock visuals use the same production `LockScreenContent` component in a normal host preview PanelWindow, not WlSessionLock: `out/preview-lock-final.png` (copied from the lock helper's reviewed capture). Neither host screenshot proves phone display or secure-lock behavior.
- The brightness helper's bounded phone prerequisite was completed and restored: `/sys/devices/platform/soc@0/4ac0000.geniqup/4a84000.i2c/i2c-0/0-0036/backlight/ktd3136-backlight/brightness`, mode `0644 root:root`, maximum/current/actual `2047`; two `0/0` samples were restored to `2047/2047` and SSH remained responsive. Physical darkness, touch wake, energy use, and crash/restart lock recovery remain unverified.

## Lock brightness recovery

If the device is reachable over SSH and its panel is dark after a failed lock attempt, the validated baseline restore command is:

```sh
printf '2047\n' | ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=4 moarchy@172.16.42.1 'sudo -n /usr/bin/tee /sys/devices/platform/soc@0/4ac0000.geniqup/4a84000.i2c/i2c-0/0-0036/backlight/ktd3136-backlight/brightness >/dev/null'
```

`2047` is the measured pre-trial brightness and should only be used while it remains the intended restore value. This writes only the KTD3136 brightness attribute; it does not change DPMS or display-link state. The task's lock helper uses `/run/user/1000/willow-lock-brightness` to preserve a dim operation's prior value. A separately triggered crash-watchdog restore path has not been observed.

## Required closeout gates

1. Root reviews the five host preview states against `docs/shell-redesign.md` and `docs/mockups/willow-concept.html`; fix any concrete source or fidelity findings.
2. After review, deploy only the changed Quickshell components/helpers in safe order, retaining a backup and SSH recovery. Do not restart the compositor or kernel.
3. Record on-device software observations separately from user-confirmed screen/touch behavior. Physical gestures, usable brightness transition/wake, secure lock, and recovery remain deployment gates. On deployment/reload, verify exactly one task-owned handle-power-key inhibitor; prior Quickshell reloads left orphan inhibitors, so do not claim lifecycle cleanup is fixed without observing it.

## Unverified

- Phone deployment and all physical interaction checks for the redesign.
- Physical gesture recognition, theme persistence on the phone, app launch/drawer behavior, native text-input auto keyboard, and session-lock/unlock behavior.
- Physical darkness/touch wake and session-lock crash/restart recovery on the phone. The bounded sysfs brightness write/readback and restoration succeeded, but secure surface coverage and physical appearance were not observed.
- Cleanup of the power-button inhibitor across Quickshell reloads. Previous sessions showed orphaned blockers; the new controller has not been deployed or checked for this behavior.
- Battery power draw while the screen is black; the hardware's `current_now` field is known to be unavailable.
