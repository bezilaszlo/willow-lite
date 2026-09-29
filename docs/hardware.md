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
| Sway 1.12 | 227 | 319 | 58.6 fps, median 16.67 ms, p95 17.25 ms, max 118 ms, 3 frames over 25 ms | 950 MHz 97.5% | 51.2 / 45.4 °C (idle 34.8 / 35.8 °C) |
| Hyprland 0.56.2 | 202 | not run | 60.0 fps, median 16.68 ms, p95 16.91 ms, max 17.83 ms, 0 frames over 25 ms | 950 MHz 96.3% | 51.2 / 44.5 °C |

Both glmark2 runs used a fullscreen 1080×2340 buffer, which is the correct size. glmark2's scenes are drawn for a landscape window, so on the portrait surface they look zoomed in and cropped at the sides, but the surface fills the screen (`Surface Size: 1080x2340 fullscreen`, checked with a grim screenshot). `refract` runs at 2 fps and `terrain` at 17 fps at this size. Hyprland's 11% lower glmark2 score costs nothing visible: the shell runs at the full 60 Hz with steadier frame times than on Sway. During the Hyprland probe the compositor's own `renderD128` fdinfo grew by 2.1 s of GPU time, and it maps `libgallium` and `dri_gbm`, so it composites on the GPU.

## Hyprland and the DSI panel [willow]

Hyprland 0.56.2 (Arch Linux ARM `extra`, aquamarine 0.15.1) runs with the GPU renderer. On this phone the panel stayed black each time a Hyprland start enabled DSI itself: the takeover modeset, and the start after a blanked fbdev console. It lights when Hyprland inherits the mode that the kernel console set. A Hyprland DPMS off/on also re-enables DSI. Once the user reported the panel relit after one, and once a start with a DPMS cycle ended with an all-black grim frame and no panel check. Treat DPMS as unsafe. This is the "Hyprland lost the backlight" quirk; the backlight itself was never off (`brightness` 2047, `bl_power` 0).

Evidence, 2026-09-29 (user watching the panel, kernel `dmesg`, `grim`):

| Start | DSI enabled by | Panel |
|---|---|---|
| First takeover from Sway | Hyprland, from a running controller (`CLK_CTRL=0x23f VID=0x9130`) | black, while grim showed the full UI |
| After `fb0/blank=4` | Hyprland, from reset (`CLK_CTRL=0x0 VID=0x20008000`) | black (the fbdev blank may also have switched the backlight off) |
| Sway → Hyprland, 4 later Hyprland → Hyprland restarts | only the kernel console restore between sessions (logind, thread `T322`), never Hyprland | lit (three visual checks; none of five batch restarts had a Hyprland DSI enable) |
| Rollback to Sway | kernel console restore | lit |

In every case the panel driver logs `Skipping prepare of already prepared panel` and `Skipping enable of already enabled panel`, so the NT36672A never gets its init sequence after the first boot. An enable through the kernel's fbdev helper still lights it, but a userspace atomic enable does not. The exact difference is not yet known. Sway works because wlroots takes over the console's CRTC without a modeset.

Workaround (in use): `willow-session` sources `~/.config/willow/display-quirks`. That file counts the ginkgo kernel's `ginkgo UEFI DSI` lines in `dmesg` across a Hyprland start. If Hyprland enabled DSI itself, the session exits it cleanly, the kernel console restores the panel, and Hyprland starts once more; a second failure starts Sway. Hyprland must also never switch DPMS off on this phone, so do not add an idle daemon that does. The retry path has not happened in practice yet: every start in testing inherited the console mode on the first try. A cold boot straight into Hyprland has not been tested.

Proposal for a real fix (kernel, not applied): make `panel-tianma-nt36672a` unprepare on DSI disable so the next enable re-sends the init sequence, or let the `ginkgo` DSI enable path re-run the panel's on-commands whenever the host was disabled. Build it as a RAM boot trial image with `scripts/build-trial-boot.sh`. Check it by starting Hyprland after `fb0/blank=4` and by a DPMS off/on; the panel must stay lit in both.

Kernel and boot proposals, not applied (the boot image is unchanged):

1. The command line contains `fw_devlink.sync_state=disabled`, which is not a valid value; the kernel prints `Malformed early option 'fw_devlink.sync_state'` and ignores it. Use `fw_devlink.sync_state=timeout` in `scripts/build-trial-boot.sh` to have the pending `sync_state()` run after the deferred-probe timeout, or drop the token.
2. Add `#cooling-cells` to the CPU nodes and cooling maps for `cpu-thermal` and `cpu0123-thermal` in the DT, so the CPU passive trips throttle `qcom-cpufreq-hw`.

Note that the Mali-400 and GLES 2.0 comments in the moarchy notes describe a different device.

## Quirks

- Hyprland shows a black panel whenever it enables DSI itself (see [Hyprland and the DSI panel](#hyprland-and-the-dsi-panel-willow)). Keep the backlight at maximum before tty1 autologin too.
- The phone has no RTC time and no network time, so the clock restarts from an old date after boot. Set it from the host (`sudo date -u -s …`) before pacman, because package signatures can otherwise be dated in the future.
- The phone has no internet route. pacman works through a reverse SOCKS tunnel: `ssh -N -R 127.0.0.1:1080 moarchy@172.16.42.1` on the host, then `sudo env all_proxy=socks5h://127.0.0.1:1080 pacman --disable-sandbox …` on the phone. The kernel lacks Landlock, so pacman's download sandbox must be disabled.
- No uinput in the kernel, so touches cannot be faked on the device.
- The Codex CLI must run with `--no-daemon`; a wrapper at `/usr/local/sbin/codex` does this.

### Cold boot check (2026-09-29)

A RAM boot straight into Hyprland: the first start enabled the display itself, `willow-session` stopped it cleanly, the retry inherited the console mode and was healthy, and the panel was lit (visually confirmed). This exercised the retry path once. One boot only; repeat before removing Sway.
