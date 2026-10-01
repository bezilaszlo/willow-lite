#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
mkdir -p "$ROOT/out"
mkdir -p "$ROOT/out/preview-config"

command -v sway >/dev/null || { echo "Install Sway with: omarchy pkg add sway" >&2; exit 1; }
command -v qs >/dev/null || { echo "Quickshell (qs) is required" >&2; exit 1; }
command -v wayvnc >/dev/null || { echo "Install wayvnc with: omarchy pkg add wayvnc" >&2; exit 1; }
test -f /usr/lib/girepository-1.0/GtkVnc-2.0.typelib || { echo "Install gtk-vnc with: omarchy pkg add gtk-vnc" >&2; exit 1; }
/usr/bin/python -c 'import gi' 2>/dev/null || { echo "Install Python GObject with: omarchy pkg add python-gobject" >&2; exit 1; }

display_file="$ROOT/out/preview-wayland-display"
: > "$display_file"
env -u HYPRLAND_INSTANCE_SIGNATURE WILLOW_SOURCE_ROOT="$ROOT" XDG_CONFIG_HOME="$ROOT/out/preview-config" XDG_SESSION_TYPE=wayland WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=1 WLR_LIBINPUT_NO_DEVICES=1 sway --config "$ROOT/preview/sway.conf" &
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

# Keep the phone's aspect ratio while its window tiles beside the terminal.
env DISPLAY="${DISPLAY:-:0}" GDK_BACKEND=x11 /usr/bin/python "$ROOT/scripts/preview-viewer.py" &
viewer_pid=$!
wait "$viewer_pid"
