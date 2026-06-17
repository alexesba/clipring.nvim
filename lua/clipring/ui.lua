local config = require("clipring.config")
local ring = require("clipring.ring")
local paste = require("clipring.paste")
local persist = require("clipring.persist")
local preview_syntax = require("clipring.preview_syntax")
local preview_highlight = require("clipring.preview_highlight")
local which_key = require("clipring.which_key")

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
  list_col = 0,
  list_row = 0,
  list_height = 3,
  float_gap = 1,
  clear_all_confirm = false,
  preview_highlight_ft = nil,
  preview_hl_autocmd = false,
}

local ns = vim.api.nvim_create_namespace("ClipRing")

local PREVIEW_MIN_WIDTH = 20
local PREVIEW_MIN_HEIGHT = 3
local LIST_MIN_HEIGHT = 3

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

---@param bufhidden? string
local function create_readonly_buf(name, filetype, bufhidden)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  vim.api.nvim_buf_set_option(buf, "bufhidden", bufhidden or "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", filetype)
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  return buf
end

local function ensure_preview_buf()
  if state.preview_buf and vim.api.nvim_buf_is_valid(state.preview_buf) then
    return state.preview_buf
  end
  state.preview_buf = create_readonly_buf("clipring://preview", "clipring_preview", "hide")
  return state.preview_buf
end

local function refresh_list_buffer()
  if not state.list_buf or not vim.api.nvim_buf_is_valid(state.list_buf) then
    return
  end

  local lines = {}
  local all = ring.get_all()

  if state.clear_all_confirm and #all > 0 then
    local n = #all
    local word = n == 1 and "entry" or "entries"
    lines = {
      string.format("Clear all %d %s?", n, word),
      "  y = yes   n = cancel",
    }
    set_buf_lines(state.list_buf, lines)
    return
  end

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
    if state.list_win and vim.api.nvim_win_is_valid(state.list_win) then
      pcall(vim.api.nvim_win_set_cursor, state.list_win, { state.index, 0 })
    end
  end
end

