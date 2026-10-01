#!/usr/bin/env bash
# Deploy only the Willow shell runtime. Preserve unrelated user configuration and
# keep the controller as the final QML file installed so its imports are ready.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PHONE=${PHONE:-moarchy@172.16.42.1}
SSH=( -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=no
      -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=4 )

FILES=(
    device/home/moarchy/.config/hypr/willow.lua
    device/home/moarchy/.config/quickshell/AppDrawer.qml
    device/home/moarchy/.config/quickshell/BackGesture.qml
    device/home/moarchy/.config/quickshell/ControlCenter.qml
    device/home/moarchy/.config/quickshell/HomeScreen.qml
    device/home/moarchy/.config/quickshell/LockScreen.qml
    device/home/moarchy/.config/quickshell/LockScreenContent.qml
    device/home/moarchy/.config/quickshell/Overview.qml
    device/home/moarchy/.config/quickshell/PowerMenu.qml
    device/home/moarchy/.config/quickshell/StatusBar.qml
    device/home/moarchy/.config/quickshell/Theme.qml
    device/home/moarchy/.config/quickshell/ThemeStore.qml
    device/home/moarchy/.config/quickshell/qmldir
    device/home/moarchy/.config/quickshell/fonts/JetBrainsMono-Regular.ttf
    device/home/moarchy/.config/quickshell/fonts/JetBrainsMono-Thin.ttf
    device/home/moarchy/.config/quickshell/fonts/OFL.txt
    device/home/moarchy/.config/quickshell/willow-screenshot-flash.qml
    device/home/moarchy/.config/quickshell/willow.qml
    device/usr/local/bin/willow-brightness
    device/usr/local/bin/willow-compositor
    device/usr/local/bin/willow-keyboard
    device/usr/local/bin/willow-lock-display
    device/usr/local/bin/willow-power-action
    device/usr/local/bin/willow-power-button
    device/usr/local/bin/willow-screenshot
    device/usr/local/bin/willow-screenshot-gesture
    device/usr/local/bin/willow-session
    device/usr/local/bin/willow-session-lock-state
    device/usr/local/bin/willow-status
)

local_stage=$(mktemp -d)
remote_stage=
cleanup() {
    rm -rf -- "$local_stage"
    if [[ -n $remote_stage ]]; then
        ssh "${SSH[@]}" "$PHONE" "rm -rf -- '$remote_stage'" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

cd "$ROOT"
sha256sum "${FILES[@]}" > "$local_stage/SHA256SUMS"
tar -czf "$local_stage/session.tar.gz" \
    -C "$local_stage" SHA256SUMS -C "$ROOT" "${FILES[@]}"
remote_stage=$(ssh "${SSH[@]}" "$PHONE" \
    'umask 077; mkdir -p "$HOME/.local/state/willow"; mktemp -d "$HOME/.local/state/willow/session-deploy.XXXXXX"')
scp "${SSH[@]}" "$local_stage/session.tar.gz" "$PHONE:$remote_stage/session.tar.gz"

ssh "${SSH[@]}" "$PHONE" bash -s -- "$remote_stage" <<'REMOTE'
set -euo pipefail
stage=$1
payload=$stage/payload
mkdir -p "$payload" "$HOME/.local/state/willow/deploy-backups"
rollback=$(mktemp -d "$HOME/.local/state/willow/deploy-backups/session.XXXXXX")
tar -xzf "$stage/session.tar.gz" -C "$payload"
cd "$payload"
sha256sum -c SHA256SUMS

helpers=(willow-brightness willow-compositor willow-keyboard willow-lock-display
         willow-power-action willow-power-button willow-screenshot
         willow-screenshot-gesture willow-session willow-session-lock-state willow-status)
qml=(AppDrawer.qml BackGesture.qml ControlCenter.qml HomeScreen.qml LockScreen.qml
     LockScreenContent.qml Overview.qml PowerMenu.qml StatusBar.qml Theme.qml
     ThemeStore.qml qmldir willow-screenshot-flash.qml)
fonts=(JetBrainsMono-Regular.ttf JetBrainsMono-Thin.ttf OFL.txt)
targets=()
for file in "${helpers[@]}"; do targets+=("helper:$file"); done
for file in "${qml[@]}"; do targets+=("qml:$file"); done
for file in "${fonts[@]}"; do targets+=("font:$file"); done
targets+=("hypr:willow.lua" "qml:willow.qml")

save_old() {
    kind=$1 file=$2 source= destination=
    case $kind in
        helper) source=/usr/local/bin/$file ;;
        qml) source=$HOME/.config/quickshell/$file ;;
        font) source=$HOME/.config/quickshell/fonts/$file ;;
        hypr) source=$HOME/.config/hypr/$file ;;
    esac
    destination=$rollback/$kind/$file
    if [ -e "$source" ]; then
        mkdir -p "$(dirname "$destination")"
        cp -p "$source" "$destination"
        : > "$destination.exists"
    fi
}
for target in "${targets[@]}"; do save_old "${target%%:*}" "${target#*:}"; done

