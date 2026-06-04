local config = require("clipring.config")
local yank = require("clipring.yank")
local persist = require("clipring.persist")
local ui = require("clipring.ui")
local which_key = require("clipring.which_key")

local M = {}

---@type { mode: string, lhs: string }[]
local open_keymaps = {}

local function clear_open_keymaps()
  for _, km in ipairs(open_keymaps) do
    pcall(vim.keymap.del, km.mode, km.lhs)
  end
  open_keymaps = {}
end

local function register_open_keymap(lhs)
  if type(lhs) ~= "string" or lhs == "" then
    return
  end

  local desc = "Open ClipRing history"
  vim.keymap.set("i", lhs, function()
    M.open({ from_insert = true })
  end, { desc = desc, silent = true })
  table.insert(open_keymaps, { mode = "i", lhs = lhs })

  for _, mode in ipairs({ "n", "v", "x" }) do
    vim.keymap.set(mode, lhs, function()
      M.open()
    end, { desc = desc, silent = true })
    table.insert(open_keymaps, { mode = mode, lhs = lhs })
  end
end

---@param open_mapping string|string[]|false|nil
local function apply_open_mapping(open_mapping)
  clear_open_keymaps()
  if open_mapping == false or open_mapping == nil or open_mapping == "" then
    return
  end
  if type(open_mapping) == "table" then
    for _, lhs in ipairs(open_mapping) do
      register_open_keymap(lhs)
    end
    return
  end
  register_open_keymap(open_mapping)
end

function M.setup(opts)
  config.setup(opts)
  which_key.setup()
  yank.setup()
  persist.setup()
  apply_open_mapping(config.get().open_mapping)
end

---@param opts table|nil passed to ui.open (e.g. { from_insert = true })
function M.open(opts)
  ui.open(opts)
end

function M.close()
  ui.close()
end

return M