---@param entry ClipRingEntry|nil
---@return string[] lines, string filetype
local function preview_content_for_entry(entry)
  if not entry or not entry.lines or #entry.lines == 0 then
    return { "(empty)" }, "clipring_preview"
  end

  local opts = config.get()
  local content_lines, filetype = preview_syntax.analyze(entry.lines, vim.tbl_extend("force", opts, {
    source_filetype = entry.filetype,
  }))
  local max_lines = opts.preview_max_lines
  if max_lines > 0 and #content_lines > max_lines then
    local truncated = {}
    for i = 1, max_lines do
      truncated[i] = content_lines[i]
    end
    table.insert(truncated, string.format("… (%d more lines)", #content_lines - max_lines))
    content_lines = truncated
  end
  return content_lines, filetype
end

local function preview_lines_for_entry(entry)
  local content_lines = select(1, preview_content_for_entry(entry))
  local padded = {}
  for i, line in ipairs(content_lines) do
    padded[i] = "  " .. line
  end
  return padded
end

local function ensure_preview_hl_autocmd()
  if state.preview_hl_autocmd or not state.preview_buf then
    return
  end
  state.preview_hl_autocmd = true
  vim.api.nvim_create_autocmd("BufWinEnter", {
    buffer = state.preview_buf,
    callback = function()
      if state.preview_highlight_ft and state.preview_highlight_ft ~= "clipring_preview" then
        preview_highlight.attach(state.preview_buf, state.preview_highlight_ft)
      end
    end,
  })
end

local function apply_preview_filetype(filetype)
  if not state.preview_buf or not vim.api.nvim_buf_is_valid(state.preview_buf) then
    return
  end
  state.preview_highlight_ft = filetype
  ensure_preview_hl_autocmd()
  preview_highlight.attach(state.preview_buf, filetype)
end

local function entry_has_preview_content(entry)
  if not entry or not entry.lines or #entry.lines == 0 then
    return false
  end
  return not table.concat(entry.lines, "\n"):match("^%s*$")
end

local function preview_should_show()
  if state.clear_all_confirm then
    return false
  end
  return ring.count() > 0 and entry_has_preview_content(ring.get(state.index))
end

local function refresh_preview_buffer()
  ensure_preview_buf()

  local all = ring.get_all()
  if #all == 0 then
    set_buf_lines(state.preview_buf, { "" })
    return
  end

  local entry = all[state.index]
  local content_lines, filetype = preview_content_for_entry(entry)
  local padded = {}
  for i, line in ipairs(content_lines) do
    padded[i] = "  " .. line
  end
  set_buf_lines(state.preview_buf, padded)
  apply_preview_filetype(filetype)
end

local function max_preview_line_width(lines)
  local max_w = 0
  for _, line in ipairs(lines) do
    max_w = math.max(max_w, vim.fn.strdisplaywidth(line))
  end
  return max_w
end

---@param entry ClipRingEntry|nil
---@return number width, number height
local function preview_size_for_entry(entry)
  local opts = config.get()
  local lines = entry and preview_lines_for_entry(entry) or { "" }
  local line_count = #lines
  local max_line_w = max_preview_line_width(lines)

  local width = math.max(PREVIEW_MIN_WIDTH, max_line_w + 1)
  if opts.preview_max_width and opts.preview_max_width > 0 then
    width = math.min(width, opts.preview_max_width)
  end

  local height = math.max(PREVIEW_MIN_HEIGHT, line_count)
  height = math.min(height, opts.picker_max_height, vim.o.lines - 4)
  if state.list_row and state.list_row > 0 then
    height = math.min(height, vim.o.lines - state.list_row - 2)
  end

  return width, height
end

local function clamp_preview_width(width)
  if not state.list_col or not state.list_width then
    return width
  end
  local preview_col = state.list_col + state.list_width + 2 + state.float_gap
  local max_on_screen = vim.o.columns - preview_col - 4
  return math.max(PREVIEW_MIN_WIDTH, math.min(width, max_on_screen))
end

--- Stable preview width for initial list placement (list stays put; preview resizes).
local function preview_footprint_width()
  local opts = config.get()
  if opts.preview_max_width and opts.preview_max_width > 0 then
    return opts.preview_max_width
  end
  local total = opts.picker_width > 0 and opts.picker_width or (vim.o.columns - 8)
  return math.max(PREVIEW_MIN_WIDTH, math.min(math.floor(total * 0.45), total - 36))
end

--- Height of the history list from entry count.
local function list_height_for_count(count)
  local opts = config.get()
  local list_lines = count > 0 and count or 3
  local height = math.max(list_lines, LIST_MIN_HEIGHT)
  return math.min(height, opts.picker_max_height, vim.o.lines - 4)
end

---@param initial_preview_width number|nil
---@param with_preview boolean
local function list_layout(initial_preview_width, with_preview)
  local opts = config.get()
  local count = ring.count()
  local height = list_height_for_count(count)

  local margin = 8
  local total_width = opts.picker_width > 0 and opts.picker_width or (vim.o.columns - margin)
  total_width = math.min(total_width, vim.o.columns - margin)
  total_width = math.max(total_width, 60)

  local list_width
  local footprint

  if not with_preview then
    list_width = total_width
    list_width = math.max(list_width, 36)
    footprint = list_width + 2
  else
    local preview_cap = opts.preview_max_width and opts.preview_max_width > 0 and opts.preview_max_width
      or (initial_preview_width or PREVIEW_MIN_WIDTH)
    preview_cap = math.max(PREVIEW_MIN_WIDTH, preview_cap)
    preview_cap = math.min(preview_cap, total_width - 36)

    if opts.list_width > 0 then
      list_width = math.min(opts.list_width, total_width - preview_cap)
    else
      list_width = total_width - preview_cap
    end
    list_width = math.max(list_width, 36)

    local preview_w = initial_preview_width or preview_cap
    footprint = (list_width + 2) + state.float_gap + (preview_w + 2)
  end

  local row = math.max(0, math.floor((vim.o.lines - height) / 2))
  local col = math.max(0, math.floor((vim.o.columns - footprint) / 2))

  return {
    row = row,
    col = col,
    height = height,
    list_width = list_width,
  }
end

local function apply_list_height()
  if not state.list_win or not vim.api.nvim_win_is_valid(state.list_win) then
    return
  end
  local height = list_height_for_count(ring.count())
  if height == state.list_height then
    return
  end
  state.list_height = height
  vim.api.nvim_win_set_config(state.list_win, {
    relative = "editor",
    width = state.list_width,
    height = height,
    row = state.list_row,
    col = state.list_col,
  })
end

local function apply_preview_layout()
  if not state.preview_win or not vim.api.nvim_win_is_valid(state.preview_win) then
    return
  end

  local entry = ring.get(state.index)
  local width, height
  if entry then
    width, height = preview_size_for_entry(entry)
  else
    width, height = PREVIEW_MIN_WIDTH, PREVIEW_MIN_HEIGHT
  end
  width = clamp_preview_width(width)

  vim.api.nvim_win_set_config(state.preview_win, {
    relative = "editor",
    width = width,
    height = height,
    row = state.list_row,
    col = state.list_col + state.list_width + 2 + state.float_gap,
  })
end

local function set_list_layout_state(layout)
  state.list_col_width = layout.list_width
  state.list_width = layout.list_width
  state.list_col = layout.col
  state.list_row = layout.row
  state.list_height = layout.height
end

local function apply_list_layout(layout)
  set_list_layout_state(layout)
  if not state.list_win or not vim.api.nvim_win_is_valid(state.list_win) then
    return
  end
  vim.api.nvim_win_set_config(state.list_win, {
    relative = "editor",
    width = layout.list_width,
    height = layout.height,
    row = layout.row,
    col = layout.col,
  })
end

local function hide_preview_window()
  if state.preview_win and vim.api.nvim_win_is_valid(state.preview_win) then
    -- Do not force-close: preview buf uses bufhidden=hide and must survive for reuse.
    vim.api.nvim_win_close(state.preview_win, false)
  end
  state.preview_win = nil
end

local function show_preview_window()
  ensure_preview_buf()

  if state.preview_win and not vim.api.nvim_win_is_valid(state.preview_win) then
    state.preview_win = nil
  end

  if not state.preview_win then
    local entry = ring.get(state.index)
    local pw, ph = preview_size_for_entry(entry)
    pw = clamp_preview_width(pw)
    state.preview_win = vim.api.nvim_open_win(state.preview_buf, false, vim.tbl_extend("force", float_opts, {
      width = pw,
      height = ph,
      row = state.list_row,
      col = state.list_col + state.list_width + 2 + state.float_gap,
    }))
    configure_float_win(state.preview_win)
  else
    apply_preview_layout()
  end

  refresh_preview_buffer()
end

local function sync_preview_visibility()
  local show = preview_should_show()
  if show then
    show_preview_window()
  else
    hide_preview_window()
  end
end

local function refresh_buffers()
  refresh_list_buffer()
  apply_list_height()
  sync_preview_visibility()
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
  state.clear_all_confirm = false
  state.preview_highlight_ft = nil
  state.preview_hl_autocmd = nil
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
  if state.clear_all_confirm then
    return
  end

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

local function cancel_clear_all_confirm()
  if not state.clear_all_confirm then
    return
  end
  state.clear_all_confirm = false
  refresh_buffers()
end

local function request_clear_all_confirm()
  if ring.count() == 0 or state.clear_all_confirm then
    return
  end
  state.clear_all_confirm = true
  refresh_buffers()
end

local function confirm_clear_all()
  if not state.clear_all_confirm then
    return
  end
  ring.clear()
  persist.save()
  state.clear_all_confirm = false
  state.index = 1
  refresh_buffers()
end

local function delete_current()
  if state.clear_all_confirm then
    cancel_clear_all_confirm()
    return
  end

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
  if state.clear_all_confirm then
    cancel_clear_all_confirm()
    return
  end

  local count = ring.count()
  if count == 0 then
    return
  end
  state.index = ((state.index - 1 + delta) % count) + 1
  refresh_buffers()
end

local function reorder_current(delta)
  if state.clear_all_confirm then
    cancel_clear_all_confirm()
    return
  end

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
      if state.clear_all_confirm then
        confirm_clear_all()
      else
        copy_current()
      end
    end, "ClipRing: copy entry or confirm clear all")
  end
  map("dd", function()
    delete_current()
  end, "ClipRing: delete entry")
  local clear_all = picker_mapping("clear_all_mapping", "C")
  if clear_all then
    map(clear_all, function()
      request_clear_all_confirm()
    end, "ClipRing: clear all entries")
  end
  map("n", function()
    if state.clear_all_confirm then
      cancel_clear_all_confirm()
    end
  end, "ClipRing: cancel clear all")
  map("q", function()
    if state.clear_all_confirm then
      cancel_clear_all_confirm()
      return
    end
    close()
  end, "ClipRing: close")
  map("<Esc>", function()
    if state.clear_all_confirm then
      cancel_clear_all_confirm()
      return
    end
    close()
  end, "ClipRing: close")

  local function block_window_prefix()
    return
  end

  if which_key.available() then
    local function show_picker_help()
      which_key.show_help()
    end

    local help = picker_mapping("help_mapping", "g?")
    if help then
      map(help, show_picker_help, "ClipRing: show keymaps")
    end
    map("<C-w>", show_picker_help, "ClipRing: show keymaps")
    map("<C-W>", show_picker_help, "ClipRing: show keymaps")
  else
    map("<C-w>", block_window_prefix, "ClipRing: disable window switch")
    map("<C-W>", block_window_prefix, "ClipRing: disable window switch")
  end
end

---@param opts table|nil
---@field from_insert boolean|nil set when the open keymap runs in Insert mode
function M.open(opts)
  opts = opts or {}

  if state.list_win and vim.api.nvim_win_is_valid(state.list_win) then
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
  state.preview_buf = create_readonly_buf("clipring://preview", "clipring_preview", "hide")

  local has_entries = ring.count() > 0
  local layout = list_layout(preview_footprint_width(), has_entries)
  set_list_layout_state(layout)

  state.list_win = vim.api.nvim_open_win(state.list_buf, true, vim.tbl_extend("force", float_opts, {
    width = layout.list_width,
    height = layout.height,
    row = layout.row,
    col = layout.col,
    title = " ClipRing ",
    title_pos = "center",
  }))

  configure_float_win(state.list_win)

  if preview_should_show() then
    local entry = ring.get(state.index)
    local pw, ph = preview_size_for_entry(entry)
    pw = clamp_preview_width(pw)
    state.preview_win = vim.api.nvim_open_win(state.preview_buf, false, vim.tbl_extend("force", float_opts, {
      width = pw,
      height = ph,
      row = state.list_row,
      col = state.list_col + state.list_width + 2 + state.float_gap,
    }))
    configure_float_win(state.preview_win)
  end

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
