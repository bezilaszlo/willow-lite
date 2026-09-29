#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

command -v sway >/dev/null || { echo "Install Sway with: omarchy pkg add sway" >&2; exit 1; }
command -v qs >/dev/null || { echo "Quickshell (qs) is required" >&2; exit 1; }
command -v wayvnc >/dev/null || { echo "Install wayvnc with: omarchy pkg add wayvnc" >&2; exit 1; }
command -v gvncviewer >/dev/null || { echo "Install gtk-vnc with: omarchy pkg add gtk-vnc" >&2; exit 1; }

parent_display=${WAYLAND_DISPLAY:-}
if [ -z "$parent_display" ]; then
    command -v hyprctl >/dev/null || { echo "Set WAYLAND_DISPLAY to the desktop socket" >&2; exit 1; }
    parent_display=$(hyprctl instances -j | jq -r '.[0].wl_socket // empty')
fi
test -S "${XDG_RUNTIME_DIR:?}/$parent_display" || { echo "Wayland socket not found: $parent_display" >&2; exit 1; }
host_sig=$(hyprctl instances -j | jq -r --arg display "$parent_display" '.[] | select(.wl_socket == $display) | .instance' | head -1)
test -n "$host_sig" || { echo "Could not find the Omarchy desktop" >&2; exit 1; }

display_file="$ROOT/out/preview-wayland-display"
: > "$display_file"
env XDG_SESSION_TYPE=wayland WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=1 WLR_LIBINPUT_NO_DEVICES=1 sway --config "$ROOT/preview/sway.conf" &
preview_pid=$!
vnc_pid=
viewer_pid=
trap 'test -z "$viewer_pid" || kill "$viewer_pid" 2>/dev/null || true; test -z "$vnc_pid" || kill "$vnc_pid" 2>/dev/null || true; kill "$preview_pid" 2>/dev/null || true' EXIT

for attempt in {1..50}; do
    test -s "$display_file" && break
    kill -0 "$preview_pid" 2>/dev/null || { wait "$preview_pid"; exit 1; }
    sleep 0.1
done
test -s "$display_file" || { echo "Sway did not publish its Wayland socket" >&2; exit 1; }
preview_display=$(cat "$display_file")
env WAYLAND_DISPLAY="$preview_display" wayvnc -R -S "$XDG_RUNTIME_DIR/willow-lite-wayvncctl" 127.0.0.1 5909 &
vnc_pid=$!

for attempt in {1..50}; do
    ss -H -ltn '( sport = :5909 )' | rg -q '5909' && break
    kill -0 "$vnc_pid" 2>/dev/null || { wait "$vnc_pid"; exit 1; }
    sleep 0.1
done

# Float the viewer before it maps; resizing it later blanks gtk-vnc's video surface.
HYPRLAND_INSTANCE_SIGNATURE="$host_sig" hyprctl eval 'hl.window_rule({ match = { class = "^Gvncviewer$" }, float = true, center = true, size = { 320, 700 }, tag = "-default-opacity" })' >/dev/null
env DISPLAY="${DISPLAY:-:0}" GDK_BACKEND=x11 gvncviewer -z 55 127.0.0.1:9 &
viewer_pid=$!
wait "$preview_pid"
