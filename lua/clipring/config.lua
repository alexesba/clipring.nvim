local M = {}

---@class ClipRingConfig
---@field max_entries number
---@field persist boolean
---@field persist_path string
---@field preview_length number
---@field deduplicate boolean
---@field min_length number
---@field open_mapping string|nil

M.defaults = {
  max_entries = 100,
  persist = false,
  persist_path = vim.fn.stdpath("data") .. "/clipring/history.json",
  preview_length = 80,
  deduplicate = true,
  min_length = 1,
  open_mapping = nil,
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
