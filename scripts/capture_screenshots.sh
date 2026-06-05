#!/usr/bin/env bash
# Capture README screenshots interactively (run in your own terminal, not Cursor agent).
#
# Requires macOS Screen Recording permission for Terminal / WezTerm.
# The Cursor agent cannot capture your display — run this script locally.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/doc/screenshots"
mkdir -p "$OUT"

capture_interactive() {
  local demo_lua="$1"
  local output="$2"
  local label="$3"

  echo ""
  echo "==> $label"
  echo "    Opening demo..."
  wezterm start --always-new-process --position 160,90 -- \
    nvim --cmd "set columns=100 lines=30" --cmd "cd $ROOT" --cmd "luafile $demo_lua" &
  sleep 2
  echo "    Click the WezTerm window to save: $output"
  screencapture -iW "$output"
  echo "    Saved $output"
  sleep 0.5
}

capture_interactive "$ROOT/scripts/demo_screenshot.lua" "$OUT/picker-with-preview.png" \
  "Picker with history list + syntax-highlighted preview"

capture_interactive "$ROOT/scripts/demo_screenshot_empty.lua" "$OUT/picker-empty.png" \
  "Empty ring (list only, no preview pane)"

echo ""
echo "Done. Add these to the README:"
echo "  doc/screenshots/picker-with-preview.png"
echo "  doc/screenshots/picker-empty.png"
