#!/usr/bin/env bash
set -u

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    echo "usage: $0 <binary> <margin|legacy> <fresh-run-directory> [exclusive|nonexclusive]" >&2
    exit 2
fi

binary=$1
margin=$2
run_dir=$3
policy=${4:-exclusive}

case "$margin" in
    0|30)
        keyboard_args=(-H 310 --bottom-margin "$margin" --hidden --wayland-layer top)
        ;;
    legacy)
        keyboard_args=(-H 310 --hidden --wayland-layer top)
        ;;
    *) echo "margin must be 0, 30, or legacy" >&2; exit 2 ;;
esac
case "$policy" in
    exclusive) ;;
    nonexclusive) keyboard_args+=(--non-exclusive) ;;
    *) echo "policy must be exclusive or nonexclusive" >&2; exit 2 ;;
esac
if [ ! -x "$binary" ]; then
    echo "keyboard binary is not executable: $binary" >&2
    exit 2
fi
if [ -e "$run_dir" ]; then
    echo "run directory already exists: $run_dir" >&2
    exit 2
fi
mkdir -m 0700 -- "$run_dir" || exit 2

binary_sha256=$(sha256sum "$binary" | cut -d ' ' -f1)
{
    printf 'binary=%s\n' "$binary"
    printf 'binary_sha256=%s\n' "$binary_sha256"
    printf 'arguments='
    printf '%q ' "${keyboard_args[@]}"
    printf '\n'
    printf 'policy=%s\n' "$policy"
    printf 'runner_pid=%s\n' "$$"
} >"$run_dir/launch.txt"

"$binary" "${keyboard_args[@]}" >"$run_dir/stderr.log" 2>&1 &
child_pid=$!
printf '%s\n' "$child_pid" >"$run_dir/child.pid"

wait "$child_pid"
wait_status=$?
printf 'child_wait_status=%s\n' "$wait_status" >"$run_dir/wait-status.txt"
