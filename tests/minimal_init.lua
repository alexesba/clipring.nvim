local root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")
vim.opt.rtp:append(root)

local plenary = os.getenv("PLENARY_DIR") or (root .. "deps/plenary.nvim")
if vim.fn.isdirectory(plenary) == 1 then
  vim.opt.rtp:append(plenary)
else
  vim.api.nvim_echo({
    {
      "ClipRing tests: plenary.nvim not found at " .. plenary .. "\nRun: scripts/run_tests.sh",
      "ErrorMsg",
    },
  }, true, {})
  vim.cmd("cquit 1")
end

require("clipring").setup({
  max_entries = 20,
  deduplicate = true,
  min_length = 1,
  persist = false,
})
