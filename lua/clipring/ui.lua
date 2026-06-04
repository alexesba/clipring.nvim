local config = require("clipring.config")
local ring = require("clipring.ring")
local paste = require("clipring.paste")
local persist = require("clipring.persist")

local M = {}

local state = {
  list_buf = nil,
  list_win = nil,
  preview_buf = nil,
  preview_win = nil,
  opener_win = nil,
  opener_cursor = nil,
  opener_mode = "n",
  visual_marks = nil,
  index = 1,
  list_col_width = 50,
}

local ns = vim.api.nvim_create_namespace("ClipRing")

local function entry_kind(entry)
  if entry.regtype == "V" then
    return "l"
  end
  if entry.regtype == "\022" or entry.regtype:find("^%d") or entry.regtype == "^V" then
    return "b"
  end
  return "c"
end

--- One-line label for the history list (truncated to fit the list pane).
local function list_label(entry, list_cols)
  local opts = config.get()
  local text = table.concat(entry.lines, " "):gsub("\t", " "):gsub("%s+", " ")
  local header = string.format("[%s] ", entry_kind(entry))
  local prefix_cols = 2 -- "▸ " or "  "
  local budget = (list_cols or state.list_col_width) - prefix_cols - vim.fn.strdisplaywidth(header)
  budget = math.min(budget, opts.preview_length)
  budget = math.max(budget, 8)
  if vim.fn.strdisplaywidth(text) > budget then
    text = vim.fn.strcharpart(text, 0, budget - 3) .. "..."
  end
  if text == "" then
    text = "(empty)"
  end
  return header .. text
end

