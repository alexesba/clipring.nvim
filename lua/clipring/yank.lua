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

      local filetype = vim.bo.filetype
      if filetype == "" or filetype == "clipring" or filetype == "clipring_preview" then
        filetype = nil
      end

      ring.add(lines, regtype, filetype)
    end,
  })
end

return M
