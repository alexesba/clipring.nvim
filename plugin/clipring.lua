if vim.g.loaded_clipring then
  return
end
vim.g.loaded_clipring = true

vim.api.nvim_create_user_command("ClipRing", function()
  require("clipring").open()
end, { desc = "Open ClipRing yank history" })
