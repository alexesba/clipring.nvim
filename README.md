# ClipRing.nvim

Minimal yank history for Neovim — a lightweight Lua plugin inspired by YankRing and Windows Clipboard History. No required dependencies.

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
  dir = "/path/to/clipring", -- or your fork after publishing
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
use({ "your-user/clipring.nvim", config = function() require("clipring").setup() end })
```

**Important:** call `require("clipring").setup()` to enable yank capture and optional persistence. The `:ClipRing` command is available without `setup`, but history will stay empty until you configure it.

## Usage

| Key / command | Action |
|---------------|--------|
| `:ClipRing` | Open history popup (always available) |
| your `open_mapping` | Open popup when set in `setup()` (e.g. `<leader>y`) |
| `j` / `k` (also `J` / `K`) | Move selection |
| `<C-j>` / `<C-k>` | Move selected entry down / up in history order |
| `<Enter>` | Paste selected entry and close |
| `dd` | Remove selected entry from history |
| `q` / `<Esc>` | Close without pasting |

While the picker is open, `<C-w>` does not switch windows (close the picker first, like Telescope).

In **Insert** mode, `<Enter>` pastes at the cursor without leaving Insert. In **Visual** mode, the selected text is replaced by the chosen entry.

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

If `<C-j>` / `<C-k>` still move lines in the picker (conflict with a global `:move` map), set different keys, e.g. `reorder_down_mapping = "<A-j>"`.

## Tests

Specs use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) and run inside headless Neovim:

```bash
./scripts/run_tests.sh
```

Set `PLENARY_DIR` if plenary is already on disk:

```bash
PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim ./scripts/run_tests.sh
```

Coverage today:

- **ring** — add, dedupe, max size, remove
- **paste** — visual capture (`v` / `'<`), charwise replace vs append, insert-mode paste at saved cursor
- **ui** — picker normal mode from insert, `j`/`k` navigation, insert restore on close, paste from picker
- **yank** — `TextYankPost` capture

## Roadmap

Possible future work: Telescope picker, system clipboard, preview pane, bulk delete.

## License

MIT
