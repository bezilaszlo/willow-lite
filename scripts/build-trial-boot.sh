#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WILLOW=/home/bezi/Work/moarchy-willow
DIAG="$WILLOW/willow-boot/boot-diag-willow.img"
NORMAL=/home/bezi/willow-image/boot.img
OUT="$ROOT/out"
TREE="$OUT/initramfs"
KERNEL=${KERNEL:-}
DTB=${DTB:-}
DEADMAN=${DEADMAN:-240}
USB=${USB:-rndis}
WDT=${WDT:-0}

test -r "$DIAG" && test -r "$NORMAL"
if [ -n "$KERNEL" ]; then
  test -s "$KERNEL" && test -s "${DTB:?DTB is required with KERNEL}" || { echo "KERNEL/DTB not readable" >&2; exit 1; }
  IMAGE_OUT=${IMAGE:-$OUT/boot-willow-kernel.img}
  test "$IMAGE_OUT" != "$OUT/boot-willow-lite.img" || { echo "refusing to overwrite the known-good rollback image" >&2; exit 1; }
else
  IMAGE_OUT="$OUT/boot-willow-lite-tianma.img"
fi
mkdir -p "$OUT"

if [ -d "$OUT/toolchain/usr/bin" ]; then
  export PATH="$PATH:$OUT/toolchain/usr/bin" LD_LIBRARY_PATH="$OUT/toolchain/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
clang --target=aarch64-linux-gnu -O2 -static -nostdlib -ffreestanding -fno-builtin -fno-stack-protector -fno-pic \
  -fuse-ld=lld -Wall -Wl,-z,norelro -o "$OUT/deadman" "$ROOT/boot/deadman.c"

rm -rf "$TREE"
cp -a "$WILLOW/mini/root" "$TREE"
install -m 0755 "$ROOT/boot/init" "$TREE/init"
install -m 0755 "$OUT/deadman" "$TREE/sbin/deadman"
(cd "$TREE" && find . -print0 | sort -z | cpio --null -o -H newc --reproducible 2>/dev/null | gzip -9 -n > "$OUT/willow-lite-ramdisk.cpio.gz")

DIAG="$DIAG" NORMAL="$NORMAL" RAMDISK="$OUT/willow-lite-ramdisk.cpio.gz" IMAGE="$IMAGE_OUT" \
KERNEL="$KERNEL" DTB="$DTB" DEADMAN="$DEADMAN" USB="$USB" WDT="$WDT" python3 - <<'PY'
import gzip
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
own = bool(os.environ["KERNEL"])
if own:
    kernel = open(os.environ["KERNEL"], "rb").read()
    if kernel[:2] != b"\x1f\x8b":
        kernel = gzip.compress(kernel, compresslevel=9, mtime=0)
    dtb = open(os.environ["DTB"], "rb").read()
    assert dtb[:4] == b"\xd0\x0d\xfe\xed", "DTB is not a flattened device tree"
ramdisk = open(os.environ["RAMDISK"], "rb").read()
header = bytearray(diag[:page])
header[64:576] = normal[64:576]
cmdline = header[64:576].split(b"\0", 1)[0].replace(b"panic=0", b"panic=30")
cmdline = cmdline.replace(b"fw_devlink.sync_state=disabled", b"fw_devlink.sync_state=timeout")
cmdline = b" ".join(part for part in cmdline.split() if not part.startswith((b"willow_root=", b"willow_deadman=", b"willow_usb=", b"willow_wdt=", b"oops=", b"panic=", b"watchdog_thresh=", b"hung_task_timeout_secs=", b"softlockup_panic=", b"hung_task_panic=", b"rcu_cpu_stall_timeout=", b"rcupdate.rcu_cpu_stall_timeout=", b"sysctl.kernel.panic_on_rcu_stall=", b"sysctl.kernel.max_rcu_stall_to_panic=", b"netconsole=")))
cmdline += b" willow_root=/var/lib/willow-lite-trial oops=panic panic=30 watchdog_thresh=60 rcupdate.rcu_cpu_stall_timeout=60 sysctl.kernel.panic_on_rcu_stall=1"
if own:
    cmdline += b" willow_deadman=" + os.environ["DEADMAN"].encode() + b" willow_usb=" + os.environ["USB"].encode()
    if os.environ["WDT"] != "0":
        cmdline += b" willow_wdt=" + os.environ["WDT"].encode()
assert len(cmdline) < 512, "cmdline too long"
header[64:576] = cmdline + b"\0" * (512 - len(cmdline))
struct.pack_into("<I", header, 8, len(kernel))
struct.pack_into("<I", header, 16, len(ramdisk))
struct.pack_into("<I", header, 1648, len(dtb))
pad = lambda data: data + b"\0" * ((-len(data)) % page)
with open(os.environ["IMAGE"], "wb") as image:
    image.write(header)
    image.write(pad(kernel))
    image.write(pad(ramdisk))
    image.write(pad(dtb))
img = open(os.environ["IMAGE"], "rb").read()
assert img[:8] == b"ANDROID!"
k, r, d = get(img, 8), get(img, 16), get(img, 1648)
o = page
assert img[o:o + 2] == b"\x1f\x8b" and len(gzip.decompress(img[o:o + k])) > 0
o += ((k + page - 1) // page) * page + ((r + page - 1) // page) * page
assert img[o:o + 4] == b"\xd0\x0d\xfe\xed" and o + d <= len(img)
print(f"kernel={len(kernel)} ramdisk={len(ramdisk)} dtb={len(dtb)} image={os.path.getsize(os.environ['IMAGE'])}")
print("cmdline=" + cmdline.decode())
PY

if [ -z "$KERNEL" ]; then
  "$ROOT/scripts/build-ebbg-trial-boot.sh"
  sha256sum "$OUT/willow-lite-ramdisk.cpio.gz" "$OUT/boot-willow-lite-tianma.img" "$OUT/boot-willow-lite.img"
else
  sha256sum "$OUT/willow-lite-ramdisk.cpio.gz" "$IMAGE_OUT"
  echo "not booted; boot with: scripts/boot-trial.sh $IMAGE_OUT (only after the user allows it)"
fi
