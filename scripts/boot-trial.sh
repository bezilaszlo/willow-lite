#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
IMAGE="$ROOT/out/boot-willow-lite.img"
test -s "$IMAGE"
exec /home/bezi/Work/moarchy-willow/mini/boot-it.sh "$IMAGE"
