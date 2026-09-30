#!/usr/bin/env bash
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOST=${HOST:-moarchy@172.16.42.1}
WAIT=${WAIT:-0}
CONFIRM=
LOGFILE=
OUT="$ROOT/out"

while [ $# -gt 0 ]; do
  case "$1" in
    --log) LOGFILE=${2:?file}; shift 2 ;;
    --wait) WAIT=${2:?seconds}; shift 2 ;;
    --confirm) CONFIRM=ok; shift ;;
    --hold) CONFIRM=ho; shift ;;
    *) echo "usage: $0 [--wait SECONDS] [--confirm|--hold] [--log dmesg.txt]" >&2; exit 2 ;;
  esac
done

SSH=(ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=4 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$HOST")
STAMP=$(date +%Y%m%d-%H%M%S)
DMESG="$OUT/dmesg-$STAMP.log"
PSTORE="$OUT/pstore-$STAMP.log"
FAIL=0

row() { printf '%-5s %-26s %s\n' "$1" "$2" "$3"; [ "$1" = FAIL ] && FAIL=$((FAIL + 1)); return 0; }

if [ -n "$LOGFILE" ]; then
  DMESG=$LOGFILE
  LIVE=0
else
  LIVE=1
  end=$(( $(date +%s) + WAIT ))
  until timeout 8 "${SSH[@]}" true 2>/dev/null; do
    if [ "$(date +%s)" -ge "$end" ]; then echo "FAIL  ssh                      no SSH to $HOST"; exit 1; fi
    sleep 3
  done
  if [ -n "$CONFIRM" ]; then
    timeout 5 bash -c "printf $CONFIRM > /dev/tcp/${HOST#*@}/9977" 2>/dev/null && echo "deadman: sent '$CONFIRM'" || echo "deadman: nothing listening on 9977 (not armed, or already gone)"
  fi
  mkdir -p "$OUT"
  timeout 30 "${SSH[@]}" 'sudo -n dmesg' > "$DMESG" || { echo "FAIL  dmesg                    cannot read dmesg"; exit 1; }
  timeout 20 "${SSH[@]}" 'sudo -n sh -c '\''for f in /sys/fs/pstore/*; do [ -f "$f" ] || continue; echo "===== $f ====="; cat "$f"; done'\''' > "$PSTORE" || { echo "WARN  pstore                   could not read pstore"; : > "$PSTORE"; }
  if [ -s "$PSTORE" ]; then echo "pstore   saved $PSTORE"; else echo "pstore   empty ($PSTORE)"; fi
fi

remote() { [ "$LIVE" = 1 ] && timeout 20 "${SSH[@]}" "$1" 2>/dev/null; }
has() { grep -E -q "$1" "$DMESG"; }
first() { grep -E -m1 "$1" "$DMESG" | sed 's/^\[[^]]*\] *//' | cut -c1-110; }

if [ "$LIVE" = 1 ]; then
  echo "kernel   $(remote 'uname -r')  cmdline: $(remote 'cat /proc/cmdline' | cut -c1-100)..."
fi
echo "dmesg    $DMESG ($(wc -l < "$DMESG") lines)"
echo

if has 'Kernel panic|Oops|BUG:|Unable to handle kernel|Call trace|WARNING: CPU'; then
  row FAIL oops-bug "$(first 'Kernel panic|Oops|BUG:|Unable to handle kernel|Call trace|WARNING: CPU')"
else
  row PASS oops-bug "none"
fi

if has 'ginkgo UEFI DSI|ginkgo DSI after EN|power mode readback'; then
  row INFO community-dsi-hook "$(first 'ginkgo UEFI DSI|power mode readback')"
fi
if has 'panel init complete'; then row INFO panel-init "$(first 'panel init complete')"; fi
if has 'Skipping (prepare|enable) of already'; then
  row FAIL panel-prepare-cycle "$(first 'Skipping (prepare|enable) of already')"
else
  row PASS panel-prepare-cycle "no 'Skipping prepare/enable of already ...' lines"
fi
if has '(DSI|dsi).*(FIFO (overflow|error|underflow)|status=5|timed out|timeout|-110)|panel.*(failed|error)'; then
  row FAIL dsi-errors "$(first '(DSI|dsi).*(FIFO (overflow|error|underflow)|status=5|timed out|timeout|-110)|panel.*(failed|error)')"
else
  row PASS dsi-errors "none"
fi
if has 'msm_dpu .*bound .*dsi'; then row PASS dpu-dsi-bound "$(first 'msm_dpu .*bound .*dsi')"; else row FAIL dpu-dsi-bound "no dpu/dsi bind line"; fi

if has 'NVT-ts.*(finished|Update firmware success)|Novatek NT36672A initialized'; then
  row PASS touch-probe "$(first 'NVT-ts.*(finished|Update firmware success)|Novatek NT36672A initialized')"
else
  row FAIL touch-probe "no NVT-ts / NT36672A init line"
fi
if has 'failed to (request|download) firmware|firmware boot timeout|firmware load failed'; then
  row FAIL touch-firmware "$(first 'failed to (request|download) firmware|firmware boot timeout|firmware load failed')"
fi

if [ "$LIVE" = 1 ]; then
  st=$(remote 'cat /sys/class/drm/card0-DSI-1/status /sys/class/drm/card0-DSI-1/enabled /sys/class/drm/card0-DSI-1/modes' | tr '\n' ' ')
  case "$st" in
    *connected*enabled*1080x2340*) row PASS dsi-connector "$st" ;;
    *) row FAIL dsi-connector "${st:-unreadable}" ;;
  esac
  if remote 'grep -E -q "NVTCapacitiveTouchScreen|Novatek NT36672A Touchscreen" /proc/bus/input/devices'; then
    row PASS touch-input "input device present"
  else
    row FAIL touch-input "no touchscreen input device"
  fi
  gpu=$(remote 'sudo -n cat /sys/kernel/debug/dri/0/gpu' | tr '\n' ' ')
  case "$gpu" in
    *"gpu-initialized: 1"*) row PASS gpu "$(echo "$gpu" | cut -c1-100)" ;;
    *) row FAIL gpu "${gpu:-debugfs gpu unreadable}" ;;
  esac
  gadget=$(remote 'ls /sys/kernel/config/usb_gadget/*/functions 2>/dev/null' | tr '\n' ' ')
  link=$(remote 'ip -br link show usb0' | tr -s ' ')
  case "$link" in
    usb0*UP*|usb0*UNKNOWN*) row PASS usb-net "$link; functions: $gadget" ;;
    *) row FAIL usb-net "${link:-no usb0}; functions: $gadget" ;;
  esac
  ramoops=$(remote 'ls /sys/fs/pstore 2>/dev/null' | tr '\n' ' ')
  row INFO pstore "${ramoops:-empty}"
  row INFO watchdog "$(remote 'ls /dev/watchdog* 2>/dev/null' | tr '\n' ' ')"
else
  row SKIP live-checks "dsi connector, touch input, gpu debugfs, usb net, pstore need a live phone"
fi

echo
echo "fail count: $FAIL"
exit $(( FAIL > 0 ))
