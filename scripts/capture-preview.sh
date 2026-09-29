#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
display_file="$ROOT/out/preview-wayland-display"
test -s "$display_file" || { echo "Start scripts/preview-phone.sh first" >&2; exit 1; }
preview_display=$(cat "$display_file")
test -S "${XDG_RUNTIME_DIR:?}/$preview_display" || { echo "Preview Wayland socket is gone" >&2; exit 1; }

env WAYLAND_DISPLAY="$preview_display" grim "$ROOT/out/phone-preview.png"
printf '%s\n' "$ROOT/out/phone-preview.png"
