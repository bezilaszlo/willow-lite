#!/usr/bin/env bash
# Deploy only the Willow shell runtime. Preserve unrelated user configuration and
# keep the controller as the final QML file installed so its imports are ready,
# then restart only Quickshell and verify the new engine loaded.
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

qs_pids=$(pgrep -f '^qs -p /home/moarchy/.config/quickshell/willow.qml$' || true)
case $qs_pids in
    *$'\n'*) echo 'refusing shell deployment with multiple Willow Quickshell instances' >&2; exit 1 ;;
esac
qs_pid=$qs_pids
qs_stopped=0
qs_terminated=0
new_qs_pid=
home_was_visible=false
if [ -n "$qs_pid" ]; then
    home_was_visible=$(qs ipc --pid "$qs_pid" prop get willow homeVisible 2>/dev/null || echo false)
fi
completed=0
marker=/run/user/1000/willow-session-locked
if [ -e "$marker" ]; then
    echo 'refusing shell deployment while the session lock marker exists' >&2
    exit 1
fi
launch_attempted=0
new_qs_stop_failed=0

launch_qs() {
    launch_token="willow-sync-${BASHPID}-${RANDOM}"
    launch_attempted=1
    hyprctl -i 0 eval "hl.exec_cmd(\"env WILLOW_SYNC_DEPLOY=$launch_token qs -p /home/moarchy/.config/quickshell/willow.qml\")"
    i=0
    while [ "$i" -lt 24 ]; do
        for candidate in $(pgrep -f '^qs -p /home/moarchy/.config/quickshell/willow.qml$' || true); do
            if [ -r "/proc/$candidate/environ" ] \
                && tr '\0' '\n' < "/proc/$candidate/environ" | grep -Fqx "WILLOW_SYNC_DEPLOY=$launch_token"; then
                new_qs_pid=$candidate
                return 0
            fi
        done
        sleep 0.25
        i=$((i+1))
    done
    return 1
}
rollback_deploy() {
    [ "$completed" -eq 0 ] || return 0
    set +e
    if [ -n "$new_qs_pid" ] && kill -0 "$new_qs_pid" 2>/dev/null; then
        kill -TERM "$new_qs_pid" 2>/dev/null || true
        i=0
        while kill -0 "$new_qs_pid" 2>/dev/null && [ "$i" -lt 20 ]; do
            sleep 0.25
            i=$((i+1))
        done
        if kill -0 "$new_qs_pid" 2>/dev/null; then
            new_qs_stop_failed=1
            echo "rollback could not stop task-launched Quickshell process $new_qs_pid; will not start another engine" >&2
        fi
    fi
    if [ "$launch_attempted" -eq 1 ] && [ -z "$new_qs_pid" ] \
        && pgrep -f '^qs -p /home/moarchy/.config/quickshell/willow.qml$' >/dev/null; then
        new_qs_stop_failed=1
        echo 'rollback found an untracked Quickshell instance; will not start another engine' >&2
    fi
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
    if { [ "$qs_terminated" -eq 1 ] || [ "$launch_attempted" -eq 1 ]; } \
        && [ "$new_qs_stop_failed" -eq 0 ] && [ "$qs_stopped" -eq 0 ]; then
        rollback_token="willow-rollback-${BASHPID}-${RANDOM}"
        hyprctl -i 0 eval "hl.exec_cmd(\"env WILLOW_SYNC_DEPLOY=$rollback_token qs -p /home/moarchy/.config/quickshell/willow.qml\")" >/dev/null 2>&1 || true
        i=0
        restored_qs_pid=
        while [ "$i" -lt 24 ]; do
            for candidate in $(pgrep -f '^qs -p /home/moarchy/.config/quickshell/willow.qml$' || true); do
                if [ -r "/proc/$candidate/environ" ] \
                    && tr '\0' '\n' < "/proc/$candidate/environ" | grep -Fqx "WILLOW_SYNC_DEPLOY=$rollback_token"; then
                    restored_qs_pid=$candidate
                    break
                fi
            done
            [ -n "$restored_qs_pid" ] && break
            sleep 0.25
            i=$((i+1))
        done
        if [ -z "$restored_qs_pid" ]; then
            echo 'rollback restored files but could not relaunch its Quickshell process' >&2
        fi
    fi
}
trap rollback_deploy EXIT
trap 'exit 1' HUP INT TERM

for file in "${helpers[@]}"; do
    sudo -n install -o root -g root -m 0755 \
        "device/usr/local/bin/$file" "/usr/local/bin/$file"
done

[ -z "$qs_pid" ] || { kill -STOP "$qs_pid"; qs_stopped=1; }
if [ -e "$marker" ]; then
    [ -z "$qs_pid" ] || { kill -CONT "$qs_pid"; qs_stopped=0; }
    echo 'refusing shell deployment: session lock marker appeared during preflight' >&2
    exit 1
fi
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
# The controller is last so the new engine cannot load incomplete components.
install -o moarchy -g moarchy -m 0644 \
    device/home/moarchy/.config/quickshell/willow.qml \
    "$HOME/.config/quickshell/willow.qml"

if [ -n "$qs_pid" ]; then
    kill -TERM "$qs_pid" 2>/dev/null || true
    kill -CONT "$qs_pid" 2>/dev/null || true
    qs_stopped=0
    i=0
    while kill -0 "$qs_pid" 2>/dev/null && [ "$i" -lt 20 ]; do
        sleep 0.25
        i=$((i+1))
    done
    if kill -0 "$qs_pid" 2>/dev/null; then
        echo "old Quickshell process $qs_pid did not exit after TERM" >&2
        exit 1
    fi
    qs_terminated=1
fi
launch_qs || { echo 'new Quickshell process did not start from this deployment' >&2; exit 1; }
sleep 2
qs ipc --pid "$new_qs_pid" show | grep -q '^target willow$' || {
    echo 'new Quickshell process has no Willow IPC target' >&2
    exit 1
}
if [ "$home_was_visible" = true ]; then
    qs ipc --pid "$new_qs_pid" call willow goHome
fi
runtime_errors=$(qs log --pid "$new_qs_pid" --tail 100 2>&1 \
    | grep -E 'ERROR.*scene|scene.*(TypeError|ReferenceError)' || true)
if [ -n "$runtime_errors" ]; then
    printf '%s\n' "$runtime_errors" >&2
    echo 'new Quickshell process reported QML runtime errors' >&2
    exit 1
fi
errors=$(hyprctl -i 0 configerrors)
case $errors in ''|ok) ;; *) printf '%s\n' "$errors" >&2; exit 1 ;; esac
printf 'lock_marker=%s lock_restore=' "$([ -e "$marker" ] && echo present || echo absent)"
hyprctl -i 0 getoption misc:allow_session_lock_restore
completed=1
trap - EXIT HUP INT TERM
printf 'deployed; qs_pid=%s backup=%s\n' \
    "$new_qs_pid" "$rollback"
REMOTE

ssh "${SSH[@]}" "$PHONE" 'willow-compositor status'
