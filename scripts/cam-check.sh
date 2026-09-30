#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=cam.conf
. "$ROOT/scripts/cam.conf"
CAM="$ROOT/out/cam"
MODE=${1:-once}

usage() {
  cat >&2 <<USAGE
usage: $0 once [label]            grab one frame, print screen-crop YAVG and view status
       $0 watch SECONDS [STEP]    save a frame every STEP seconds (default 3), print YAVG each
       $0 frozen [DELAY]          two frames DELAY seconds apart (default 4), print crop difference
lit/dark and frozen/changing labels require SCREEN_VIEW_VALID=1 after confirming that crop
$SCREEN_CROP (w:h:x:y) contains the phone screen. Otherwise output is marked view=unverified.
Frozen mode also needs on-screen motion (cursor, clock); a static lit screen reads as frozen.
USAGE
  exit 2
}

busy() {
  local pids
  pids=$(fuser "$CAM_DEVICE" 2>/dev/null || true)
  [ -z "$pids" ] && return 1
  for pid in $pids; do
    echo "camera busy: pid $pid $(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | cut -c1-80)" >&2
  done
  echo "stop: ask the user to close the process holding $CAM_DEVICE; it is not killed here" >&2
  return 0
}

grab() {
  ffmpeg -y -loglevel error -f v4l2 -video_size "$CAM_SIZE" -framerate "$CAM_FPS" -i "$CAM_DEVICE" \
    -vf "select=gte(n\,$CAM_SKIP_FRAMES)" -frames:v 1 "$1"
}

yavg() {
  ffmpeg -loglevel error -i "$1" -vf "crop=$SCREEN_CROP,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-" -f null - |
    awk -F= '/YAVG/ { printf "%.1f\n", $2 }'
}

verdict() { awk -v y="$1" -v t="$LIT_MIN_YAVG" 'BEGIN { print (y > t) ? "lit" : "dark" }'; }

report() {
  local y
  y=$(yavg "$1")
  if [ "${SCREEN_VIEW_VALID:-0}" = "1" ]; then
    echo "$1 yavg=$y $(verdict "$y")"
  else
    echo "$1 yavg=$y view=unverified"
  fi
}

mkdir -p "$CAM"
busy && exit 3
case "$MODE" in
  once)
    f="$CAM/$(date +%Y%m%d-%H%M%S)${2:+-$2}.jpg"
    grab "$f"
    report "$f" ;;
  watch)
    total=${2:?seconds}
    step=${3:-3}
    end=$(( $(date +%s) + total ))
    while [ "$(date +%s)" -lt "$end" ]; do
      f="$CAM/$(date +%Y%m%d-%H%M%S).jpg"
      grab "$f" && report "$f"
      sleep "$step"
    done ;;
  frozen)
    delay=${2:-4}
    a="$CAM/frozen-a-$(date +%H%M%S).jpg"
    b="$CAM/frozen-b-$(date +%H%M%S).jpg"
    grab "$a"
    sleep "$delay"
    grab "$b"
    d=$(ffmpeg -loglevel error -i "$a" -i "$b" -filter_complex "[0:v]crop=$SCREEN_CROP[x];[1:v]crop=$SCREEN_CROP[y];[x][y]blend=all_mode=difference,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-" -f null - |
        awk -F= '/YAVG/ { printf "%.2f\n", $2 }')
    if [ "${SCREEN_VIEW_VALID:-0}" = "1" ]; then
      state=$(awk -v d="$d" -v m="$FROZEN_MAX_DIFF" 'BEGIN { print (d < m) ? "frozen-or-static" : "changing" }')
    else
      state=view=unverified
    fi
    echo "$a $b diff=$d $state" ;;
  *) usage ;;
esac
