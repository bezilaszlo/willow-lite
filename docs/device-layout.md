# Device layout

Decision (2026-09-29): three layers plus a manifest per device. Other phones will be supported, and phones may share a chip, so hardware knowledge is stored once at the level it belongs to.

## Layers

```text
shell/                     shared: Quickshell UI, gestures, themes, foot config, helpers, tests
platforms/<soc>/           per chip: GPU and Mesa notes, firmware handling, kernel config, clock/thermal policy
devices/<codename>/        per phone: manifest, panel, touch, backlight, DTB, boot scripts, docs
  device.toml
  files/                   mirrors the root filesystem, installed last
  scripts/  docs/
```

Composition order, later layers win: `shell/` → `platforms/<soc>/` → `devices/<codename>/`. Build, deploy and preview scripts compose the result from the manifest. Nothing outside `devices/` and `platforms/` may hard-code a phone's screen size, scale, output name or input device.

## Manifest

```toml
# devices/willow/device.toml
name = "Xiaomi Redmi Note 8"
codename = "willow"
platform = "sm6125"

[display]
output = "DSI-1"
width = 1080
height = 2340
scale = 2          # logical 540x1170

[input]
touch = "auto"     # or an evdev name; the gesture daemon and compositor map it to the output

[packages]
extra = []

[boot]
method = "fastboot-ram"
root = "/var/lib/willow-lite-trial"
```

The shell reads `display` values (logical size, scale) for edge-band sizes, overview layout and preview resolution. Platform manifests (`platforms/<soc>/platform.toml`) list GPU driver, required firmware and packages.

## Where a file belongs

| Kind of thing | Layer |
|---|---|
| QML, gestures, screenshot and back logic, foot config, themes, compositor config templates | shell |
| Mesa/Freedreno or Panfrost setup, firmware package lists, clock and thermal policy, kernel config shared by the chip | platform |
| Panel size, scale, output name, touch firmware, backlight service, DTB and boot image scripts, autologin quirks | device |

When unsure, put it in the device layer and move it to the platform once a second phone on the same chip needs it.

## Migration from today's tree

| Today | Target |
|---|---|
| `device/home/moarchy/.config/{quickshell,foot}`, sway or Hyprland config templates, `device/usr/local/bin` gesture scripts | `shell/` (compositor config rendered from the manifest) |
| GPU and firmware notes, `packages.txt` GPU parts | `platforms/sm6125/` |
| `device/etc/systemd/system/willow-backlight.service`, hostname, network unit, `scripts/build-*-boot.sh`, `boot/init`, `device/codex-release.txt` split as needed | `devices/willow/` |
| `scripts/preview-*.sh`, `preview/` | stay in `scripts/`, take size and scale from a chosen manifest |

The move happens once, in one commit, after the gesture branches and the Hyprland work are merged, so it does not conflict with them. Until then new device-specific values should be easy to lift out: keep them in one place, not scattered through QML.
