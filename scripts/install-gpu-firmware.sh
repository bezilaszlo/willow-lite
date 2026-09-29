#!/usr/bin/env bash
# Install the Adreno 610 firmware the RAM boot initramfs already carries into the phone root,
# so the GPU does not depend on the initramfs for a later firmware request.
set -euo pipefail

PHONE=${PHONE:-moarchy@172.16.42.1}
SSH_OPTS=${SSH_OPTS:--o UserKnownHostsFile=/tmp/willow-lite-known-hosts}
SOURCE=${SOURCE:-/home/bezi/Work/moarchy-willow/mini/root/lib/firmware}
STAGE=/tmp/willow-lite-gpu-firmware

# SQE is linux-firmware's (version >= 0x190); the zap shader is Xiaomi-signed for PIL 0x57515000.
files=(
    qcom/a630_sqe.fw
    qcom/sm6125/xiaomi/ginkgo/a610_zap.mdt
    qcom/sm6125/xiaomi/ginkgo/a610_zap.b00
    qcom/sm6125/xiaomi/ginkgo/a610_zap.b01
    qcom/sm6125/xiaomi/ginkgo/a610_zap.b02
)
sums=(
    a0e1b583f620fabe32729ce367959d1960638663244d7d0cfc21b9a5215a018b
    fa0202981746df6c67518c4d27cf54517544ef93b755453319d4a2d143eff03b
    422ed7993d7cd924ba3200b1acd18c120b0a40f4357b55362eddcbe4a0c8e019
    3b515c06a7b3bc92b5d9fb35c141cc2793ce168a2ad7fc1b2be081cf64fc32f7
    84c657996f3ec60a90d0c7223faad9b0700074fe00dc55596e0d3ba69b914d33
)
for i in "${!files[@]}"; do
    printf '%s  %s\n' "${sums[$i]}" "$SOURCE/${files[$i]}"
done | sha256sum --check --quiet -

# shellcheck disable=SC2086
tar -C "$SOURCE" -cf - "${files[@]}" | ssh $SSH_OPTS "$PHONE" "rm -rf '$STAGE' && mkdir -m 0700 '$STAGE' && tar -C '$STAGE' -xf -"
# shellcheck disable=SC2086
ssh $SSH_OPTS "$PHONE" "
  set -eu
  # From the old root the trial lives below /var/lib; once booted into it, it is /.
  target=/var/lib/willow-lite-trial
  sudo test -x \"\$target/sbin/init\" || target=
  cd '$STAGE'
  for f in ${files[*]}; do
    sudo install -D -o root -g root -m 0644 \"\$f\" \"\$target/usr/lib/firmware/\$f\"
  done
  cd /
  rm -rf '$STAGE'
  cd \"\$target/usr/lib/firmware\" && sha256sum ${files[*]}
"
