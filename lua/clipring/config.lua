local M = {}

---@class ClipRingConfig
---@field max_entries number
---@field persist boolean
---@field persist_path string
---@field preview_length number
---@field deduplicate boolean
---@field min_length number
---@field open_mapping string|nil
---@field reorder_down_mapping string|false|nil move selected entry down in picker (default `<C-j>`)
---@field reorder_up_mapping string|false|nil move selected entry up in picker (default `<C-k>`)

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
