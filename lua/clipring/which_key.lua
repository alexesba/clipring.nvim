local M = {}

--- Disable which-key in ClipRing picker buffers (same idea as TelescopePrompt).
function M.setup()
  local ok, wk_config = pcall(require, "which-key.config")
  if not ok or not wk_config.disable or not wk_config.disable.ft then
    return
  end
  for _, ft in ipairs({ "clipring", "clipring_preview" }) do
    if not vim.tbl_contains(wk_config.disable.ft, ft) then
      table.insert(wk_config.disable.ft, ft)
    end
  end
end

return M
