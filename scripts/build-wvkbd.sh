#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PHONE=${PHONE:-moarchy@172.16.42.1}
SSH=(ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
COMMIT=e14b53aff4fd1f471add6b21b3885c2cff945509
SOURCE=${SOURCE:-"$ROOT/out/wvkbd"}
PATCH="$ROOT/device/patches/wvkbd-bottom-margin.patch"
BASE_MAIN_SHA256=0cee9e9f7f1af4d48041933ca1851819fa41f96bb3f6d29627000657b602f659
PATCHED_MAIN_SHA256=787e0a64a64af388a4cd53df306800d307d20104b535efe1d9d3fb73415a27eb
BUILD_ID=$(date -u +%Y%m%dT%H%M%SZ)-$$
REMOTE=${REMOTE:-/tmp/willow-lite-wvkbd-bottom-margin-$BUILD_ID}
TARGET=${TARGET:-/var/lib/willow-lite-wvkbd-bottom-margin-$BUILD_ID}

case "$REMOTE$TARGET" in
    *[!A-Za-z0-9_./-]*|*//*|*..*)
        echo "REMOTE and TARGET must be safe absolute paths without shell metacharacters" >&2
        exit 1
        ;;
esac
case "$REMOTE:$TARGET" in
    /*:/*) ;;
    *) echo "REMOTE and TARGET must be absolute paths" >&2; exit 1 ;;
esac

if [ ! -d "$SOURCE/.git" ]; then
    mkdir -p "$ROOT/out"
    git clone https://github.com/jjsullivan5196/wvkbd.git "$SOURCE"
fi
git -C "$SOURCE" fetch --depth=1 origin "$COMMIT"
git -C "$SOURCE" checkout --detach "$COMMIT"

if [ "$(git -C "$SOURCE" rev-parse HEAD)" != "$COMMIT" ]; then
    echo "wvkbd checkout does not match the pinned source commit" >&2
    exit 1
fi
if ! git -C "$SOURCE" diff --quiet -- . ':!main.c'; then
    echo "unexpected tracked changes outside wvkbd main.c; inspect and preserve them" >&2
    exit 1
fi
if [ -n "$(git -C "$SOURCE" ls-files --others --exclude-standard)" ]; then
    echo "unexpected untracked wvkbd source files; inspect and preserve them" >&2
    exit 1
fi
main_sha256=$(sha256sum "$SOURCE/main.c" | cut -d ' ' -f1)
if [ "$main_sha256" = "$BASE_MAIN_SHA256" ]; then
    git -C "$SOURCE" apply --check "$PATCH"
    git -C "$SOURCE" apply "$PATCH"
    main_sha256=$(sha256sum "$SOURCE/main.c" | cut -d ' ' -f1)
fi
if [ "$main_sha256" != "$PATCHED_MAIN_SHA256" ]; then
    echo "wvkbd main.c differs from both the pinned source and Willow margin patch" >&2
    exit 1
fi

printf 'Pinned source: %s (%s)\nPatched main.c SHA256: %s\nRemote build: %s\nPackage target: %s\n' \
    "$COMMIT" "$BASE_MAIN_SHA256" "$main_sha256" "$REMOTE" "$TARGET"
tar -C "$SOURCE" --exclude=.git --exclude='build-*' \
    --exclude=wvkbd-mobintl --exclude=wvkbd-deskintl -cf - . |
    "${SSH[@]}" "$PHONE" "test ! -e '$REMOTE' && mkdir -m 0700 '$REMOTE' && tar -C '$REMOTE' -xf -"
"${SSH[@]}" "$PHONE" "
  set -eu
  test ! -e '$TARGET'
  pkg-config --exists cairo pangocairo wayland-client xkbcommon
  command -v gcc >/dev/null
  command -v make >/dev/null
  make -C '$REMOTE' wvkbd-mobintl
  sudo install -D -o root -g root -m 0755 '$REMOTE/wvkbd-mobintl' '$TARGET/usr/local/bin/wvkbd-mobintl'
  sudo install -D -o root -g root -m 0644 '$REMOTE/COPYING' '$TARGET/usr/local/share/licenses/wvkbd/COPYING'
  ldd '$TARGET/usr/local/bin/wvkbd-mobintl'
  file '$TARGET/usr/local/bin/wvkbd-mobintl'
"
