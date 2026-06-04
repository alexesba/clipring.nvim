local config = require("clipring.config")
local yank = require("clipring.yank")
local persist = require("clipring.persist")
local ui = require("clipring.ui")

local M = {}

function M.setup(opts)
  config.setup(opts)
  yank.setup()
  persist.setup()

  local open_map = config.get().open_mapping
  if open_map and open_map ~= "" then
    vim.keymap.set("i", open_map, function()
      M.open({ from_insert = true })
    end, { desc = "Open ClipRing history", silent = true })
    vim.keymap.set({ "n", "v", "x" }, open_map, function()
      M.open()
    end, { desc = "Open ClipRing history", silent = true })
  end
end

---@param opts table|nil passed to ui.open (e.g. { from_insert = true })
function M.open(opts)
  ui.open(opts)
end

function M.close()
  ui.close()
end

return M
