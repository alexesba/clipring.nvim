#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLENARY_DIR="${PLENARY_DIR:-$ROOT/deps/plenary.nvim}"

if [[ ! -d "$PLENARY_DIR" ]]; then
  echo "Cloning plenary.nvim into $PLENARY_DIR ..."
  mkdir -p "$(dirname "$PLENARY_DIR")"
  git clone --depth 1 https://github.com/nvim-lua/plenary.nvim "$PLENARY_DIR"
fi

export PLENARY_DIR
cd "$ROOT"

nvim --headless \
  -u tests/minimal_init.lua \
  -c "lua require('plenary.test_harness').test_directory('tests', { minimal_bust = true })" \
  -c "qa!"

echo "All specs passed."
