local M = {}

function M.reset()
  require("clipring.config").setup({
    max_entries = 20,
    deduplicate = true,
    min_length = 1,
    persist = false,
  })
  require("clipring.ring").clear()
end

---@param lines string[]
---@return number, number
function M.open_buf(lines)
  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = 80,
    height = 12,
    row = 2,
    col = 2,
    style = "minimal",
  })
  return buf, win
end

---@param buf number
---@param lnum number 1-indexed line
---@param col number 1-indexed byte column
---@return number[]
function M.pos(buf, lnum, col)
  return { buf, lnum, col, 0 }
end

--- Charwise visual selection (1-indexed line/column for marks).
---@param win number
---@param start {[1]:number,[2]:number,[3]:number}
---@param end_ {[1]:number,[2]:number,[3]:number}
---@return string mode
function M.charwise_visual(win, start, end_)
  vim.api.nvim_win_set_cursor(win, { start[2], start[3] - 1 })
  vim.cmd("normal! v")
  vim.api.nvim_win_set_cursor(win, { end_[2], end_[3] - 1 })
  return vim.fn.mode()
end

---@param buf number
---@return string
function M.buf_text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

---@param entry { lines: string[], regtype: string }
function M.entry(lines, regtype)
  return { lines = lines, regtype = regtype or "v" }
end

return M
