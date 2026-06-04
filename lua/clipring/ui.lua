local config = require("clipring.config")
local ring = require("clipring.ring")
local paste = require("clipring.paste")
local persist = require("clipring.persist")

local M = {}

local state = {
  buf = nil,
  win = nil,
  opener_win = nil,
  opener_mode = "n",
  visual_marks = nil,
  index = 1,
}

local ns = vim.api.nvim_create_namespace("ClipRing")

local function preview_line(entry)
  local opts = config.get()
  local text = table.concat(entry.lines, " "):gsub("\t", " "):gsub("%s+", " ")
  if #text > opts.preview_length then
    text = text:sub(1, opts.preview_length - 3) .. "..."
  end
  if text == "" then
    text = "(empty)"
  end
  local kind = "c"
  if entry.regtype == "V" then
    kind = "l"
  elseif entry.regtype == "\022" or entry.regtype:find("^%d") or entry.regtype == "^V" then
    kind = "b"
  end
  return string.format("[%s] %s", kind, text)
end

local function refresh_buffer()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local lines = {}
  local all = ring.get_all()
  if #all == 0 then
    lines = { "No yanks yet. Copy something with y or Y." }
    state.index = 1
  else
    if state.index > #all then
      state.index = #all
    end
    if state.index < 1 then
      state.index = 1
    end
    for i, entry in ipairs(all) do
      local prefix = (i == state.index) and "▸ " or "  "
      table.insert(lines, prefix .. preview_line(entry))
    end
  end

  vim.api.nvim_buf_set_option(state.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.buf, "modifiable", false)

  if #all > 0 then
    vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
    vim.api.nvim_buf_add_highlight(state.buf, ns, "CursorLine", state.index - 1, 0, -1)
  end
end

local function close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  if state.opener_win and vim.api.nvim_win_is_valid(state.opener_win) then
    vim.api.nvim_set_current_win(state.opener_win)
  end
  state.buf = nil
  state.win = nil
  state.opener_win = nil
  state.visual_marks = nil
end

local function select_current()
  local all = ring.get_all()
  if #all == 0 then
    close()
    return
  end

  local entry = all[state.index]
  if not entry then
    close()
    return
  end

  local mode = state.opener_mode
  local marks = state.visual_marks
  local opener_win = state.opener_win
  close()
  paste.apply(entry, mode, marks, opener_win)
end

local function delete_current()
  local all = ring.get_all()
  if #all == 0 then
    return
  end

  ring.remove(state.index)
  persist.save()

  if ring.count() == 0 then
    state.index = 1
  elseif state.index > ring.count() then
    state.index = ring.count()
  end

  refresh_buffer()
end

local function move(delta)
  local count = ring.count()
  if count == 0 then
    return
  end
  state.index = ((state.index - 1 + delta) % count) + 1
  refresh_buffer()
end

local function attach_keymaps()
  local opts = { buffer = state.buf, silent = true, nowait = true }

  local function map(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, opts)
  end

  map("j", function()
    move(1)
  end)
  map("k", function()
    move(-1)
  end)
  map("<Down>", function()
    move(1)
  end)
  map("<Up>", function()
    move(-1)
  end)
  map("<CR>", function()
    select_current()
  end)
  map("dd", function()
    delete_current()
  end)
  map("q", function()
    close()
  end)
  map("<Esc>", function()
    close()
  end)
end

function M.open()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    refresh_buffer()
    vim.api.nvim_set_current_win(state.win)
    return
  end

  state.opener_win = vim.api.nvim_get_current_win()
  state.opener_mode = vim.fn.mode()
  state.visual_marks = paste.capture_visual_marks(state.opener_win, state.opener_mode)
  state.index = 1

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(state.buf, "clipring://history")
  vim.api.nvim_buf_set_option(state.buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(state.buf, "filetype", "clipring")
  vim.api.nvim_buf_set_option(state.buf, "swapfile", false)

  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(15, ring.count())
  if height < 3 then
    height = 3
  end

  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " ClipRing ",
    title_pos = "center",
  })

  attach_keymaps()
  refresh_buffer()

  if ring.count() > 0 then
    vim.api.nvim_win_set_cursor(state.win, { state.index, 0 })
  end
end

function M.close()
  close()
end

return M
