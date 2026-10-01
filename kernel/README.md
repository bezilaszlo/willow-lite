# Willow kernel

Mainline Linux v7.2 plus a small patch series for the Redmi Note 8T (willow, SM6125). The kernel tree is not stored here: `base.txt` pins the tag and commit, `patches/` holds `git format-patch` output, `config/` holds the configuration. A fresh clone rebuilds the identical tree with `scripts/kernel-sync.sh apply`.

## Current experimental status

Working checkpoint (2026-10-01): the unchanged normal touch-enabled image `out/experimental-checkpoint-20260930/touch-enabled/boot-willow-kernel-ebbg-fifo-qup-sleep-panel-reset-200ms-touch-ebbg.img` (SHA-256 `d3de161459f9d6bdec1b41db1c8b855f1767b1d998e15977b509baf080c78fca`) was booted twice: first with Hyprland (user observed black after graphical startup), then with the existing Sway compositor selected. The user confirms the Sway panel and GUI are visible and work normally, including touch and keyboard. At 648 s, SSH remained healthy with Sway/Quickshell running, USB RNDIS up, exactly one DCS power-mode line (`0x9c` at 8 s), no post-60 DSI error matches, and empty pstore; the user separately confirmed the panel still worked at that checkpoint. This is one successful Sway boot, not a repeatability claim; the exact 3→6→9 touch matrix and repeat Sway boots are unverified. See `PROGRESS.md` for saved logs and current limits.

Hyprland's black startup remains unresolved. Source shows that `msm_atomic.c` requests a full modeset when CTM changes between absent and present; Aquamarine reported that DSI-1 exposes CTM. A separate diagnostic trial showed a second host-enable/DCS cycle with the user-reported black screen, while the Sway trial had one DCS line and a visible GUI. That supports CTM-triggered modeset as a hypothesis, but does not prove it caused the black output. The diagnostic-only source hunks were removed after the trial; its image and logs remain available. DPMS/blanking and later Hyprland modesets are untested. The measured MDP clock in the black session was 192 MHz (pixel clock 183.025 MHz), correcting an older 160.6 MHz snapshot.

The existing compositor preference is stored at `/home/moarchy/.local/state/willow/compositor`; `willow-session` reads it and runs Sway when the value is `sway`. The current value is `sway`; the previous `hyprland` preference is saved in `out/compositor-before-sway-trial-20261001.txt`. Sway's checked-in output rule is `output DSI-1 scale 2`, with no explicit mode setting. No default-selection code or moarchy configuration was changed.

## Layout

| Path | Content |
|---|---|
| `base.txt` | tag, resolved commit, remote |
| `patches/NNNN-*.patch` | series, applied with `git am` on the base |
| `config/community-base.defconfig` | savedefconfig of the community ginkgo kernel config, converted to v7.2 |
| `config/willow.fragment` | our changes on top of it |

`scripts/build-kernel.sh config` builds `.config` as `alldefconfig` over `community-base.defconfig`, merges `willow.fragment`, sets `EXTRA_FIRMWARE_DIR` and runs `olddefconfig`.

## Workflow

```
scripts/kernel-sync.sh apply            # clone base if needed, git am the series (default tree /home/bezi/Work/linux-sm6125)
scripts/build-kernel.sh [all|image|dtb|module|config|clean]
scripts/check-kernel.sh                 # host-only gates, must pass before any boot
KERNEL=out/kernel/Image.gz DTB=out/kernel/willow.dtb scripts/build-trial-boot.sh
scripts/boot-trial.sh <image>             # verified, logged RAM-only fastboot flow
scripts/kernel-sync.sh squash           # fold fixup! commits
scripts/kernel-sync.sh export           # regenerate patches/ from the branch
```

`scripts/boot-trial.sh` owns both supported entry paths. From SSH it requests one reboot to bootloader and waits at most 30 seconds for the exact phone serial; from fastboot it verifies that same serial. Both paths then reset the bootloader, recheck the serial, and issue one logged `fastboot boot`. Both paths have completed successfully on this phone; the SSH-to-fastboot path was used on 2026-10-01.

`build-kernel.sh dtb` rebuilds only the device tree (seconds). `module` rebuilds `novatek-nt36672a-spi.ko` for `scp` and `insmod`. Output goes to `out/kernel/`; the object tree is persistent in `/home/bezi/Work/linux-sm6125-out`. Keep the same `KSRC` and `KOUT` paths between builds: the persistent object tree avoids recompilation, and ccache can reuse compiler results across invocations. The script defaults `KBUILD_BUILD_TIMESTAMP` to empty for stable build metadata; set it explicitly when a dated build timestamp is needed. Using new isolated source/output paths reduces ccache hits.

Tools: clang, ld.lld, llvm binutils, flex, bison and bc. `ld.lld` and `bc` come from Arch packages extracted into `out/toolchain` (no install, signatures checked); `scripts/build-kernel.sh` appends that directory to `PATH`.

## Series

