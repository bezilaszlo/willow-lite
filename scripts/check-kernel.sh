#!/usr/bin/env bash
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
KSRC=${KSRC:-/home/bezi/Work/linux-sm6125}
KOUT=${KOUT:-/home/bezi/Work/linux-sm6125-out}
COMMUNITY=${COMMUNITY:-/home/bezi/Work/moarchy-willow/community-boot}
OUT="$ROOT/out/kernel"
VENV="$ROOT/out/dtschema-venv"
DTBS_CHECK=${DTBS_CHECK:-1}
FAIL=0

row() { printf '%-5s %-22s %s\n' "$1" "$2" "$3"; [ "$1" = FAIL ] && FAIL=$((FAIL + 1)); return 0; }

test -s "$OUT/config" && test -s "$OUT/Image.gz" && test -s "$OUT/willow.dtb" || { echo "no build in $OUT (run scripts/build-kernel.sh)" >&2; exit 1; }

want() {
  local sym=$1 val=$2 have
  have=$(grep -E "^CONFIG_${sym}=" "$OUT/config" | cut -d= -f2)
  [ -z "$have" ] && have=n
  if [ "$have" = "$val" ]; then row PASS "CONFIG_$sym" "$have"; else row FAIL "CONFIG_$sym" "have $have, want $val"; fi
}

echo "== config"
for sym in USB_GADGET USB_CONFIGFS USB_CONFIGFS_ECM USB_CONFIGFS_NCM USB_CONFIGFS_RNDIS USB_CONFIGFS_MASS_STORAGE \
           USB_DWC3 USB_DWC3_QCOM PHY_QCOM_QUSB2 DRM_MSM DRM_MSM_DPU DRM_MSM_DSI DRM_MSM_DSI_14NM_PHY \
           DRM_PANEL_NOVATEK_NT36672A BACKLIGHT_CLASS_DEVICE BACKLIGHT_KTD3136 SPI_QCOM_GENI I2C_QCOM_GENI \
           PSTORE_RAM PSTORE_CONSOLE PSTORE_PMSG SECURITY_LANDLOCK INPUT_UINPUT ARM64_VA_BITS_39 SM_GCC_6125 SM_GPUCC_6125 \
           SM_DISPCC_6125 PINCTRL_SM6125 ARM_QCOM_CPUFREQ_HW QCOM_PD_MAPPER POWER_RESET_QCOM_PON REBOOT_MODE \
           QCOM_WDT SOFTLOCKUP_DETECTOR DETECT_HUNG_TASK PANIC_ON_OOPS NETCONSOLE \
           MMC_SDHCI_MSM EXT4_FS ARM_SMMU DEVTMPFS FRAMEBUFFER_CONSOLE MODULES; do
  want "$sym" y
done
want TOUCHSCREEN_NOVATEK_NT36672A_SPI m
want DEFAULT_HUNG_TASK_TIMEOUT 120
want PANIC_TIMEOUT 30
want BOOTPARAM_SOFTLOCKUP_PANIC 1
want BOOTPARAM_HUNG_TASK_PANIC 1
grep -E -q '^CONFIG_EXTRA_FIRMWARE="novatek_ts_ebbg_fw.bin"' "$OUT/config" && row PASS EXTRA_FIRMWARE "novatek_ts_ebbg_fw.bin" || row FAIL EXTRA_FIRMWARE "EBBG touch firmware not built in"

echo "== community config delta (hardware symbols)"
sort "$COMMUNITY/config" | grep -E '^CONFIG_(QCOM|DRM_MSM|DRM_PANEL_NOVATEK|PHY_QCOM|USB_|SPI_QCOM|I2C_QCOM|PINCTRL_SM|SM_|ARM_QCOM|POWER_RESET|REBOOT|PSTORE|WATCHDOG|ARM_SMMU|MMC_SDHCI|INTERCONNECT_QCOM|COMMON_CLK_QCOM|REGULATOR_QCOM)[A-Z0-9_]*=' > "$OUT/.community-hw"
sort "$OUT/config" | grep -E '^CONFIG_(QCOM|DRM_MSM|DRM_PANEL_NOVATEK|PHY_QCOM|USB_|SPI_QCOM|I2C_QCOM|PINCTRL_SM|SM_|ARM_QCOM|POWER_RESET|REBOOT|PSTORE|WATCHDOG|ARM_SMMU|MMC_SDHCI|INTERCONNECT_QCOM|COMMON_CLK_QCOM|REGULATOR_QCOM)[A-Z0-9_]*=' > "$OUT/.ours-hw"
diff "$OUT/.community-hw" "$OUT/.ours-hw" | grep '^[<>]' > "$OUT/config-delta.txt" || true
row INFO config-delta "$(grep -c '^<' "$OUT/config-delta.txt") community-only, $(grep -c '^>' "$OUT/config-delta.txt") ours-only; see $OUT/config-delta.txt"
grep '^<' "$OUT/config-delta.txt" | sed 's/^< /       community-only: /' | head -20

echo "== Image"
gzip -dc "$OUT/Image.gz" > "$OUT/.Image.check"
python3 - "$OUT/.Image.check" "$COMMUNITY/Image" "$OUT/Image.gz" <<'PY'
import os
import struct
import sys

