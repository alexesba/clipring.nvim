#!/usr/bin/env bash
# Open a ClipRing demo in WezTerm for README screenshots.
# Usage: ./scripts/open_screenshot_demo.sh [full|empty]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-full}"

case "$MODE" in
  full)
    DEMO="$ROOT/scripts/demo_screenshot.lua"
    ;;
  empty)
    DEMO="$ROOT/scripts/demo_screenshot_empty.lua"
    ;;
  *)
    echo "Usage: $0 [full|empty]" >&2
    exit 1
    ;;
esac

exec wezterm start --always-new-process --position 160,90 -- \
  nvim --clean --cmd "set columns=100 lines=32" --cmd "cd $ROOT" --cmd "luafile $DEMO"
