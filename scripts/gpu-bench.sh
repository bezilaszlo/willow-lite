#!/usr/bin/env bash
# Benchmark the phone GPU inside the running Wayland session and record clocks and temperatures.
# Usage: scripts/gpu-bench.sh LABEL [glmark2 args...]; the log lands in out/gpu-bench-LABEL.log.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PHONE=${PHONE:-moarchy@172.16.42.1}
SSH_OPTS=${SSH_OPTS:--o UserKnownHostsFile=/tmp/willow-lite-known-hosts}
label=${1:?usage: gpu-bench.sh LABEL [glmark2 args...]}
shift
mkdir -p "$ROOT/out"
log="$ROOT/out/gpu-bench-$label.log"

# shellcheck disable=SC2086
ssh $SSH_OPTS "$PHONE" bash -s -- "$@" <<'REMOTE' | tee "$log"
set -eu
export XDG_RUNTIME_DIR=/run/user/$(id -u)
WAYLAND_DISPLAY=$(cd "$XDG_RUNTIME_DIR" && ls wayland-* 2>/dev/null | grep -v lock | head -1)
export WAYLAND_DISPLAY
test -n "$WAYLAND_DISPLAY" || { echo "no Wayland session" >&2; exit 1; }
gpu=/sys/class/devfreq/5900000.gpu
zone() { for z in /sys/class/thermal/thermal_zone*; do [ "$(cat "$z/type")" = "$1" ] && cat "$z/temp"; done; }
compositor=$(for c in Hyprland sway; do pgrep -x "$c" >/dev/null && { echo "$c"; break; }; done)
echo "date: $(date -u +%FT%TZ)"
echo "kernel: $(uname -r)"
echo "compositor: ${compositor:-unknown} on $WAYLAND_DISPLAY"
echo "governor: $(cat $gpu/governor) range $(cat $gpu/min_freq)-$(cat $gpu/max_freq)"
echo "idle: gpu $(zone gpu-thermal) cpu $(zone cpu-thermal) freq $(cat $gpu/cur_freq) battery $(cat /sys/class/power_supply/*/voltage_now) uV"
samples=$(mktemp)
(while :; do
    echo "$(cat $gpu/cur_freq) $(cat /sys/class/drm/card0/device/gpu_busy_percent) $(zone gpu-thermal) $(zone cpu-thermal)"
    sleep 0.5
done) >"$samples" &
sampler=$!
trap 'kill $sampler 2>/dev/null; rm -f "$samples"' EXIT
if [ $# -eq 0 ]; then
    set -- --fullscreen
fi
glmark2-es2-wayland "$@" 2>&1 | grep -vE '^\s*$'
kill $sampler
awk '{ n++; f[$1]++; busy += $2; if ($3 > gt) gt = $3; if ($4 > ct) ct = $4 }
    END {
        printf "samples: %d, mean busy %.0f%%, max gpu-thermal %.1f C, max cpu-thermal %.1f C\n", n, busy / n, gt / 1000, ct / 1000
        for (k in f) printf "  %4d MHz %5.1f%%\n", k / 1000000, 100 * f[k] / n
    }' "$samples" | sort -k1,1 -s
echo "after: gpu $(zone gpu-thermal) cpu $(zone cpu-thermal) battery $(cat /sys/class/power_supply/*/voltage_now) uV"
REMOTE
printf 'log: %s\n' "$log"
