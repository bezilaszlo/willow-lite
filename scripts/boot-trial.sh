#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
IMAGE=${1:-$ROOT/out/boot-willow-lite.img}
test -s "$IMAGE"

# Keep normal platform-tools discovery without changing HOME.
ORIGINAL_HOME=${HOME:-/home/bezi}
PLATFORM_TOOLS="$ORIGINAL_HOME/.local/opt/platform-tools"
if [ -d "$PLATFORM_TOOLS" ]; then PATH="$PLATFORM_TOOLS:$PATH"; fi
FASTBOOT_BIN=$(command -v fastboot || true)
[ -n "$FASTBOOT_BIN" ] || { echo "stop: fastboot binary not found" >&2; exit 1; }
SSH_BIN=/usr/bin/ssh
SSH_ARGS=(-F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=4)

# A manually recovered phone may already be in fastboot. In that case skip
# the SSH transition and use a checked reset/boot sequence.
if ! FASTBOOT_OUTPUT=$(timeout 8 "$FASTBOOT_BIN" devices 2>&1); then
  echo "stop: fastboot devices check failed" >&2
  exit 1
fi
FASTBOOT_ROWS=$(printf '%s\n' "$FASTBOOT_OUTPUT" | awk 'NF { if (NF != 2) { print "!invalid"; next }; print $1 " " $2 }')
if [ -n "$FASTBOOT_ROWS" ] && [ "$FASTBOOT_ROWS" != "e685bd fastboot" ]; then
  echo "stop: expected exactly one e685bd fastboot device; found: $FASTBOOT_ROWS" >&2
  exit 1
fi

if [ -z "$FASTBOOT_ROWS" ]; then
  if ! timeout 6 "$SSH_BIN" "${SSH_ARGS[@]}" moarchy@172.16.42.1 true 2>/dev/null; then
    echo "stop: no fastboot device and no SSH session" >&2
    exit 1
  fi
  if ! timeout 20 "$SSH_BIN" "${SSH_ARGS[@]}" moarchy@172.16.42.1 \
      'sudo -n systemctl reboot --reboot-argument=bootloader'; then
    echo "stop: SSH reboot-to-bootloader command failed" >&2
    exit 1
  fi

  FASTBOOT_DEADLINE=$((SECONDS + 30))
  while (( SECONDS < FASTBOOT_DEADLINE )); do
    if ! FASTBOOT_OUTPUT=$(timeout 2 "$FASTBOOT_BIN" devices 2>&1); then
      echo "stop: fastboot devices polling failed" >&2
      exit 1
    fi
    FASTBOOT_ROWS=$(printf '%s\n' "$FASTBOOT_OUTPUT" | awk 'NF { if (NF != 2) { print "!invalid"; next }; print $1 " " $2 }')
    if [ "$FASTBOOT_ROWS" = "e685bd fastboot" ]; then break; fi
    if [ -n "$FASTBOOT_ROWS" ]; then
      echo "stop: unexpected fastboot device during SSH transition: $FASTBOOT_ROWS" >&2
      exit 1
    fi
    sleep 1
  done
  if [ "$FASTBOOT_ROWS" != "e685bd fastboot" ]; then
    echo "stop: e685bd did not appear in fastboot within 30 seconds" >&2
    exit 1
  fi
fi