local function set_buf_lines(buf, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

local function refresh_list_buffer()
  if not state.list_buf or not vim.api.nvim_buf_is_valid(state.list_buf) then
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
      table.insert(lines, prefix .. list_label(entry, state.list_col_width))
    end
  end

  set_buf_lines(state.list_buf, lines)

  if #all > 0 then
    vim.api.nvim_buf_clear_namespace(state.list_buf, ns, 0, -1)
    vim.api.nvim_buf_add_highlight(state.list_buf, ns, "CursorLine", state.index - 1, 0, -1)
  end
end

local function preview_lines_for_entry(entry)
  if not entry or not entry.lines or #entry.lines == 0 then
    return { "(empty)" }
  end

  local opts = config.get()
  local lines = vim.deepcopy(entry.lines)
  local max_lines = opts.preview_max_lines
  if max_lines > 0 and #lines > max_lines then
    local truncated = {}
    for i = 1, max_lines do
      truncated[i] = lines[i]
    end
    table.insert(truncated, string.format("… (%d more lines)", #lines - max_lines))
    lines = truncated
  end
  local padded = {}
  for i, line in ipairs(lines) do
    padded[i] = "  " .. line
  end
  return padded
end

local function refresh_preview_buffer()
  if not state.preview_buf or not vim.api.nvim_buf_is_valid(state.preview_buf) then
    return
  end

  local all = ring.get_all()
  if #all == 0 then
    set_buf_lines(state.preview_buf, { "" })
    return
  end

  local entry = all[state.index]
  set_buf_lines(state.preview_buf, preview_lines_for_entry(entry))
end

local function refresh_buffers()
  refresh_list_buffer()
  refresh_preview_buffer()
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

local function close_windows_and_bufs()
  if state.list_win and vim.api.nvim_win_is_valid(state.list_win) then
    vim.api.nvim_win_close(state.list_win, true)
  end
  if state.preview_win and vim.api.nvim_win_is_valid(state.preview_win) then
    vim.api.nvim_win_close(state.preview_win, true)
  end
  if state.list_buf and vim.api.nvim_buf_is_valid(state.list_buf) then
    vim.api.nvim_buf_delete(state.list_buf, { force = true })
  end
  if state.preview_buf and vim.api.nvim_buf_is_valid(state.preview_buf) then
    vim.api.nvim_buf_delete(state.preview_buf, { force = true })
  end
  state.list_buf = nil
  state.list_win = nil
  state.preview_buf = nil
  state.preview_win = nil
end

local function close(restore_insert)
  local opener_mode = state.opener_mode
  local opener_win = state.opener_win

  close_windows_and_bufs()

  if opener_win and vim.api.nvim_win_is_valid(opener_win) then
    vim.api.nvim_set_current_win(opener_win)
  end
  state.opener_win = nil
  state.opener_cursor = nil
  state.visual_marks = nil

  if restore_insert ~= false and opener_mode == "i" then
    vim.cmd("startinsert")
  end
end

local function focus_list_normal()
  if not state.list_win or not vim.api.nvim_win_is_valid(state.list_win) then
    return
  end
  vim.api.nvim_set_current_win(state.list_win)
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
    if opener_cursor and #opener_cursor < 4 then
      vim.api.nvim_win_set_cursor(opener_win, opener_cursor)
    end
  end
  paste.apply(entry, mode, marks, opener_win, opener_cursor)
end

local function copy_current()
  local all = ring.get_all()
  if #all == 0 then
    return
  end
  local entry = all[state.index]
  if entry then
    paste.copy_to_clipboard(entry)
  end
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

  refresh_buffers()
end

local function move_selection(delta)
  local count = ring.count()
  if count == 0 then
    return
  end
  state.index = ((state.index - 1 + delta) % count) + 1
  refresh_buffers()
end

local function reorder_current(delta)
  if ring.count() == 0 then
    return
  end
  local new_index = ring.move(state.index, delta)
  if new_index then
    state.index = new_index
    persist.save()
    refresh_buffers()
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
  local map_opts = {
    buffer = state.list_buf,
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
  local copy_key = picker_mapping("copy_mapping", "y")
  if copy_key then
    map(copy_key, function()
      copy_current()
    end, "ClipRing: copy entry to system clipboard")
  end
  map("dd", function()
    delete_current()
  end, "ClipRing: delete entry")
  map("q", function()
    close()
  end, "ClipRing: close")
  map("<Esc>", function()
    close()
  end, "ClipRing: close")

  local function block_window_prefix()
    return
  end
  map("<C-w>", block_window_prefix, "ClipRing: disable window switch")
  map("<C-W>", block_window_prefix, "ClipRing: disable window switch")
end

local function create_readonly_buf(name, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", filetype)
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  return buf
end

local function picker_layout()
  local opts = config.get()
  local count = ring.count()
  local list_lines = count > 0 and count or 3
  local entry = count > 0 and ring.get(state.index) or nil
  local preview_lines = entry and #preview_lines_for_entry(entry) or 1

  local height = math.max(list_lines, preview_lines, 3)
  height = math.min(height, opts.picker_max_height, vim.o.lines - 4)

  local margin = 8
  local total_width = opts.picker_width > 0 and opts.picker_width or (vim.o.columns - margin)
  total_width = math.min(total_width, vim.o.columns - margin)
  total_width = math.max(total_width, 60)

  local preview_cap = math.max(20, opts.preview_max_width or 80)
  preview_cap = math.min(preview_cap, total_width - 36)

  local preview_width = preview_cap
  local list_width
  if opts.list_width > 0 then
    list_width = math.min(opts.list_width, total_width - preview_width)
  else
    list_width = total_width - preview_width
  end
  list_width = math.max(list_width, 36)

  local float_gap = 1
  local footprint = (list_width + 2) + float_gap + (preview_width + 2)
  local row = math.max(0, math.floor((vim.o.lines - height) / 2))
  local col = math.max(0, math.floor((vim.o.columns - footprint) / 2))

  return {
    row = row,
    col = col,
    height = height,
    list_width = list_width,
    preview_width = preview_width,
    preview_col = col + list_width + 2 + float_gap,
    float_gap = float_gap,
  }
end

local function apply_picker_layout(layout)
  if not state.list_win or not vim.api.nvim_win_is_valid(state.list_win) then
    return
  end
  state.list_col_width = layout.list_width
  vim.api.nvim_win_set_config(state.list_win, {
    relative = "editor",
    width = layout.list_width,
    height = layout.height,
    row = layout.row,
    col = layout.col,
  })
  if state.preview_win and vim.api.nvim_win_is_valid(state.preview_win) then
    vim.api.nvim_win_set_config(state.preview_win, {
      relative = "editor",
      width = layout.preview_width,
      height = layout.height,
      row = layout.row,
      col = layout.preview_col,
    })
  end
end

local float_opts = {
  relative = "editor",
  style = "minimal",
  border = "rounded",
}

local function configure_float_win(win)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual"
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
end

---@param opts table|nil
---@field from_insert boolean|nil set when the open keymap runs in Insert mode
function M.open(opts)
  opts = opts or {}

  if state.list_win and vim.api.nvim_win_is_valid(state.list_win) then
    apply_picker_layout(picker_layout())
    refresh_buffers()
    focus_list_normal()
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

  state.list_buf = create_readonly_buf("clipring://history", "clipring")
  state.preview_buf = create_readonly_buf("clipring://preview", "clipring_preview")

  local layout = picker_layout()
  state.list_col_width = layout.list_width

  state.list_win = vim.api.nvim_open_win(state.list_buf, true, vim.tbl_extend("force", float_opts, {
    width = layout.list_width,
    height = layout.height,
    row = layout.row,
    col = layout.col,
    title = " ClipRing ",
    title_pos = "center",
  }))

  state.preview_win = vim.api.nvim_open_win(state.preview_buf, false, vim.tbl_extend("force", float_opts, {
    width = layout.preview_width,
    height = layout.height,
    row = layout.row,
    col = layout.preview_col,
  }))

  configure_float_win(state.list_win)
  configure_float_win(state.preview_win)

  attach_keymaps()
  refresh_buffers()
  focus_list_normal()

  if ring.count() > 0 then
    vim.api.nvim_win_set_cursor(state.list_win, { state.index, 0 })
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
    list_buf = state.list_buf,
    preview_buf = state.preview_buf,
  }
end

return M
