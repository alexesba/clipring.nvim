--- Empty ring demo for README screenshots (list only, no preview pane).

local root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p"):gsub("/$", "")

vim.opt.rtp:prepend(root)
vim.opt.termguicolors = true
vim.opt.number = true
vim.cmd("colorscheme default")

vim.api.nvim_buf_set_lines(0, 0, -1, true, {
  "-- Copy something with y, then open ClipRing",
  "",
})
vim.bo.filetype = "lua"

require("clipring").setup({ open_mapping = nil })
require("clipring.ring").clear()

vim.defer_fn(function()
  require("clipring.ui").open()
end, 250)
