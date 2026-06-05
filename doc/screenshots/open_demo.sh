#!/usr/bin/env bash
# Open a ClipRing demo in WezTerm for manual screenshots.
# Usage: ./doc/screenshots/open_demo.sh [full|empty]
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
MODE="${1:-full}"

case "$MODE" in
  full)
    DEMO="$DIR/demo.lua"
    ;;
  empty)
    DEMO="$DIR/demo_empty.lua"
    ;;
  *)
    echo "Usage: $0 [full|empty]" >&2
    exit 1
    ;;
esac

exec wezterm start --always-new-process --position 160,90 -- \
  nvim --clean --cmd "set columns=100 lines=32" --cmd "cd $ROOT" --cmd "luafile $DEMO"
