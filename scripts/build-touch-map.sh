#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/out/willow-touch-map.so"
TOOLCHAIN="$ROOT/out/toolchain/usr"

if ! command -v ld.lld >/dev/null && [ -x "$TOOLCHAIN/bin/ld.lld" ]; then
  export PATH="$TOOLCHAIN/bin:$PATH"
  export LD_LIBRARY_PATH="$TOOLCHAIN/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

command -v clang >/dev/null
command -v ld.lld >/dev/null
mkdir -p "$ROOT/out"
clang --target=aarch64-unknown-linux-gnu -fuse-ld=lld -fPIC -shared -O2 -nostdlib \
  -Wall -Wextra -Werror \
  -Wl,-soname,willow-touch-map.so \
  -o "$OUT" "$ROOT/device/touch-map/willow-touch-map.c"

file "$OUT"
