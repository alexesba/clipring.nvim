local ring = require("clipring.ring")

local M = {}
local augroup = nil

function M.setup()
  if augroup then
    return
  end

  augroup = vim.api.nvim_create_augroup("ClipRing", { clear = true })

  vim.api.nvim_create_autocmd("TextYankPost", {
    group = augroup,
    desc = "ClipRing: capture yanks",
    callback = function()
      local event = vim.v.event
      if event.operator ~= "y" then
        return
      end

      local regname = event.regname
      if regname == "" then
        regname = '"'
      end

      local lines = vim.fn.getreg(regname, 1, true)
      if type(lines) == "string" then
        lines = { lines }
      end

      local regtype = vim.fn.getregtype(regname)
      ring.add(lines, regtype)
    end,
  })
end

return M
