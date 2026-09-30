#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BASE_IMAGE=${BASE_IMAGE:?set BASE_IMAGE to the verified 200ms-reset EBBG kernel/DTB image}
MODULE=${MODULE:?set MODULE to the verified EBBG touch module}
FIRMWARE=${FIRMWARE:?set FIRMWARE to the directory containing novatek_ts_ebbg_fw.bin}
EXPECTED_BASE_SHA256=${EXPECTED_BASE_SHA256:?set EXPECTED_BASE_SHA256 to the reviewed base image hash}
EXPECTED_MODULE_SHA256=${EXPECTED_MODULE_SHA256:?set EXPECTED_MODULE_SHA256 to the reviewed module hash}
OUT=${OUT:-$ROOT/out/touch-ram-trial}
TREE="$OUT/initramfs"
RAMDISK="$OUT/willow-touch-ramdisk.cpio.gz"
BASE_RAMDISK="$OUT/base-ramdisk.cpio.gz"
BASE_INIT="$OUT/base-init"
IMAGE="$OUT/boot-willow-kernel-ebbg-fifo-qup-sleep-panel-reset-200ms-touch-ebbg.img"

test -s "$BASE_IMAGE"
test -s "$MODULE"
test -s "$FIRMWARE/novatek_ts_ebbg_fw.bin"
test "$(sha256sum "$BASE_IMAGE" | cut -d' ' -f1)" = "$EXPECTED_BASE_SHA256"
test "$(sha256sum "$MODULE" | cut -d' ' -f1)" = "$EXPECTED_MODULE_SHA256"
test "$(modinfo -F vermagic "$MODULE" | cut -d' ' -f1)" = 7.2.0-willow+

mkdir -p "$OUT"
rm -rf "$TREE"
python3 - "$BASE_IMAGE" "$BASE_RAMDISK" <<'PY'
import struct
import sys

page = 4096
data = open(sys.argv[1], "rb").read()
assert data[:8] == b"ANDROID!"
ksize = struct.unpack_from("<I", data, 8)[0]
rsize = struct.unpack_from("<I", data, 16)[0]
rstart = page + ((ksize + page - 1) // page) * page
open(sys.argv[2], "wb").write(data[rstart:rstart + rsize])
PY
mkdir -p "$TREE"
(cd "$TREE" && gzip -dc "$BASE_RAMDISK" | cpio -idm --quiet)
gzip -dc "$BASE_RAMDISK" | cpio -i --to-stdout init 2>/dev/null > "$BASE_INIT"
python3 - "$BASE_INIT" "$ROOT/boot/init" <<'PY'
import sys

base = open(sys.argv[1], "rb").read()
source = open(sys.argv[2], "rb").read()
marker = b"# Bind a visible host USB-network gadget before handing over to systemd.\n"
block = (b"# Load the trial touch module only after the selected root is mounted. Its\n"
         b"# EBBG firmware is built into the matching RAM-boot kernel image.\n"
         b"TOUCH=$(cmdopt willow_touch)\n"
         b"if [ \"$TOUCH\" = \"ebbg-module\" ]; then\n"
         b"  if [ \"$ROOTPATH\" = \"/var/lib/willow-lite-trial\" ] && [ -s /lib/modules/novatek-nt36672a-spi.ko ]; then\n"
         b"    if insmod /lib/modules/novatek-nt36672a-spi.ko; then\n"
         b"      crumbs \"touch module loaded after selecting $ROOTPATH\"\n"
         b"    else\n"
         b"      crumbs \"touch module load failed\"\n"
         b"    fi\n"
         b"  else\n"
         b"    crumbs \"touch module skipped (trial root or module missing)\"\n"
         b"  fi\n"
         b"fi\n\n")
assert base.count(marker) == 1
assert source.count(block) == 1, "source init must contain exactly one guarded touch block"
if base.count(block) == 1:
    assert source == base, "init differs from base beyond its single guarded touch block"
else:
    assert base.count(block) == 0, "base init has a partial or duplicate touch block"
    assert source == base.replace(marker, block + marker, 1), "init differs beyond the guarded touch load"
PY
install -m 0755 "$ROOT/boot/init" "$TREE/init"
install -D -m 0644 "$MODULE" "$TREE/lib/modules/novatek-nt36672a-spi.ko"
find "$TREE" -exec touch -h -d @0 {} +
("$TREE/bin/busybox" --list | grep -x insmod >/dev/null)
(cd "$TREE" && find . -print0 | sort -z | cpio --null -o -H newc --reproducible 2>/dev/null | gzip -9 -n > "$RAMDISK")

BASE_IMAGE="$BASE_IMAGE" RAMDISK="$RAMDISK" IMAGE="$IMAGE" FIRMWARE="$FIRMWARE/novatek_ts_ebbg_fw.bin" python3 - <<'PY'
import gzip
import os
import struct

page = 4096
def u32(data, offset):
    return struct.unpack_from("<I", data, offset)[0]

def sections(data):
    assert data[:8] == b"ANDROID!"
    ksize, rsize, dsize = u32(data, 8), u32(data, 16), u32(data, 1648)
    kstart = page
    rstart = kstart + ((ksize + page - 1) // page) * page
    dstart = rstart + ((rsize + page - 1) // page) * page
    assert dstart + dsize <= len(data)
    return (data[kstart:kstart + ksize], data[rstart:rstart + rsize],
            data[dstart:dstart + dsize])

base = open(os.environ["BASE_IMAGE"], "rb").read()
kernel, _, dtb = sections(base)
raw_kernel = gzip.decompress(kernel)
firmware = open(os.environ["FIRMWARE"], "rb").read()
assert raw_kernel.count(firmware) == 1, "EBBG firmware not embedded exactly once in kernel"
ramdisk = open(os.environ["RAMDISK"], "rb").read()
header = bytearray(base[:page])
cmdline = header[64:576].split(b"\0", 1)[0]
cmdline = b" ".join(part for part in cmdline.split() if not part.startswith(b"willow_touch="))
cmdline += b" willow_touch=ebbg-module"
assert len(cmdline) < 512, "kernel command line exceeds boot header capacity"
header[64:576] = cmdline + b"\0" * (512 - len(cmdline))
struct.pack_into("<I", header, 16, len(ramdisk))
pad = lambda data: data + b"\0" * ((-len(data)) % page)
with open(os.environ["IMAGE"], "wb") as image:
    image.write(header)
    image.write(pad(kernel))
    image.write(pad(ramdisk))
    image.write(pad(dtb))

result = open(os.environ["IMAGE"], "rb").read()
new_kernel, new_ramdisk, new_dtb = sections(result)
assert new_kernel == kernel, "kernel changed"
assert new_dtb == dtb, "DTB changed"
assert gzip.decompress(new_ramdisk) == gzip.decompress(ramdisk)
assert b"willow_touch=ebbg-module" in result[64:576]
print(f"kernel={len(kernel)} ramdisk={len(ramdisk)} dtb={len(dtb)} image={len(result)}")
print("EBBG firmware is embedded in the unchanged kernel; only the initramfs and touch boot flag changed")
PY

gzip -dc "$RAMDISK" | cpio -it 2>/dev/null | grep -x 'lib/modules/novatek-nt36672a-spi.ko' >/dev/null
sha256sum "$MODULE" "$FIRMWARE/novatek_ts_ebbg_fw.bin" "$RAMDISK" "$IMAGE"
echo "host-only artifact; not booted"
