#!/usr/bin/env bash
# Copy the session files (compositor configs, Quickshell, foot, session scripts) to the running phone root.
# Install helpers before copying Quickshell QML because its watcher reloads the file immediately.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PHONE=${PHONE:-moarchy@172.16.42.1}
SSH_OPTS=${SSH_OPTS:--o UserKnownHostsFile=/tmp/willow-lite-known-hosts}

# shellcheck disable=SC2086
tar -C "$ROOT/device/usr/local/bin" -cf - willow-session willow-compositor willow-power-button willow-power-action |
    ssh $SSH_OPTS "$PHONE" 'stage=$(mktemp -d) && tar -C "$stage" -xf - && sudo install -o root -g root -m 0755 -t /usr/local/bin "$stage"/* && rm -rf "$stage"'
# shellcheck disable=SC2086
tar -C "$ROOT/device/home/moarchy" -cf - .bash_profile .config | ssh $SSH_OPTS "$PHONE" 'tar -C "$HOME" -xf -'
# shellcheck disable=SC2086
ssh $SSH_OPTS "$PHONE" 'willow-compositor status'
