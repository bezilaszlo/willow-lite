# Willow screen recording

Use **Record screen** in Control Center to start a private, user initiated recording. The helper is also available as:

```sh
willow-screen-record start [SECONDS]
willow-screen-record status
willow-screen-record stop
```

The default duration is 90 seconds and the hard capture limit is 120 seconds. The recorder gets up to five additional seconds to finalize after the duration limit before the watchdog sends SIGKILL. Capture stops at 100 MiB if reached sooner. Video is written to `~/Videos/Willow/lock-diagnostic-<timestamp>-<unique>.mp4` with owner-only permissions. Recording uses 15 fps H.264 with audio disabled. A start request while the secure-session marker already exists is rejected. A recording started while unlocked continues through a later lock transition only if the compositor's supported screen-capture interface permits it; the helper does not weaken the native lock capture policy. Secure content may therefore be redacted or recording may stop at lock.

The helper prints only newline-separated `key=value` status fields: `state`, `file`, `remaining_seconds`, `max_seconds`, and `secure`. `secure=1` means the shell's session-lock marker currently exists; it does not claim a compositor protocol confirmed capture of protected content. States are `recording`, `idle`, `locked`, and `unavailable`. Starting while already locked exits with status 3; other operational errors exit nonzero. On stop, a bounded Quickshell `eventTimelineJson` snapshot is saved beside the video as `.events.json` when the running Willow shell exposes it. Idle status retains the most recent recording path.

For host-side review, sample one image per second and optionally save up to eight full-size frames around notable times:

```sh
python scripts/analyze-screen-recording.py ~/Videos/Willow/lock-diagnostic-20261001-120000.mp4 --at 12.4 --at 37
```

The analyzer creates up to four compact 30-second contact sheets and a report in a new sibling `*-review` directory. It refuses recordings longer than the helper's bound and will not overwrite an existing review directory. The recording shows compositor output; it cannot establish that the physical panel or backlight was emitting light.
