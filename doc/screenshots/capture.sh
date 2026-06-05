#!/usr/bin/env bash
# Maintainer helper: capture README screenshots (macOS + WezTerm).
# Run from your own terminal — not from Cursor's agent shell.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"

NVIM_OPTS=(
  --clean
  --cmd "set columns=100 lines=32"
  --cmd "cd $ROOT"
)

capture_interactive() {
  local demo_lua="$1"
  local output="$2"
  local label="$3"
  local wait="${4:-3}"

  echo ""
  echo "==> $label"
  echo "    Opening demo..."
  wezterm start --always-new-process --position 160,90 -- \
    nvim "${NVIM_OPTS[@]}" --cmd "luafile $demo_lua" &
  sleep "$wait"
  echo "    Click the WezTerm window to save: $output"
  screencapture -iW "$output"
  echo "    Saved $output"
  sleep 0.5
}

case "${1:-all}" in
  full|with-preview|preview)
    capture_interactive "$DIR/demo.lua" "$DIR/picker-with-preview.png" \
      "Picker with history list + syntax-highlighted preview" 3.5
    ;;
  empty)
    capture_interactive "$DIR/demo_empty.lua" "$DIR/picker-empty.png" \
      "Empty ring (list only, no preview pane)" 3
    ;;
  all)
    capture_interactive "$DIR/demo.lua" "$DIR/picker-with-preview.png" \
      "Picker with history list + syntax-highlighted preview" 3.5
    capture_interactive "$DIR/demo_empty.lua" "$DIR/picker-empty.png" \
      "Empty ring (list only, no preview pane)" 3
    ;;
  *)
    echo "Usage: $0 [all|full|empty]" >&2
    exit 1
    ;;
esac

echo ""
echo "Done. Screenshots in $DIR"
