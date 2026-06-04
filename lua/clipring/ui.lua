local config = require("clipring.config")
local ring = require("clipring.ring")
local paste = require("clipring.paste")
local persist = require("clipring.persist")

local M = {}

local state = {
  buf = nil,
  win = nil,
  opener_win = nil,
  opener_cursor = nil,
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

local NAV_MODES = { "n", "i", "v", "x", "s" }

--- Insert/Normal: full getcurpos() (accurate at end-of-line/file). Else win {row, col}.
local function capture_opener_cursor(win, mode)
  local ch = mode:sub(1, 1)
  if ch == "i" or ch == "n" then
    return vim.fn.getcurpos()
  end
  return vim.api.nvim_win_get_cursor(win)
end

local function close(restore_insert)
  local opener_mode = state.opener_mode
  local opener_win = state.opener_win

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  if opener_win and vim.api.nvim_win_is_valid(opener_win) then
    vim.api.nvim_set_current_win(opener_win)
  end
  state.buf = nil
  state.win = nil
  state.opener_win = nil
  state.opener_cursor = nil
  state.visual_marks = nil

  if restore_insert ~= false and opener_mode == "i" then
    vim.cmd("startinsert")
  end
end

local function focus_float_normal()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end
  vim.api.nvim_set_current_win(state.win)
  vim.cmd("stopinsert")
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
  local opener_cursor = state.opener_cursor
  close(false)
  if opener_win and vim.api.nvim_win_is_valid(opener_win) then
    vim.api.nvim_set_current_win(opener_win)
    -- Win cursor only; insert uses getcurpos restored inside paste_insert_mode.
    if opener_cursor and #opener_cursor < 4 then
      vim.api.nvim_win_set_cursor(opener_win, opener_cursor)
    end
  end
  paste.apply(entry, mode, marks, opener_win, opener_cursor)
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

local function move_selection(delta)
  local count = ring.count()
  if count == 0 then
    return
  end
  state.index = ((state.index - 1 + delta) % count) + 1
  refresh_buffer()
end

local function reorder_current(delta)
  if ring.count() == 0 then
    return
  end
  local new_index = ring.move(state.index, delta)
  if new_index then
    state.index = new_index
    persist.save()
    refresh_buffer()
  end
end

local function picker_mapping(key, fallback)
  local value = config.get()[key]
  if value == false or value == "" then
    return nil
  end
  if type(value) == "string" then
    return value
  end
  return fallback
end

local function attach_keymaps()
  -- noremap: override global maps (e.g. <C-j> -> :move) on this read-only buffer.
  local map_opts = {
    buffer = state.buf,
    silent = true,
    nowait = true,
    noremap = true,
  }

  local function map(lhs, rhs, desc)
    vim.keymap.set(NAV_MODES, lhs, rhs, vim.tbl_extend("force", map_opts, { desc = desc }))
  end

  map("j", function()
    move_selection(1)
  end, "ClipRing: next entry")
  map("J", function()
    move_selection(1)
  end, "ClipRing: next entry")
  map("k", function()
    move_selection(-1)
  end, "ClipRing: previous entry")
  map("K", function()
    move_selection(-1)
  end, "ClipRing: previous entry")
  map("<Down>", function()
    move_selection(1)
  end, "ClipRing: next entry")
  map("<Up>", function()
    move_selection(-1)
  end, "ClipRing: previous entry")

  local reorder_down = picker_mapping("reorder_down_mapping", "<C-j>")
  if reorder_down then
    map(reorder_down, function()
      reorder_current(1)
    end, "ClipRing: move entry down")
  end
  local reorder_up = picker_mapping("reorder_up_mapping", "<C-k>")
  if reorder_up then
    map(reorder_up, function()
      reorder_current(-1)
    end, "ClipRing: move entry up")
  end
  map("<CR>", function()
    select_current()
  end, "ClipRing: paste entry")
  map("dd", function()
    delete_current()
  end, "ClipRing: delete entry")
  map("q", function()
    close()
  end, "ClipRing: close")
  map("<Esc>", function()
    close()
  end, "ClipRing: close")

  -- Keep focus in the picker (Telescope-style); close with q/Esc before <C-w>.
  map("<C-w>", "<Nop>", "ClipRing: disable window switch")
  map("<C-W>", "<Nop>", "ClipRing: disable window switch")
end

---@param opts table|nil
---@field from_insert boolean|nil set when the open keymap runs in Insert mode
function M.open(opts)
  opts = opts or {}

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    refresh_buffer()
    focus_float_normal()
    return
  end

  state.opener_win = vim.api.nvim_get_current_win()
  if opts.from_insert then
    state.opener_mode = "i"
  else
    state.opener_mode = vim.api.nvim_get_mode().mode
  end
  state.opener_cursor = capture_opener_cursor(state.opener_win, state.opener_mode)
  state.visual_marks = nil
  if paste.opener_in_visual_mode(state.opener_mode) then
    state.visual_marks = paste.capture_visual_marks(state.opener_win, state.opener_mode)
  end
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
  focus_float_normal()

  if ring.count() > 0 then
    vim.api.nvim_win_set_cursor(state.win, { state.index, 0 })
  end
end

function M.close()
  close()
end

--- Test-only accessor for picker state.
function M._state()
  return {
    opener_mode = state.opener_mode,
    opener_cursor = state.opener_cursor,
    visual_marks = state.visual_marks,
    index = state.index,
  }
end

return M