qs_pid=$(pgrep -f '^qs -p /home/moarchy/.config/quickshell/willow.qml$' | head -n 1 || true)
qs_stopped=0
completed=0
rollback_deploy() {
    [ "$completed" -eq 0 ] || return 0
    set +e
    for target in "${targets[@]}"; do
        kind=${target%%:*}; file=${target#*:}
        case $kind in
            helper) destination=/usr/local/bin/$file ;;
            qml) destination=$HOME/.config/quickshell/$file ;;
            font) destination=$HOME/.config/quickshell/fonts/$file ;;
            hypr) destination=$HOME/.config/hypr/$file ;;
        esac
        old=$rollback/$kind/$file
        if [ -e "$old.exists" ]; then
            if [ "$kind" = helper ]; then
                sudo -n install -o root -g root -m 0755 "$old" "$destination"
            else
                install -o moarchy -g moarchy -m 0644 "$old" "$destination"
            fi
        elif [ "$kind" = helper ]; then
            sudo -n rm -f -- "$destination"
        else
            rm -f -- "$destination"
        fi
    done
    if [ "$qs_stopped" -eq 1 ]; then kill -CONT "$qs_pid" 2>/dev/null || true; fi
}
trap rollback_deploy EXIT
trap 'exit 1' HUP INT TERM

for file in "${helpers[@]}"; do
    sudo -n install -o root -g root -m 0755 \
        "device/usr/local/bin/$file" "/usr/local/bin/$file"
done

[ -z "$qs_pid" ] || { kill -STOP "$qs_pid"; qs_stopped=1; }
mkdir -p "$HOME/.config/quickshell/fonts" "$HOME/.config/hypr"
for file in "${qml[@]}"; do
    install -o moarchy -g moarchy -m 0644 \
        "device/home/moarchy/.config/quickshell/$file" \
        "$HOME/.config/quickshell/$file"
done
for file in "${fonts[@]}"; do
    install -o moarchy -g moarchy -m 0644 \
        "device/home/moarchy/.config/quickshell/fonts/$file" \
        "$HOME/.config/quickshell/fonts/$file"
done
install -o moarchy -g moarchy -m 0644 \
    device/home/moarchy/.config/hypr/willow.lua "$HOME/.config/hypr/willow.lua"
# The controller is last: its file watcher may reload QML as soon as it lands.
install -o moarchy -g moarchy -m 0644 \
    device/home/moarchy/.config/quickshell/willow.qml \
    "$HOME/.config/quickshell/willow.qml"

if [ -n "$qs_pid" ]; then
    kill -CONT "$qs_pid"
    qs_stopped=0
fi
restore_option=$(hyprctl -i 0 getoption misc:allow_session_lock_restore)
case $restore_option in
    *'bool: true'*) ;;
    *) hyprctl -i 0 reload ;;
esac
sleep 3
if ! pgrep -f '^qs -p /home/moarchy/.config/quickshell/willow.qml$' >/dev/null; then
    hyprctl -i 0 eval 'hl.exec_cmd("qs -p /home/moarchy/.config/quickshell/willow.qml")'
fi
sleep 2
pgrep -f '^qs -p /home/moarchy/.config/quickshell/willow.qml$' >/dev/null
errors=$(hyprctl -i 0 configerrors)
case $errors in ''|ok) ;; *) printf '%s\n' "$errors" >&2; exit 1 ;; esac
hyprctl -i 0 getoption misc:allow_session_lock_restore
completed=1
trap - EXIT HUP INT TERM
printf 'deployed; qs_pid=%s backup=%s\n' \
    "$(pgrep -f '^qs -p /home/moarchy/.config/quickshell/willow.qml$' | head -n 1)" "$rollback"
REMOTE

ssh "${SSH[@]}" "$PHONE" 'willow-compositor status'
