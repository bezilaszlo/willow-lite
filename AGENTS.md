# Willow Lite agent guide

Use this guide for work in this repository. Do not edit sibling `moarchy`, `moarchy-willow`, or `omarchy-mobile` repositories. The `device/home/moarchy/` path here is this repo's tracked phone configuration. Kernel tasks may also use the dedicated tree described below.

## Start with the right source

- Read [docs/README.md](docs/README.md) to find the design and architecture notes. Keep lasting product decisions and behavior changes in the relevant doc, and add user-visible changes to [CHANGELOG.md](CHANGELOG.md).
- For kernel work, read [kernel/PROGRESS.md](kernel/PROGRESS.md) first, then [kernel/README.md](kernel/README.md). `PROGRESS.md` is the dated evidence log; distinguish observed facts, user reports, hypotheses, and pending checks. Keep it current after kernel work.
- Read [docs/hardware.md](docs/hardware.md) before display, GPU, backlight, camera, or boot work. Use the dated current-state entries in [kernel/PROGRESS.md](kernel/PROGRESS.md) for the active kernel and boot facts; history can be stale.
- For shell changes, read [docs/shell-redesign-status.md](docs/shell-redesign-status.md) and the relevant design/spec docs such as [docs/shell-redesign.md](docs/shell-redesign.md), [docs/gestures.md](docs/gestures.md), and [docs/screen-recording.md](docs/screen-recording.md). The main controller and components are under `device/home/moarchy/.config/quickshell/`; helpers and deployment inputs are under `device/usr/local/bin/`.

## Phone and display safety

- The user prefers not to handle the phone or move the camera. Do not ask them to do so as a routine diagnostic; report a hang or other stop condition. A boot hang that needs Power hold 10–15 seconds followed by Volume Down + Power ends the trial. Never loop reboots.
- Trial boots are RAM-only through `scripts/boot-trial.sh <image>`. Never run fastboot `flash`, `erase`, or `oem`, and never write a partition. A power-menu Restart is a normal reboot into the installed boot path, not a RAM trial.
- Never unbind/rebind the live backlight I2C or DRM driver; make direct I2C writes; write `fb0/blank`, `bl_power`, or DPMS state; or add a DPMS-off action. These can leave the panel unusable. Strong power actions, lock/unlock gestures, and boot attempts need explicit scope in the active task.
- Host `sudo` is prohibited. Phone `sudo` is permitted for scoped task operations under the user's existing authorization; do not ask again for routine use within that scope. This does not authorize risky display, power, boot, or partition operations without explicit active-task scope. Older blanket “no sudo” notes in `kernel/PROGRESS.md` are superseded only for this distinction. If a host package is missing, report the exact `pacman` command instead of installing it.
- Canonical phone SSH target: `moarchy@172.16.42.1`. Use `ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=4 moarchy@172.16.42.1 ...`; host keys change after RAM boots.
- Never kill a Quickshell process holding `/dev/video0`; that can be the user's open camera preview. If `fuser /dev/video0` reports Quickshell, stop and ask the user to close the preview. Do not move the camera. Screenshots and `grim` show compositor output, not physical panel emission. Only the user and a correctly positioned camera can confirm the panel is lit; use SSH health or spaced frames to distinguish a frozen image.

## Shell deployment and previews

- `scripts/sync-session.sh` is the normal deployment path. It checks that the native session-lock marker is absent, backs up deployed files, restarts only Willow Quickshell, and checks the new engine. If the lock marker exists, stop: do not clear it or use normal sync.
- A secure-preserving manual Quickshell reload while locked is a special, bounded operation. Use it only when the active task contains explicit authorization for that path. Retain the marker, verify `misc:allow_session_lock_restore=true`, back up the exact files, restart only the exact Willow Quickshell instance once, and confirm the native lock reacquired before stopping. Never treat this as standing authorization or unlock through IPC.
- Keep host previews isolated from the user's running preview/compositor. Do not reuse or disrupt the existing preview port (5909). Store generated review artifacts under ignored `out/`; do not mistake preview screenshots for phone evidence.
- Do not automate phone lock, unlock, power-button, or menu gestures unless explicitly scoped. Report keyboard and physical gesture behavior as unverified until the user checks it.

## Agent workflow

- Use the installed `willow-kernel-bringup` and `kernel-development-skills` skills for kernel work, and `omarchy` for shell and display work.
- When acting as orchestrator, delegate hands-on implementation to Luna at high effort, as the user prefers. Keep progress reports compact and preserve durable findings in the relevant docs.
- For behavior changes, get an independent review and use existing bounded runtime checks where applicable. A QML load is not evidence of phone behavior; do not add a test framework by default.
- Do not select Astra or another costly model without explicit user approval.

## Git and authorization

- Preserve unrecognized or user-authored work. Stage only task-owned files; do not include unrelated drafts. Never use `reset --hard`, `clean`, or `restore`, and do not amend commits.
- Local commits in this personal repository are allowed when useful; this supersedes older no-commit notes in `kernel/PROGRESS.md`. Verify both author and committer are `bezilaszlo <bezilaszlo95@gmail.com>`. Do not add agent attribution trailers.
- The personal remote is `git@github.com:bezilaszlo/willow-lite.git`, branch `main`. Push only after an explicit user request or workflow authorization; verify the SSH writer, fetch and check that remote `main` is an ancestor, then use a normal non-forced push.
- Commit scoped, reviewable work with Conventional Commit messages. The only sibling-repository commit exception is local kernel work in the dedicated `linux-sm6125` tree below; never push it.

## Useful entry points

- Kernel: sources are in `/home/bezi/Work/linux-sm6125` on `willow/v7.2`; build output is `/home/bezi/Work/linux-sm6125-out`. Follow `kernel/PROGRESS.md`. Local kernel commits are allowed with the personal `bezilaszlo` identity; never push that repository. Use `scripts/kernel-sync.sh apply`, `scripts/build-kernel.sh`, `scripts/check-kernel.sh`, `scripts/build-trial-boot.sh`, `scripts/build-touch-trial-boot.sh`, `scripts/boot-trial.sh`, and `scripts/verify-boot.sh`. A phone boot requires task-specific authorization even after host checks pass.
- Shell: edit tracked QML and helpers, review the matching docs, then use `scripts/sync-session.sh` only when its unlocked-session guard passes.
- Screen recording: follow [docs/screen-recording.md](docs/screen-recording.md); review recordings with `scripts/analyze-screen-recording.py`. A recording does not prove physical panel output or validate capture of secure content.
