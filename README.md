# clipring.nvim

[![Tests](https://github.com/alexesba/clipring.nvim/actions/workflows/test.yml/badge.svg)](https://github.com/alexesba/clipring.nvim/actions/workflows/test.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Minimal yank history for Neovim — a lightweight Lua plugin inspired by YankRing and Windows Clipboard History. No required dependencies.

**Repository:** [github.com/alexesba/clipring.nvim](https://github.com/alexesba/clipring.nvim)

## Features

- Automatic capture of every yank
- Floating popup history (`:ClipRing`)
- Navigate with `j` / `k`, reorder with `<C-j>` / `<C-k>`, paste with `<Enter>`, delete with `dd`
- Works from Normal, Insert, and Visual modes
- Optional JSON persistence between sessions
- Configurable history size and keymaps

## Requirements

- Neovim 0.9+

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "alexesba/clipring.nvim",
  config = function()
    require("clipring").setup({
      max_entries = 100,
      persist = true,
      open_mapping = "<leader>y",
    })
  end,
}
```

With [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use({ "alexesba/clipring.nvim", config = function() require("clipring").setup() end })
```

With a minimal `lazy.nvim` / `packer.nvim` setup, Neovim loads the plugin from `lua/clipring/` automatically after install.

**Important:** call `require("clipring").setup()` to enable yank capture and optional persistence. The `:ClipRing` command is registered without `setup`, but the ring stays empty until you configure it.

## Usage

### Open the picker

| How | When |
|-----|------|
| `:ClipRing` | Always available (no keymap required) |
| Your `open_mapping` | After you set one in `setup()` (e.g. `<leader>y`) |

The picker opens as a centered floating window listing recent yanks (newest first). Each line shows the register type (`c` charwise, `l` linewise, `b` block) and a short preview.

### Inside the picker

| Key | Action |
|-----|--------|
| `j` / `k` or `J` / `K` | Move selection up / down |
| `<Up>` / `<Down>` | Same as `k` / `j` |
| `<C-j>` / `<C-k>` | Move the **selected entry** down / up in history order (reorder) |
| `<Enter>` | Paste the selected entry and close |
| `dd` | Delete the selected entry from history |
| `q` or `<Esc>` | Close without pasting |

While the picker is focused, `<C-w>` does not switch windows or open which-key (close the picker first, like Telescope). If you use [which-key.nvim](https://github.com/folke/which-key.nvim), `setup()` registers the `clipring` filetype so which-key stays off in the picker buffer.

### Paste behavior by mode

**Normal** — Pastes at the cursor position when you opened the picker. Linewise and charwise entries use the saved position (including end-of-line and empty lines).

**Insert** — Pastes at the cursor without leaving Insert mode. Trailing spaces and end-of-file positions are preserved.

**Visual** — Replaces the current visual selection with the chosen entry. Open ClipRing **while still in visual mode** so the selection is captured; stale `'<` / `'>` marks from an earlier visual session are ignored when you open from Normal mode.

### Typical workflow

1. Yank text as usual (`y`, `yy`, visual yank, etc.).
2. Open ClipRing (`:ClipRing` or your mapping).
3. Use `j` / `k` to highlight an entry, optionally `<C-j>` / `<C-k>` to reorder favorites.
4. Press `<Enter>` to paste, or `q` to cancel.

With `persist = true`, history is restored after you restart Neovim (stored under `persist_path`).

## Configuration

```lua
require("clipring").setup({
  max_entries = 100,       -- max items in ring
  persist = false,           -- save history to disk
  persist_path = vim.fn.stdpath("data") .. "/clipring/history.json",
  preview_length = 80,       -- chars shown per line in popup
  deduplicate = true,        -- move duplicates to top instead of re-adding
  min_length = 1,            -- ignore yanks shorter than this (chars)
  open_mapping = "<leader>y",  -- string, list of strings, or false (nil = no keymap)
  reorder_down_mapping = "<C-j>", -- picker: move entry down in history (false to disable)
  reorder_up_mapping = "<C-k>",   -- picker: move entry up in history (false to disable)
})
```

**`open_mapping`** — set a string (e.g. `"<leader>y"`) or multiple (`{ "<leader>y", "<M-y>" }`) to open ClipRing from Normal, Visual, and Insert. Leave unset or `nil` to use only `:ClipRing`. Use `false` to clear a keymap after a previous `setup()`.

Omit `reorder_down_mapping` / `reorder_up_mapping` to keep the defaults above. Set either to `false` to turn off that binding.

If `<C-j>` / `<C-k>` conflict with global maps (e.g. `:move`), use different keys: `reorder_down_mapping = "<A-j>"`.

## Tests

Specs run on every push to `main` and on pull requests via [GitHub Actions](https://github.com/alexesba/clipring.nvim/actions/workflows/test.yml).

Locally, tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) inside headless Neovim:

```bash
git clone https://github.com/alexesba/clipring.nvim.git
cd clipring.nvim
./scripts/run_tests.sh
```

Set `PLENARY_DIR` if plenary is already on disk:

```bash
PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim ./scripts/run_tests.sh
```

Coverage today:

- **ring** — add, dedupe, max size, remove, reorder
- **paste** — visual capture (`v` / `'<`), charwise replace vs append, insert-mode paste at saved cursor
- **ui** — picker from insert, navigation, reorder keys, which-key / `<C-w>` behavior
- **yank** — `TextYankPost` capture
- **setup** — `open_mapping` registration

## Roadmap

Possible future work: Telescope picker, system clipboard, preview pane, bulk delete.

## License

MIT
