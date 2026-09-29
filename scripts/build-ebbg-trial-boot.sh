#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SOURCE="$ROOT/out/boot-willow-lite-tianma.img"
TARGET="$ROOT/out/boot-willow-lite.img"
FIRMWARE=/home/bezi/Work/moarchy-willow/ginkgo-mainline-linux/firmware/ginkgo

test -s "$SOURCE"
test -s "$FIRMWARE/novatek_ts_tianma_fw.bin"
test -s "$FIRMWARE/novatek_ts_ebbg_fw.bin"

SOURCE="$SOURCE" TARGET="$TARGET" FIRMWARE="$FIRMWARE" python3 - <<'PY'
from pathlib import Path
import gzip
import hashlib
import os
import struct

page = 4096
source = Path(os.environ["SOURCE"]).read_bytes()
firmware = Path(os.environ["FIRMWARE"])
tianma = (firmware / "novatek_ts_tianma_fw.bin").read_bytes()
ebbg = (firmware / "novatek_ts_ebbg_fw.bin").read_bytes()
assert len(tianma) == len(ebbg), "firmware size mismatch"
assert source[:8] == b"ANDROID!", "not an Android boot image"

kernel_size = struct.unpack_from("<I", source, 8)[0]
ramdisk_size = struct.unpack_from("<I", source, 16)[0]
dtb_size = struct.unpack_from("<I", source, 1648)[0]
aligned = lambda size: (size + page - 1) // page * page
kernel_start = page
ramdisk_start = kernel_start + aligned(kernel_size)
dtb_start = ramdisk_start + aligned(ramdisk_size)
assert dtb_start + dtb_size <= len(source), "truncated boot image"
kernel = gzip.decompress(source[kernel_start:kernel_start + kernel_size])
assert kernel.count(tianma) == 1, "Tianma firmware is not unique in the kernel"
assert kernel.count(ebbg) == 0, "EBBG firmware already present in the kernel"

candidate = kernel.replace(tianma, ebbg, 1)
new_kernel = gzip.compress(candidate, compresslevel=9, mtime=0)
header = bytearray(source[:page])
struct.pack_into("<I", header, 8, len(new_kernel))
pad = lambda data: data + b"\0" * ((-len(data)) % page)
ramdisk = source[ramdisk_start:ramdisk_start + ramdisk_size]
dtb = source[dtb_start:dtb_start + dtb_size]
target = Path(os.environ["TARGET"])
target.write_bytes(bytes(header) + pad(new_kernel) + pad(ramdisk) + pad(dtb))
assert gzip.decompress(new_kernel) == candidate
print(f"EBBG RAM boot: {target} ({target.stat().st_size} bytes)")
print(f"Kernel SHA-256: {hashlib.sha256(new_kernel).hexdigest()}")
print("The Tianma recovery image remains beside it. No partition is flashed by this script.")
PY
