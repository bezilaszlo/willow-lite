#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PHONE=${PHONE:-moarchy@172.16.42.1}
COMMIT=e14b53aff4fd1f471add6b21b3885c2cff945509
SOURCE="$ROOT/out/wvkbd"
REMOTE=/tmp/willow-lite-wvkbd-e14b53a
TARGET=/var/lib/willow-lite-trial

if [ ! -d "$SOURCE/.git" ]; then
    mkdir -p "$ROOT/out"
    git clone https://github.com/jjsullivan5196/wvkbd.git "$SOURCE"
fi
git -C "$SOURCE" fetch --depth=1 origin "$COMMIT"
git -C "$SOURCE" checkout --detach "$COMMIT"

tar -C "$SOURCE" --exclude=.git -cf - . | ssh "$PHONE" "test ! -e '$REMOTE' && mkdir -m 0700 '$REMOTE' && tar -C '$REMOTE' -xf -"
ssh "$PHONE" "
  set -eu
  pkg-config --exists cairo pangocairo wayland-client xkbcommon
  command -v gcc >/dev/null
  command -v make >/dev/null
  make -C '$REMOTE' wvkbd-mobintl
  sudo install -D -o root -g root -m 0755 '$REMOTE/wvkbd-mobintl' '$TARGET/usr/local/bin/wvkbd-mobintl'
  sudo install -D -o root -g root -m 0644 '$REMOTE/COPYING' '$TARGET/usr/local/share/licenses/wvkbd/COPYING'
  ldd '$TARGET/usr/local/bin/wvkbd-mobintl'
  file '$TARGET/usr/local/bin/wvkbd-mobintl'
"