def hdr(path):
    d = open(path, "rb").read(64)
    return {"magic": d[56:60], "text_offset": struct.unpack_from("<Q", d, 8)[0], "image_size": struct.unpack_from("<Q", d, 16)[0], "flags": struct.unpack_from("<Q", d, 24)[0], "size": os.path.getsize(path)}

fails = 0

def row(level, name, msg):
    global fails
    fails += level == "FAIL"
    print(f"{level:<5} {name:<22} {msg}")

ours, comm = hdr(sys.argv[1]), hdr(sys.argv[2])
row("PASS" if ours["magic"] == b"ARM\x64" else "FAIL", "image magic", repr(ours["magic"]))
row("PASS" if ours["text_offset"] == comm["text_offset"] else "FAIL", "text_offset", f"ours={ours['text_offset']:#x} community={comm['text_offset']:#x}")
row("PASS" if ours["flags"] == comm["flags"] else "FAIL", "image flags", f"ours={ours['flags']:#x} community={comm['flags']:#x} (page size and endianness bits)")
limit = comm["size"] + 3 * 1024 * 1024
row("PASS" if ours["size"] <= limit else "FAIL", "image size", f"ours={ours['size']} community={comm['size']} limit={limit} (fastboot RAM boot layout is tuned to the community size)")
row("INFO", "image.gz size", f"{os.path.getsize(sys.argv[3])} bytes")
sys.exit(fails)
PY
FAIL=$((FAIL + $?))
if ! python3 - "$OUT" <<'PY'
import subprocess, sys
out = sys.argv[1]
d = open(out + "/.Image.check", "rb").read()
sys.exit(0 if d.count(b"novatek_ts_ebbg_fw.bin") >= 1 and b"7.2.0-willow" in d else 1)
PY
then row FAIL image-content "built-in EBBG firmware name or release string missing"; else row PASS image-content "EBBG firmware built in, release 7.2.0-willow"; fi
rm -f "$OUT/.Image.check"

if [ -s "$OUT/novatek-nt36672a-spi.ko" ]; then
  rel=$(cat "$KOUT/include/config/kernel.release")
  vm=$(strings "$OUT/novatek-nt36672a-spi.ko" | grep -m1 '^vermagic=' | cut -d' ' -f1)
  [ "$vm" = "vermagic=$rel" ] && row PASS module-vermagic "$vm" || row FAIL module-vermagic "$vm vs $rel"
else
  row FAIL module "no novatek-nt36672a-spi.ko"
fi

echo "== dtb vs community (loud on board-id and carve-outs)"
python3 "$ROOT/scripts/dtb-compare.py" "$OUT/willow.dtb" "$COMMUNITY/dtb" | tee "$OUT/dtb-compare.txt"
n=$(grep -c '^FAIL' "$OUT/dtb-compare.txt"); FAIL=$((FAIL + n))
if grep -q '^FAIL' "$OUT/dtb-compare.txt"; then
  echo "!!!!! dtb differs from the community dtb in a known hang cause: do not boot until explained !!!!!"
fi

echo "== dtbs_check (our nodes)"
if [ "$DTBS_CHECK" = 1 ] && [ -x "$VENV/bin/dt-validate" ]; then
  if [ -d "$OUT/../toolchain/usr/bin" ]; then export PATH="$PATH:$ROOT/out/toolchain/usr/bin" LD_LIBRARY_PATH="$ROOT/out/toolchain/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
  make_status=0
  PATH="$VENV/bin:$PATH" make -C "$KSRC" O="$KOUT" ARCH=arm64 LLVM=1 CHECK_DTBS=y qcom/sm6125-xiaomi-willow.dtb > "$OUT/dtbs_check.log" 2>&1 || make_status=$?
  ours=$(grep -E 'willow|ginkgo' "$OUT/dtbs_check.log" | grep -E 'panel@0|backlight@36|touchscreen@0|gpu@5900000|gmu@596a000|iommu@59a0000|cpufreq@f521000|watchdog@f017000|restart@440b000|clock-controller@5990000|regulator-lcdb|cpu@' || true)
  total=$(grep -c 'willow' "$OUT/dtbs_check.log" || true)
  if [ -n "$ours" ]; then
    detail="$(echo "$ours" | wc -l) warnings on our nodes (of $total total)"
    [ "$make_status" -eq 0 ] || detail="$detail; make failed (exit $make_status)"
    row FAIL dtbs_check "$detail, see $OUT/dtbs_check.log"
    echo "$ours" | head -20
  elif [ "$make_status" -ne 0 ]; then
    row FAIL dtbs_check "make failed (exit $make_status), see $OUT/dtbs_check.log"
  else
    row PASS dtbs_check "no warnings on our nodes ($total pre-existing total), log $OUT/dtbs_check.log"
  fi
else
  row SKIP dtbs_check "needs $VENV (uv venv + uv pip install dtschema yamllint) or DTBS_CHECK=0"
fi

echo
echo "fail count: $FAIL"
exit $(( FAIL > 0 ))
