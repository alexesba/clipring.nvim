#!/usr/bin/env bash
# Capture README screenshots interactively (run in your own terminal, not Cursor agent).
#
# Uses `nvim --clean` so your personal config does not override the demo yanks.
# Requires macOS Screen Recording permission for Terminal / WezTerm.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/doc/screenshots"
mkdir -p "$OUT"

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
    capture_interactive "$ROOT/scripts/demo_screenshot.lua" "$OUT/picker-with-preview.png" \
      "Picker with history list + syntax-highlighted preview" 3.5
    ;;
  empty)
    capture_interactive "$ROOT/scripts/demo_screenshot_empty.lua" "$OUT/picker-empty.png" \
      "Empty ring (list only, no preview pane)" 3
    ;;
  all)
    capture_interactive "$ROOT/scripts/demo_screenshot.lua" "$OUT/picker-with-preview.png" \
      "Picker with history list + syntax-highlighted preview" 3.5
    capture_interactive "$ROOT/scripts/demo_screenshot_empty.lua" "$OUT/picker-empty.png" \
      "Empty ring (list only, no preview pane)" 3
    ;;
  *)
    echo "Usage: $0 [all|full|empty]" >&2
    exit 1
    ;;
esac

echo ""
echo "Done. Screenshots in $OUT"
