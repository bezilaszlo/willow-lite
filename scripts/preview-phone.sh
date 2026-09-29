#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

command -v sway >/dev/null || { echo "Install Sway with: omarchy pkg add sway" >&2; exit 1; }
command -v qs >/dev/null || { echo "Quickshell (qs) is required" >&2; exit 1; }

parent_display=${WAYLAND_DISPLAY:-}
if [ -z "$parent_display" ]; then
    command -v hyprctl >/dev/null || { echo "Set WAYLAND_DISPLAY to the desktop socket" >&2; exit 1; }
    parent_display=$(hyprctl instances -j | jq -r '.[0].wl_socket // empty')
fi
test -S "${XDG_RUNTIME_DIR:?}/$parent_display" || { echo "Wayland socket not found: $parent_display" >&2; exit 1; }

env WAYLAND_DISPLAY="$parent_display" XDG_SESSION_TYPE=wayland WLR_BACKENDS=wayland WLR_WL_OUTPUTS=1 sway --config "$ROOT/preview/sway.conf" &
preview_pid=$!
trap 'kill "$preview_pid" 2>/dev/null || true' EXIT

# Keep the nested output at its requested size instead of a tiled host size.
host_sig=$(hyprctl instances -j | jq -r --arg display "$parent_display" '.[] | select(.wl_socket == $display) | .instance' | head -1)
if [ -n "$host_sig" ]; then
    for attempt in {1..50}; do
        preview_addr=$(HYPRLAND_INSTANCE_SIGNATURE="$host_sig" hyprctl clients -j | jq -r --argjson pid "$preview_pid" '.[] | select(.pid == $pid) | .address' | head -1)
        if [ -n "$preview_addr" ]; then
            HYPRLAND_INSTANCE_SIGNATURE="$host_sig" hyprctl eval "hl.dispatch(hl.dsp.window.float({ action = 'on', window = 'address:$preview_addr' }))"
            HYPRLAND_INSTANCE_SIGNATURE="$host_sig" hyprctl eval "hl.dispatch(hl.dsp.window.resize({ x = 540, y = 1170, relative = false, window = 'address:$preview_addr' }))"
            HYPRLAND_INSTANCE_SIGNATURE="$host_sig" hyprctl eval "hl.dispatch(hl.dsp.window.center({ window = 'address:$preview_addr' }))"
            break
        fi
        sleep 0.1
    done
fi

wait "$preview_pid"
