local M = {}

---@class ClipRingConfig
---@field max_entries number
---@field persist boolean
---@field persist_path string
---@field preview_length number max chars in each one-line list label
---@field deduplicate boolean
---@field min_length number
---@field open_mapping string|string[]|false|nil keymap(s) to open picker (`nil` = `:ClipRing` only)
---@field reorder_down_mapping string|false|nil move selected entry down in picker (default `<C-j>`)
---@field reorder_up_mapping string|false|nil move selected entry up in picker (default `<C-k>`)
---@field copy_mapping string|false|nil copy selected entry to system clipboard in picker (default `y`)
---@field clear_all_mapping string|false|nil clear entire history in picker with confirmation (default `C`)
---@field help_mapping string|false|nil which-key cheat-sheet key in picker (default `g?`; only when which-key is installed)
---@field picker_width number total inner width of list + preview (`0` = nearly full editor width)
---@field list_width number width of the history list (`0` = auto; fixed width is advanced)
---@field preview_max_width number max preview width (`0` = content width up to screen edge)
---@field picker_max_height number max height of list and preview panes (lines)
---@field preview_max_lines number max lines shown in the preview pane for one entry
---@field preview_syntax boolean highlight preview when a code filetype is detected

M.defaults = {
  max_entries = 100,
  persist = false,
  persist_path = vim.fn.stdpath("data") .. "/clipring/history.json",
  preview_length = 80,
  deduplicate = true,
  min_length = 1,
  open_mapping = nil,
  reorder_down_mapping = "<C-j>",
  reorder_up_mapping = "<C-k>",
  copy_mapping = "y",
  clear_all_mapping = "C",
  help_mapping = "g?",
  picker_width = 80,
  list_width = 0,
  preview_max_width = 0,
  picker_max_height = 18,
  preview_max_lines = 16,
  preview_syntax = true,
}

---@type ClipRingConfig
M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

function M.get()
  return M.options
end

return M
