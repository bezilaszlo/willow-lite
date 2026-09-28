#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PHONE=${PHONE:-moarchy@172.16.42.1}
TARGET=/var/lib/willow-lite-trial
STAGE=/tmp/willow-lite-device-config

test -d "$ROOT/device"
bash "$ROOT/scripts/build-touch-map.sh"
tar -C "$ROOT/device" -cf - . | ssh "$PHONE" "sudo install -d -m 0700 '$STAGE' && sudo tar --no-same-owner -C '$STAGE' -xf -"
ssh "$PHONE" "sudo test -x '$TARGET/sbin/init'"

ssh "$PHONE" "
  set -eu
  target='$TARGET'
  uid=\$(id -u moarchy)
  gid=\$(id -g moarchy)
  if ! sudo awk -F: -v gid=\"\$gid\" '\$3 == gid { found=1 } END { exit !found }' \"\$target/etc/group\"; then
    sudo groupadd --prefix \"\$target\" -g \"\$gid\" moarchy
  fi
  if ! sudo grep -q '^moarchy:' \"\$target/etc/passwd\"; then
    sudo useradd --prefix \"\$target\" -m -u \"\$uid\" -g \"\$gid\" -G wheel,input,video,seat -s /bin/bash moarchy
  fi
  sudo install -D -o root -g root -m 0644 '$STAGE/etc/hostname' \"\$target/etc/hostname\"
  sudo install -D -o root -g root -m 0644 '$STAGE/etc/systemd/network/10-willow-usb.network' \"\$target/etc/systemd/network/10-willow-usb.network\"
  sudo install -D -o root -g root -m 0440 '$STAGE/etc/sudoers.d/10-willow-lite' \"\$target/etc/sudoers.d/10-willow-lite\"
  sudo visudo -c -f \"\$target/etc/sudoers.d/10-willow-lite\"
  sudo cp -a '$STAGE/home/moarchy/.' \"\$target/home/moarchy/\"
  sudo install -d -o \"\$uid\" -g \"\$gid\" -m 0700 \"\$target/home/moarchy/.ssh\"
  sudo chown -R \"\$uid:\$gid\" \"\$target/home/moarchy\"
  sudo chmod 0700 \"\$target/home/moarchy/.ssh\"
  sudo install -o \"\$uid\" -g \"\$gid\" -m 0600 /home/moarchy/.ssh/authorized_keys \"\$target/home/moarchy/.ssh/authorized_keys\"
  sudo chmod 0600 \"\$target/home/moarchy/.ssh/authorized_keys\"
  sudo chmod 0644 \"\$target/home/moarchy/.config/sway/config\"
  [ -e \"\$target/etc/ssh/ssh_host_ed25519_key\" ] || sudo ssh-keygen -q -t ed25519 -N '' -C '' -f \"\$target/etc/ssh/ssh_host_ed25519_key\"
  [ -e \"\$target/etc/ssh/ssh_host_ecdsa_key\" ] || sudo ssh-keygen -q -t ecdsa -b 521 -N '' -C '' -f \"\$target/etc/ssh/ssh_host_ecdsa_key\"
  [ -e \"\$target/etc/ssh/ssh_host_rsa_key\" ] || sudo ssh-keygen -q -t rsa -b 3072 -N '' -C '' -f \"\$target/etc/ssh/ssh_host_rsa_key\"
  sudo systemctl --root=\"\$target\" enable sshd.service systemd-networkd.service systemd-resolved.service getty@tty1.service
  sudo systemd-tmpfiles --root=\"\$target\" --create
  sudo install -D -o root -g root -m 0644 '$STAGE/etc/systemd/system/getty@tty1.service.d/autologin.conf' \"\$target/etc/systemd/system/getty@tty1.service.d/autologin.conf\"
  sudo install -D -o root -g root -m 0644 '$STAGE/etc/systemd/system/willow-backlight.service' \"\$target/etc/systemd/system/willow-backlight.service\"
  sudo install -D -o root -g root -m 0755 '$ROOT/out/willow-touch-map.so' \"\$target/usr/local/lib/willow-touch-map.so\"
  sudo install -D -o root -g root -m 0755 '$STAGE/usr/local/sbin/willow-touch-map-rollback' \"\$target/usr/local/sbin/willow-touch-map-rollback\"
  sudo systemctl --root=\"\$target\" enable willow-backlight.service
  sudo rm -rf '$STAGE'
"

ssh "$PHONE" "sudo test -x '$TARGET/sbin/init' && sudo test -s '$TARGET/home/moarchy/.ssh/authorized_keys' && sudo test -L '$TARGET/etc/systemd/system/multi-user.target.wants/sshd.service' && sudo test -L '$TARGET/etc/systemd/system/getty.target.wants/getty@tty1.service'"
