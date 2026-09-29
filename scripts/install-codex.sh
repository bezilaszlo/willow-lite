#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/out/codex"
VERSION=0.158.0
ASSET="codex-aarch64-unknown-linux-musl.zst"
URL="https://github.com/openai/codex/releases/download/rust-v${VERSION}/$ASSET"
SHA256=b57e35821fdba79e175a9d6fec40a88642a39c0e080028a893c7aa79bf333f00
PHONE=${PHONE:-moarchy@172.16.42.1}
REMOTE_ARCHIVE="/tmp/willow-lite-codex-${VERSION}.zst"
REMOTE_BINARY="/tmp/willow-lite-codex-${VERSION}"
TARGET=/var/lib/willow-lite-trial

mkdir -p "$OUT"
curl --fail --location --retry 3 --output "$OUT/$ASSET" "$URL"
printf '%s  %s\n' "$SHA256" "$OUT/$ASSET" | sha256sum --check -
zstd --decompress --force "$OUT/$ASSET" -o "$OUT/codex"
chmod 0755 "$OUT/codex"
readelf -h "$OUT/codex" | grep -q 'Machine:.*AArch64'
qemu-aarch64-static "$OUT/codex" --version

ssh "$PHONE" "test ! -e '$REMOTE_ARCHIVE' && test ! -e '$REMOTE_BINARY' && test ! -e '$TARGET/usr/local/bin/codex'"
scp "$OUT/$ASSET" "$PHONE:$REMOTE_ARCHIVE"
ssh "$PHONE" "sudo zstd --decompress --force '$REMOTE_ARCHIVE' -o '$REMOTE_BINARY' && sudo install -D -o root -g root -m 0755 '$REMOTE_BINARY' '$TARGET/usr/local/bin/codex'"
ssh "$PHONE" "sudo chroot '$TARGET' /usr/local/bin/codex --version"
scp device/usr/local/sbin/codex "$PHONE:/tmp/willow-lite-codex-wrapper"
ssh "$PHONE" "sudo install -D -o root -g root -m 0755 /tmp/willow-lite-codex-wrapper '$TARGET/usr/local/sbin/codex' && rm /tmp/willow-lite-codex-wrapper"