if [ "$FASTBOOT_ROWS" = "e685bd fastboot" ]; then
  echo "fastboot: e685bd; RAM-booting $IMAGE"
  umask 077
  mkdir -p "$ROOT/out"
  BOOT_LOG=$(mktemp "$ROOT/out/boot-trial-fastboot-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX.log")
  IMAGE_SHA256=$(sha256sum -- "$IMAGE" | awk '{print $1}')
  {
    printf 'started_utc=%s\n' "$(date -u +%FT%TZ)"
    printf 'preflight_device=%s\n' "$FASTBOOT_ROWS"
    printf 'image=%s\n' "$IMAGE"
    printf 'image_size_bytes=%s\n' "$(stat -c %s -- "$IMAGE")"
    printf 'image_sha256=%s\n' "$IMAGE_SHA256"
    printf 'fastboot_path=%s\n' "$FASTBOOT_BIN"
    printf 'fastboot_target=%s\n' "$(readlink -f -- "$FASTBOOT_BIN")"
  } > "$BOOT_LOG"
  if FASTBOOT_VERSION_OUTPUT=$("$FASTBOOT_BIN" --version 2>&1); then
    printf '%s\n' "$FASTBOOT_VERSION_OUTPUT" | sed 's/^/fastboot_version: /' >> "$BOOT_LOG"
  else
    printf 'fastboot_version_query_exit_status=%s\n' "$?" >> "$BOOT_LOG"
  fi

  run_fastboot_stage() {
    local stage=$1
    local limit=$2
    local started_ns
    local finished_ns
    shift 2

    {
      printf '%s_command=timeout %s %q -s e685bd' "$stage" "$limit" "$FASTBOOT_BIN"
      printf ' %q' "$@"
      printf '\n'
    } >> "$BOOT_LOG"
    started_ns=$(date +%s%N)
    if timeout "$limit" "$FASTBOOT_BIN" -s e685bd "$@" >> "$BOOT_LOG" 2>&1; then
      FASTBOOT_STAGE_EXIT_STATUS=0
    else
      FASTBOOT_STAGE_EXIT_STATUS=$?
    fi
    finished_ns=$(date +%s%N)
    printf '%s_exit_status=%s\n%s_duration_ms=%s\n' \
      "$stage" "$FASTBOOT_STAGE_EXIT_STATUS" "$stage" \
      "$(((finished_ns - started_ns) / 1000000))" >> "$BOOT_LOG"
  }

  finish_fastboot_trial() {
    local status=$1
    printf 'script_exit_status=%s\nfinished_utc=%s\n' \
      "$status" "$(date -u +%FT%TZ)" >> "$BOOT_LOG"
    cat "$BOOT_LOG"
    printf 'fastboot trial exit status: %s; log: %s\n' "$status" "$BOOT_LOG"
    exit "$status"
  }

  run_fastboot_stage reboot_bootloader 30 reboot-bootloader
  if [ "$FASTBOOT_STAGE_EXIT_STATUS" -ne 0 ]; then
    printf 'stop_reason=reboot-bootloader command failed\n' >> "$BOOT_LOG"
    finish_fastboot_trial "$FASTBOOT_STAGE_EXIT_STATUS"
  elif ! grep -Eiq '^Rebooting into bootloader[[:space:]]+OKAY([[:space:]]|$)' "$BOOT_LOG"; then
    printf 'stop_reason=reboot-bootloader returned no explicit OKAY\n' >> "$BOOT_LOG"
    finish_fastboot_trial 1
  fi

  printf 'wait_after_reboot_seconds=8\n' >> "$BOOT_LOG"
  sleep 8
  if FASTBOOT_AFTER_OUTPUT=$(timeout 8 "$FASTBOOT_BIN" devices 2>&1); then
    FASTBOOT_AFTER_STATUS=0
  else
    FASTBOOT_AFTER_STATUS=$?
  fi
  FASTBOOT_AFTER_ROWS=$(printf '%s\n' "$FASTBOOT_AFTER_OUTPUT" | awk 'NF { if (NF != 2) { print "!invalid"; next }; print $1 " " $2 }')
  {
    printf 'post_reboot_devices_exit_status=%s\n' "$FASTBOOT_AFTER_STATUS"
    printf 'post_reboot_devices_rows=%s\n' "$FASTBOOT_AFTER_ROWS"
    printf 'post_reboot_devices_output_begin\n%s\npost_reboot_devices_output_end\n' "$FASTBOOT_AFTER_OUTPUT"
  } >> "$BOOT_LOG"
  if [ "$FASTBOOT_AFTER_STATUS" -ne 0 ] || [ "$FASTBOOT_AFTER_ROWS" != "e685bd fastboot" ]; then
    printf 'stop_reason=post-reboot fastboot state was not exactly e685bd fastboot\n' >> "$BOOT_LOG"
    finish_fastboot_trial 1
  fi

  run_fastboot_stage boot 300 boot "$IMAGE"
  if [ "$FASTBOOT_STAGE_EXIT_STATUS" -ne 0 ]; then
    printf 'stop_reason=fastboot boot command failed\n' >> "$BOOT_LOG"
    finish_fastboot_trial "$FASTBOOT_STAGE_EXIT_STATUS"
  elif ! grep -Eiq '^Booting[[:space:]]+OKAY([[:space:]]|$)' "$BOOT_LOG"; then
    printf 'stop_reason=boot command returned no explicit OKAY\n' >> "$BOOT_LOG"
    finish_fastboot_trial 1
  fi
  finish_fastboot_trial 0
fi
