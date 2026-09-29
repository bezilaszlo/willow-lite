#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WILLOW=/home/bezi/Work/moarchy-willow
DIAG="$WILLOW/willow-boot/boot-diag-willow.img"
NORMAL=/home/bezi/willow-image/boot.img
OUT="$ROOT/out"
TREE="$OUT/initramfs"

test -r "$DIAG" && test -r "$NORMAL"
mkdir -p "$OUT"
rm -rf "$TREE"
cp -a "$WILLOW/mini/root" "$TREE"
install -m 0755 "$ROOT/boot/init" "$TREE/init"
(cd "$TREE" && find . -print0 | sort -z | cpio --null -o -H newc --reproducible 2>/dev/null | gzip -9 -n > "$OUT/willow-lite-ramdisk.cpio.gz")

DIAG="$DIAG" NORMAL="$NORMAL" RAMDISK="$OUT/willow-lite-ramdisk.cpio.gz" IMAGE="$OUT/boot-willow-lite-tianma.img" python3 - <<'PY'
import os
import struct

page = 4096
diag = open(os.environ["DIAG"], "rb").read()
normal = open(os.environ["NORMAL"], "rb").read()
get = lambda data, offset: struct.unpack_from("<I", data, offset)[0]
kernel_size, dtb_size = get(diag, 8), get(diag, 1648)
offset = page
kernel = diag[offset:offset + kernel_size]
offset += ((kernel_size + page - 1) // page) * page
offset += ((get(diag, 16) + page - 1) // page) * page
dtb = diag[offset:offset + dtb_size]
ramdisk = open(os.environ["RAMDISK"], "rb").read()
header = bytearray(diag[:page])
header[64:576] = normal[64:576]
cmdline = header[64:576].split(b"\0", 1)[0].replace(b"panic=0", b"panic=30")
cmdline = b" ".join(part for part in cmdline.split() if not part.startswith(b"willow_root="))
cmdline += b" willow_root=/var/lib/willow-lite-trial"
header[64:576] = cmdline + b"\0" * (512 - len(cmdline))
struct.pack_into("<I", header, 16, len(ramdisk))
pad = lambda data: data + b"\0" * ((-len(data)) % page)
with open(os.environ["IMAGE"], "wb") as image:
    image.write(header)
    image.write(pad(kernel))
    image.write(pad(ramdisk))
    image.write(pad(dtb))
print(f"kernel={len(kernel)} ramdisk={len(ramdisk)} dtb={len(dtb)} image={os.path.getsize(os.environ['IMAGE'])}")
PY
"$ROOT/scripts/build-ebbg-trial-boot.sh"
sha256sum "$OUT/willow-lite-ramdisk.cpio.gz" "$OUT/boot-willow-lite-tianma.img" "$OUT/boot-willow-lite.img"
