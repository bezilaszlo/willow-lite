#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
KSRC=${KSRC:-/home/bezi/Work/linux-sm6125}
KOUT=${KOUT:-/home/bezi/Work/linux-sm6125-out}
FIRMWARE=${FIRMWARE:-/home/bezi/Work/moarchy-willow/ginkgo-mainline-linux/firmware/ginkgo}
JOBS=${JOBS:-$(nproc)}
OUT="$ROOT/out/kernel"
DTS=qcom/sm6125-xiaomi-willow
MODULE=drivers/input/touchscreen/novatek-nt36672a-spi
MODE=${1:-all}

# Keep generated kernel metadata stable so unchanged objects remain cacheable.
export KBUILD_BUILD_TIMESTAMP=${KBUILD_BUILD_TIMESTAMP:-}

usage() { echo "usage: $0 [all|config|image|dtb|module|clean]" >&2; exit 2; }

TOOLCHAIN="$ROOT/out/toolchain/usr"
if [ -d "$TOOLCHAIN/bin" ]; then
  export PATH="$PATH:$TOOLCHAIN/bin" LD_LIBRARY_PATH="$TOOLCHAIN/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
for tool in clang ld.lld llvm-objcopy llvm-nm llvm-ar flex bison bc; do
  command -v "$tool" >/dev/null 2>&1 || { echo "missing tool: $tool" >&2; exit 1; }
done
test -f "$KSRC/Makefile" || { echo "no kernel tree at $KSRC (run scripts/kernel-sync.sh apply)" >&2; exit 1; }

K=(make -C "$KSRC" O="$KOUT" ARCH=arm64 LLVM=1 -j"$JOBS")
if command -v ccache >/dev/null 2>&1; then K+=(CC="ccache clang"); fi

configure() {
  test -s "$FIRMWARE/novatek_ts_ebbg_fw.bin" || { echo "missing $FIRMWARE/novatek_ts_ebbg_fw.bin" >&2; exit 1; }
  mkdir -p "$KOUT"
  "${K[@]}" -s KCONFIG_ALLCONFIG="$ROOT/kernel/config/community-base.defconfig" alldefconfig
  (cd "$KOUT" && "$KSRC/scripts/kconfig/merge_config.sh" -m -O "$KOUT" "$KOUT/.config" "$ROOT/kernel/config/willow.fragment" >/dev/null)
  "$KSRC/scripts/config" --file "$KOUT/.config" --set-str EXTRA_FIRMWARE_DIR "$FIRMWARE"
  "${K[@]}" -s olddefconfig
  sha256sum "$ROOT/kernel/config/community-base.defconfig" "$ROOT/kernel/config/willow.fragment" > "$KOUT/.willow-config-inputs"
}

need_config() {
  [ -f "$KOUT/.config" ] || return 0
  [ -f "$KOUT/.willow-config-inputs" ] || return 0
  sha256sum -c --quiet "$KOUT/.willow-config-inputs" >/dev/null 2>&1 || return 0
  return 1
}

collect() {
  mkdir -p "$OUT"
  cp "$KOUT/.config" "$OUT/config"
  [ -f "$KOUT/arch/arm64/boot/Image.gz" ] && cp "$KOUT/arch/arm64/boot/Image.gz" "$OUT/Image.gz"
  [ -f "$KOUT/arch/arm64/boot/Image" ] && cp "$KOUT/arch/arm64/boot/Image" "$OUT/Image"
  [ -f "$KOUT/arch/arm64/boot/dts/$DTS.dtb" ] && cp "$KOUT/arch/arm64/boot/dts/$DTS.dtb" "$OUT/willow.dtb"
  [ -f "$KOUT/$MODULE.ko" ] && cp "$KOUT/$MODULE.ko" "$OUT/novatek-nt36672a-spi.ko"
  {
    echo "base: $(cat "$ROOT/kernel/base.txt" 2>/dev/null | tr '\n' ' ')"
    echo "head: $(git -C "$KSRC" rev-parse HEAD) $(git -C "$KSRC" status --porcelain | wc -l) dirty"
    echo "release: $(cat "$KOUT/include/config/kernel.release" 2>/dev/null)"
    (cd "$OUT" && sha256sum Image.gz Image willow.dtb config 2>/dev/null)
  } > "$OUT/build-info.txt"
  ls -l "$OUT"
}

case "$MODE" in
  config) configure ;;
  clean) rm -rf "$KOUT" "$OUT" ;;
  dtb)
    need_config && configure
    "${K[@]}" "$DTS.dtb"
    collect ;;
  image)
    need_config && configure
    "${K[@]}" Image.gz
    "${K[@]}" "$DTS.dtb"
    collect ;;
  module)
    need_config && configure
    "${K[@]}" "$MODULE.ko"
    collect ;;
  all)
    need_config && configure
    time "${K[@]}" Image.gz "$DTS.dtb"
    "${K[@]}" "$MODULE.ko"
    collect ;;
  *) usage ;;
esac