| Patch | Origin |
|---|---|
| dt-bindings for KTD3136, NT36672A Tianma-ginkgo panel, NT36672A SPI touch | RFC by Yigitcan Kavakli, 2026-09-11, unchanged |
| drm/msm/dpu SM6125 programmable-fetch delay | same RFC, unchanged |
| drm/msm/dsi command/video exclusion, host link vs video enable | same RFC, second one adapted to the v7.2 legacy bridge `.enable` hook |
| drm/panel nt36672a ginkgo mode, `.enable`/`.disable`, `prepare_prev_first` | same RFC, ported to the v7.2 table driver, plus downstream shenchao page 0x23 writes |
| Input novatek-nt36672a-spi | RFC source, hardened locally for firmware bounds, SPI error propagation, and panel-prepare retry |
| backlight ktd3136 (also LM3697) | ginkgo-mainline-linux overlay, the RFC driver does not handle LM3697 |
| pd-mapper sm6125 | ours |
| sm6125 dtsi: cpufreq-hw, Adreno 610 + GPUCC + SMMU, PS_HOLD, disabled APSS watchdog | ours, from the community DT |
| ginkgo common dtsi: display, backlight, touch (RFC), GPU, carve-outs, EBBG firmware name | RFC plus ours |

The RFC patches were recovered from the mail-archive copy of the posting; author address and message ids are recorded in each commit (`Link:`). They are RFC-grade and untested by us on hardware.

The touch source review found unchecked firmware offsets and ignored SPI write errors, and probe could fail before registering its panel follower. The local follow-up validates table and payload ranges before controller I/O, stops on failed writes, and registers the follower before the initial firmware attempt so panel prepare can retry. Input coordinate maxima come from DT (1080×2340 here). On this Shenchao unit, the EBBG touch-enabled RAM trial reached firmware version `0x08`, registered `event3`, and the user confirmed normal taps and keyboard input; the numbered matrix confirmed correct 3→6→9 mapping.

## Config decisions

- Base is the community config, which boots this phone. Everything hardware-relevant stays built in; only the touch driver is a module.
- The production patch/config series includes `novatek_ts_ebbg_fw.bin` for the declared EBBG target. Same-unit community runtime logs later showed a successful request/update of `novatek_ts_tianma_fw.bin`; isolated Tianma trial images therefore override the firmware name and built-in payload. The current QUP-sleep trial uses Tianma firmware. It reached firmware version `0x11` and reset state `0xa1`, but touch response remains unverified pending a user tap.
- Added: Landlock, uinput, pstore console/pmsg, soft-lockup/hung-task/RCU-stall panic handling, `oops=panic`, `panic=30`, `LOCALVERSION=-willow` (fixed release, no `-dirty`). `watchdog_thresh=60` makes a soft lockup panic after roughly 120 seconds; hung-task and RCU stall timeouts are 120 and 60 seconds. Netconsole is built in, but the current config has `CONFIG_NETCONSOLE_DYNAMIC` unset and no static target in the cmdline, so no netconsole target can be activated in this image. A future netconsole setup needs a rebuild with `CONFIG_NETCONSOLE_DYNAMIC=y`, then configfs target creation after initramfs brings up the selected USB gadget as `usb0` (the kernel command line is parsed before that interface exists).
- The touch driver is `m` and is built as a separate host artifact. `scripts/build-touch-trial-boot.sh` packages the verified module in the initramfs, then `boot/init` loads it only when the boot command line opts in with `willow_touch=ebbg-module` and the selected root is `/var/lib/willow-lite-trial`. Supply `BASE_IMAGE`, `MODULE`, `FIRMWARE`, `EXPECTED_BASE_SHA256`, and `EXPECTED_MODULE_SHA256`; output defaults to `out/touch-ram-trial/`. The builder accepts either a base init with exactly one matching guarded touch block or one without it, rejects duplicates/partial variants, and checks that the kernel and DTB remain byte-identical and the EBBG firmware is embedded exactly once. The image is RAM-booted only; it does not flash a partition.
- The APSS watchdog node is disabled in the DT and not petted by default; although the compatible's `qcom,kpss-wdt` fallback matches `QCOM_WDT`, no reset destination has been tested. Pseudo-NMI is also not enabled; it needs `ARM64_PSEUDO_NMI=y` and `irqchip.gicv3_pseudo_nmi=1` and has not been validated on this unit.

## Recovery design

- `boot/init` starts `/sbin/deadman` when the cmdline has `willow_deadman=N`. It listens on tcp/9977, and unless the host connects and sends `ok` within N seconds it calls `reboot(RESTART2, "bootloader")`. It is a static binary that survives `switch_root`.
- `willow_usb=rndis|ecm|ncm` picks the gadget function (default `rndis`, the proven one).
- `willow_wdt=N` pets `/dev/watchdog` from the initramfs with a bite after N seconds. Do not use until a bite has been shown to land in fastboot.
- Observed: a forced panic with `panic=30` reached fastboot by itself in about 38 s; a real hang with `kernel.panic=0` never reset and needed a manual key combination.
