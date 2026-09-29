# Hardware

| | |
|---|---|
| Device | Xiaomi Redmi Note 8, codename `willow` (Shenchao panel variant) |
| SoC | Snapdragon 665 (SM6125) |
| GPU | Adreno 610, Freedreno (`msm` DRM, render node `/dev/dri/renderD128`) |
| Display | 1080×2340 panel; logical 540×1170 at scale 2 |
| Touch | Needs the EBBG firmware payload in the RAM boot kernel |
| Boot | RAM boot over fastboot; boot partition untouched; root at `/var/lib/willow-lite-trial` |
| Access | USB networking, `moarchy@172.16.42.1`, SSH with sudo |

## GPU

Audited 2026-09-29 on kernel `7.0.0-00002-gcd7710569d75-dirty` (#147) and Mesa 26.2.3. The stack is healthy; no kernel change is needed for the desktop. Labels: **[sm6125]** holds for any SM6125 phone, **[willow]** for this phone only.

- **[sm6125] Driver.** `msm` binds DPU and Adreno 610 (chip id `0x06010000`) on one card: `card0` for KMS, `renderD128` for rendering. `/sys/kernel/debug/dri/0/gpu` shows `gpu-initialized: 1`, `revision: 610 (6.1.0.0)`, and fences retire.
- **[sm6125] GMU.** A610 has no real GMU, only a register wrapper (`596a000.gmu`, `qcom,adreno-gmu-wrapper`) that the Adreno driver maps through `qcom,gmu`. No driver binds it, so `gpucc-sm6125 … sync_state() pending due to 596a000.gmu` is printed and never resolves. It is harmless: the GX and CX GDSCs are `off` whenever the GPU is runtime suspended (`pm_genpd_summary`), and `clk_ignore_unused` already keeps unused clocks on. At idle the GPU is suspended about 95% of the time (66 ms autosuspend).
- **[sm6125] Clocks.** devfreq `simple_ondemand` over 320/465/600/745/820/900/950 MHz, and each OPP votes GPU-to-DDR bandwidth (1.8–6.9 GB/s peak). Under glmark2 the GPU sat at 950 MHz 97.5% of the time, and it idles at 320 MHz.
- **[willow] Firmware.** The GPU needs `qcom/a630_sqe.fw` (linux-firmware's, version ≥ 0x190; the vendor file is too old) and the Xiaomi-signed zap shader `qcom/sm6125/xiaomi/ginkgo/a610_zap.{mdt,b00,b01,b02}` (the DT reserves PIL memory at `0x57515000`). The kernel loads both while still on the RAM boot initramfs (`/lib/firmware`, from `moarchy-willow/mini/root`) and keeps them cached. The trial root had no `/usr/lib/firmware` at all, and `firmware_class.path=/usr/lib/firmware/moarchy-willow` points at a directory that exists only on the old root. `scripts/install-gpu-firmware.sh` installs the same checksummed files under `/usr/lib/firmware/qcom/` on the root, so a later request, such as a driver rebind or a boot without this initramfs, still finds them. This has not been tested by rebinding the driver, which would drop the display.
- **[willow] Compositor.** Sway (wlroots GLES2) holds `card0` as DRM master and renders through `renderD128` with `libgallium` and `dri_gbm`. Its `renderD128` fdinfo accumulates `drm-engine-gpu` time, so composition runs on the GPU, not pixman or llvmpipe. Quickshell renders on the GPU too; foot uses shared-memory buffers, as it always does.
- **[sm6125] Vulkan.** Turnip reports `Turnip Adreno (TM) 610`, Vulkan 1.0.354; `vkcube` and `vkmark` run on Wayland. Nothing in the desktop needs Vulkan; `vulkan-freedreno` is installed only for benchmarks.
- **[willow] Thermals and power.** Zones `cpu-thermal`, `cpu0123-thermal`, `gpu-thermal`, `mapss-thermal`. Only the GPU has a cooling device (devfreq, passive trip at 85 °C). The CPU passive trips at 90 °C have no cooling map, so the CPU is never throttled below the 110 °C `hot` trip. The battery gauge reports voltage but `current_now` is always 0, so power draw cannot be measured on the device.

Measured with `scripts/gpu-bench.sh` (glmark2-es2-wayland, fullscreen, 1080×2340 buffer) and `tests/fps-probe.qml`:

| Session | glmark2 | vkmark | Quickshell probe (540×1170 logical) | GPU clock under load | Max gpu / cpu temperature |
|---|---|---|---|---|---|
| Sway 1.12 | 227 | 319 | 58.6 fps, median 16.67 ms, p95 17.25 ms | 950 MHz 97.5% | 51.2 / 45.4 °C (idle 34.8 / 35.8 °C) |

glmark2's scenes are drawn for a landscape window. On the portrait surface they look zoomed in and cropped at the sides, but the surface does fill the screen (`Surface Size: 1080x2340 fullscreen`, checked with a grim screenshot). `refract` runs at 2 fps and `terrain` at 17 fps at this size.

Kernel and boot proposals, not applied (the boot image is unchanged):

1. The command line contains `fw_devlink.sync_state=disabled`, which is not a valid value; the kernel prints `Malformed early option 'fw_devlink.sync_state'` and ignores it. Use `fw_devlink.sync_state=timeout` in `scripts/build-trial-boot.sh` to have the pending `sync_state()` run after the deferred-probe timeout, or drop the token.
2. Add `#cooling-cells` to the CPU nodes and cooling maps for `cpu-thermal` and `cpu0123-thermal` in the DT, so the CPU passive trips throttle `qcom-cpufreq-hw`.

Note that the Mali-400 and GLES 2.0 comments in the moarchy notes describe a different device.

## Quirks

- Hyprland previously lost the backlight on this device; keep the backlight at maximum before tty1 autologin.
- The phone has no RTC time and no network time, so the clock restarts from an old date after boot. Set it from the host (`sudo date -u -s …`) before pacman, because package signatures can otherwise be dated in the future.
- The phone has no internet route. pacman works through a reverse SOCKS tunnel: `ssh -N -R 127.0.0.1:1080 moarchy@172.16.42.1` on the host, then `sudo env all_proxy=socks5h://127.0.0.1:1080 pacman --disable-sandbox …` on the phone. The kernel lacks Landlock, so pacman's download sandbox must be disabled.
- No uinput in the kernel, so touches cannot be faked on the device.
- The Codex CLI must run with `--no-daemon`; a wrapper at `/usr/local/sbin/codex` does this.
