# Hardware

| | |
|---|---|
| Device | Xiaomi Redmi Note 8, codename `willow` (Shenchao panel variant) |
| SoC | Snapdragon 665 (SM6125) |
| GPU | Adreno 610, Freedreno (`msm` DRM, render node `/dev/dri/renderD128`) |
| Display | 1080×2340 panel; logical 540×1170 at scale 2 |
| Touch | Novatek, needs the EBBG firmware payload in the RAM boot kernel |
| Boot | RAM boot over fastboot; boot partition untouched; root at `/var/lib/willow-lite-trial` |
| Access | USB networking, `moarchy@172.16.42.1`, SSH with sudo |

## GPU

Checked 2026-09-29: a Qt client on the running Sway session reports `freedreno FD610`, OpenGL 4.6, Mesa 26.2.3, so the GPU renders. The kernel log shows the Adreno firmware loading and `gpucc-sm6125 … sync_state() pending due to 596a000.gmu`. The kernel command line has `clk_ignore_unused`. Open questions, under audit: whether the compositor itself composites on the GPU, GPU clock scaling and thermals, Vulkan (Turnip), and the GMU warning. Note that the Mali-400 and GLES 2.0 comments in the moarchy notes describe a different device.

## Quirks

- Hyprland previously lost the backlight on this device; keep the backlight at maximum before tty1 autologin.
- The phone's clock reads Sep 25, so file timestamps are off.
- No uinput in the kernel, so touches cannot be faked on the device.
- The Codex CLI must run with `--no-daemon`; a wrapper at `/usr/local/sbin/codex` does this.
