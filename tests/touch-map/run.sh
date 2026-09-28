#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

clang -fsyntax-only -DWILLOW_TOUCH_MAP_USE_SYSTEM_LIBINPUT \
  -Wall -Wextra -Werror "$ROOT/device/touch-map/willow-touch-map.c"
cc -fPIC -shared -o "$TMP/libwillow-touch-mock.so" \
  "$ROOT/tests/touch-map/mock-libinput.c"
cc -o "$TMP/recorded-taps" "$ROOT/tests/touch-map/recorded-taps.c" \
  -L "$TMP" -lwillow-touch-mock -Wl,-rpath,"$TMP" -lm
cc -fPIC -shared -O2 -DWILLOW_TOUCH_MAP_USE_SYSTEM_LIBINPUT \
  -Wall -Wextra -Werror -o "$TMP/willow-touch-map-host.so" \
  "$ROOT/device/touch-map/willow-touch-map.c"
LD_PRELOAD="$TMP/willow-touch-map-host.so" "$TMP/recorded-taps"
