local M = {}

--- Disable which-key in ClipRing picker buffers (same idea as TelescopePrompt).
function M.setup()
  local ok, wk_config = pcall(require, "which-key.config")
  if not ok or not wk_config.disable or not wk_config.disable.ft then
    return
  end
  if not vim.tbl_contains(wk_config.disable.ft, "clipring") then
    table.insert(wk_config.disable.ft, "clipring")
  end
end

return M
