local M = {}

---@return boolean
function M.available()
  local ok, wk = pcall(require, "which-key")
  return ok and type(wk.show) == "function"
end

---Show a cheat-sheet of the current buffer's mappings via which-key.
---No-op when which-key is not installed.
function M.show_help()
  if not M.available() then
    return
  end
  require("which-key").show({ global = false })
end

return M
