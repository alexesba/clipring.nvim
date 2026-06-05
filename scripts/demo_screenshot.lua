--- Demo buffer + yank history for README screenshots.
--- Usage: nvim --cmd "set rtp+=..." --cmd "luafile scripts/demo_screenshot.lua"

local root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p"):gsub("/$", "")

vim.opt.rtp:prepend(root)
vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.signcolumn = "yes"
vim.cmd("colorscheme default")

vim.api.nvim_buf_set_lines(0, 0, -1, true, {
  'require("clipring").setup({',
  '  open_mapping = "<leader>y",',
  "  persist = true,",
  "  preview_syntax = true,",
  "})",
  "",
  "-- Yank history opens with :ClipRing",
})
vim.bo.filetype = "lua"

require("clipring").setup({
  open_mapping = nil,
  preview_syntax = true,
  picker_width = 86,
  picker_max_height = 14,
  preview_max_lines = 12,
})

local ring = require("clipring.ring")
ring.clear()
ring.add({ "Hello from ClipRing!" }, "v")
ring.add({
  "class Widget",
  "  def name",
  "    'clipring'",
  "  end",
  "end",
}, "V")
ring.add({
  "```lua",
  'require("clipring").setup({',
  '  open_mapping = "<leader>y",',
  "  preview_syntax = true,",
  "})",
  "```",
}, "V")

vim.defer_fn(function()
  require("clipring.ui").open()
end, 250)
