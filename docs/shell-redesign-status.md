# Shell redesign implementation status

This task-owned status note tracks source, preview, deployment, and physical validation separately. The user-authored design brief and mockup remain the source of truth.

## Current state

- The redesigned QML shell is landed on `main` at `a55c54f` and deployed on 2026-10-01. Phone Quickshell PID 448 is still running; the deployed controller hash is `9914f539f7862fe0b295afc9c4cbb72a883a5eefbc9943ad049ae8d10351ce2f`. The exact staged deployment and post-deploy observations are recorded in ignored artifact `out/redesign-deploy-20261001/post-deploy.txt`.
- The deployed build has the verified 30 px physical-bottom gesture strip and wvkbd bottom margin. Keep `willow-sway.qml` unchanged. ThemeStore and the instantiable Theme facade preserve that Sway QML contract.
- Combined controller previews load under the isolated headless Sway compositor with no QML errors. The preview guards actions and status polling; host brightness, network, keyboard state, apps, and screenshot operations are not used as device state. The live phone has status/back/edge layer surfaces, and its Quickshell journal query was empty after deployment.
- Captures are in the task worktree's ignored `out/` directory: `integrated-preview-home.png`, `integrated-preview-drawer.png`, `integrated-preview-control.png`, and `integrated-preview-recents.png`. Home/drawer/CC use the integrated controller; the phone recents state is empty on the preview host. `preview-recents-final.png` renders the production card delegate with inert preview-only labels to inspect the 0.62 scale, 28 px gap, and newest centered card. The drawer inventory is from this preview host and is not a claim about installed phone apps.
- Lock visuals use the same production `LockScreenContent` component in a normal host preview PanelWindow, not WlSessionLock: `out/preview-lock-final.png` (copied from the lock helper's reviewed capture). Neither host screenshot proves phone display or secure-lock behavior.
- The brightness helper's bounded phone prerequisite was completed and restored: `/sys/devices/platform/soc@0/4ac0000.geniqup/4a84000.i2c/i2c-0/0-0036/backlight/ktd3136-backlight/brightness`, mode `0644 root:root`, maximum/current/actual `2047`; two `0/0` samples were restored to `2047/2047` and SSH remained responsive. Physical darkness, touch wake, energy use, and crash/restart lock recovery remain unverified.
- The task backup is retained at `/home/moarchy/.local/state/willow/redesign-backup-20261001T140840Z`; the latest exact-file rollback snapshot is `/home/moarchy/.local/state/willow/deploy-backups/session.DvKJhN`. Hyprland now reports `misc:allow_session_lock_restore=true`; current brightness is `2047/2047`, the lock marker is absent, and the session remains unlocked. The keyboard remains in manual mode with the existing 30 px margin; its current state was hidden at the post-deploy check. One Quickshell-owned handle-power-key inhibitor is active; a prior duplicate whose owner PID was gone was removed by its exact process tree. This confirms the current count only, not cleanup across future shell reloads.
- Phone status currently reports battery unavailable and USB networking at `172.16.42.1`. The measured 540×1170 layer layout includes a 40 px status row and a 30 px gesture strip at y=1140; no physical-screen, gesture, or lock behavior is inferred from layer data.

## Lock brightness recovery

If the device is reachable over SSH and its panel is dark after a failed lock attempt, the validated baseline restore command is:

```sh
printf '2047\n' | ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=4 moarchy@172.16.42.1 'sudo -n /usr/bin/tee /sys/devices/platform/soc@0/4ac0000.geniqup/4a84000.i2c/i2c-0/0-0036/backlight/ktd3136-backlight/brightness >/dev/null'
```

`2047` is the measured pre-trial brightness and should only be used while it remains the intended restore value. This writes only the KTD3136 brightness attribute; it does not change DPMS or display-link state. The task's lock helper uses `/run/user/1000/willow-lock-brightness` to preserve a dim operation's prior value. A separately triggered crash-watchdog restore path has not been observed.

## Required closeout gates

1. Root reviewed the Home, drawer, Control Center, recents, and lock previews against the user brief and mockup; the redesigned shell is deployed without restarting Hyprland or the kernel.
2. Ask the user to verify the phone display and physical touch behavior. A short power press must acquire the real `WlSessionLock`, dim through the brightness helper, and remain locked; a single tap should restore brightness, and an upward swipe should unlock. If lock acquisition fails, preserve the marker and use SSH to restore the saved brightness.
3. Verify the screenshot gesture is suppressed while securely locked, and confirm display behavior, power hold/menu, bottom/side/top gestures, theme persistence, app launch, and keyboard mode interactively. Hardware auto-rotation remains unavailable; battery power draw is unknown because `current_now` is unavailable.

## Unverified

- Physical display visibility, gesture recognition, theme switching/persistence, app launch/drawer behavior, and the physical keyboard/margin interaction after this deployment.
- Secure `WlSessionLock` acquisition, visible/dark appearance, tap-to-wake, swipe-to-unlock, screenshot suppression during lock, and lock crash/restart recovery. The bounded brightness helper and restoration succeeded earlier, but no lock cycle has been triggered after deployment.
- Cleanup of the power-button inhibitor across future Quickshell reloads. Exactly one blocker was present after exact dead-owner cleanup; repeated reload cleanup is not established.
- Battery power draw while the screen is black; the hardware's `current_now` field is known to be unavailable.
