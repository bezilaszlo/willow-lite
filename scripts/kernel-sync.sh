#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
KSRC=${KSRC:-/home/bezi/Work/linux-sm6125}
BASE="$ROOT/kernel/base.txt"
PATCHES="$ROOT/kernel/patches"
MODE=${1:-}
TREE=${2:-$KSRC}

usage() { echo "usage: $0 apply|export|squash [tree]" >&2; exit 2; }

field() { awk -v k="$1" '$1 == k { print $2 }' "$BASE"; }
TAG=$(field tag)
COMMIT=$(field commit)
REMOTE=$(field remote)
BRANCH="willow/$TAG"
test -n "$TAG" && test -n "$COMMIT" && test -n "$REMOTE" || { echo "bad $BASE" >&2; exit 1; }

case "$MODE" in
  apply)
    if [ ! -d "$TREE/.git" ]; then
      git clone --depth 1 --branch "$TAG" "$REMOTE" "$TREE"
    fi
    test -z "$(git -C "$TREE" status --porcelain)" || { echo "$TREE is dirty" >&2; exit 1; }
    if ! git -C "$TREE" cat-file -e "$COMMIT^{commit}" 2>/dev/null; then
      git -C "$TREE" fetch --depth 1 "$REMOTE" "refs/tags/$TAG"
    fi
    git -C "$TREE" cat-file -e "$COMMIT^{commit}" || { echo "$COMMIT not found in $TREE" >&2; exit 1; }
    if git -C "$TREE" rev-parse -q --verify "refs/heads/$BRANCH" >/dev/null; then
      AHEAD=$(git -C "$TREE" rev-list --count "$COMMIT..$BRANCH")
      if [ "$AHEAD" -gt 0 ] && [ "${FORCE:-0}" != 1 ]; then
        echo "$BRANCH has $AHEAD commits above base; run '$0 export' first or set FORCE=1" >&2
        exit 1
      fi
    fi
    git -C "$TREE" switch -q -C "$BRANCH" "$COMMIT"
    if compgen -G "$PATCHES/*.patch" >/dev/null; then
      git -C "$TREE" am --keep-cr "$PATCHES"/*.patch
    fi
    git -C "$TREE" log --oneline "$COMMIT..HEAD"
    ;;
  squash)
    GIT_SEQUENCE_EDITOR=true git -C "$TREE" rebase -i --autosquash "$COMMIT"
    ;;
  export)
    test -z "$(git -C "$TREE" status --porcelain)" || { echo "$TREE is dirty" >&2; exit 1; }
    if git -C "$TREE" log --format=%s "$COMMIT..HEAD" | grep -q '^fixup!'; then
      echo "fixup commits present; run '$0 squash' first" >&2
      exit 1
    fi
    rm -f "$PATCHES"/*.patch
    mkdir -p "$PATCHES"
    git -C "$TREE" format-patch --zero-commit --no-signature --keep-subject -o "$PATCHES" "$COMMIT..HEAD"
    ;;
  *) usage ;;
esac
