local M = {}

local function linewise(regtype)
  return regtype == "V"
end

local function is_getcurpos(cursor)
  return type(cursor) == "table" and cursor[2] ~= nil and cursor[3] ~= nil and cursor[4] ~= nil
end

--- 0-indexed byte column for nvim_buf_set_text from getcurpos() in Insert mode.
local function byte_col_from_curpos(curpos)
  local lnum, col = curpos[2], curpos[3]
  local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] or ""
  local byte = vim.str_byteindex(line, col - 1, true)
  if byte < 0 then
    return #line
  end
  return byte
end

--- Insert at cursor in Insert mode.
---@param lines string[]
---@param regtype string
---@param cursor number[]|nil getcurpos() or {row, col} win cursor (0-indexed col)
local function paste_insert_mode(lines, regtype, cursor)
  local buf = vim.api.nvim_get_current_buf()
  local row, col

  if cursor and is_getcurpos(cursor) then
    row = cursor[2] - 1
    col = byte_col_from_curpos(cursor)
  else
    if cursor then
      vim.api.nvim_win_set_cursor(0, cursor)
    end
    vim.cmd("startinsert")
    row, col = unpack(vim.api.nvim_win_get_cursor(0))
    row = row - 1
  end

  if linewise(regtype) then
    vim.api.nvim_buf_set_text(buf, row, 0, row, 0, lines)
    vim.api.nvim_win_set_cursor(0, { row + #lines, 0 })
  else
    vim.api.nvim_buf_set_text(buf, row, col, row, col, lines)
    vim.api.nvim_win_set_cursor(0, { row + 1, col + #(lines[#lines] or "") })
  end

  vim.cmd("startinsert")
end

local function mark_buf(pos, buf)
  if pos[1] == 0 then
    return buf
  end
  return pos[1]
end

local function is_visual_mode(mode)
  return mode == "v" or mode == "V" or mode == "\022"
end

local function region_regtype(visual_mode)
  if visual_mode == "V" then
    return "V"
  end
  if visual_mode == "\022" then
    return "\022"
  end
  return "v"
end

---@param marks table
---@return number, number, number, number
local function bounds_from_marks(marks)
  local s_row = marks.start[2] - 1
  local s_col = marks.start[3] - 1
  local e_row = marks["end"][2] - 1
  local e_col = marks["end"][3]

  if marks.visual_mode == "V" then
    s_col = 0
    e_row = marks["end"][2]
    e_col = 0
  end

  return s_row, s_col, e_row, e_col
end

--- Snapshot region while visual marks / active selection are still valid.
---@param win number
---@param marks table
---@param mode string
local function freeze_region(win, marks, mode)
  if vim.fn.exists("*getregionpos") ~= 1 then
    marks.s_row, marks.s_col, marks.e_row, marks.e_col = bounds_from_marks(marks)
    return
  end

  local regtype = region_regtype(marks.visual_mode)
  local ok, pos

  if is_visual_mode(mode) then
    ok, pos = pcall(vim.fn.getregionpos, win, { regtype = regtype })
  else
    vim.fn.setpos("'<", marks.start)
    vim.fn.setpos("'>", marks["end"])
    ok, pos = pcall(vim.fn.getregionpos, win, { regtype = regtype })
  end

  if ok and type(pos) == "table" and #pos >= 2 then
    local p1, p2 = pos[1], pos[2]
    if type(p1) == "table" and type(p2) == "table" and p1[2] > 0 and p2[2] > 0 then
      marks.s_row = p1[2] - 1
      marks.s_col = p1[3] - 1
      marks.e_row = p2[2] - 1
      marks.e_col = p2[3] - 1
      return
    end
  end

  marks.s_row, marks.s_col, marks.e_row, marks.e_col = bounds_from_marks(marks)
end

---@param win number
---@param mode string
---@return table|nil
function M.capture_visual_marks(win, mode)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return nil
  end

  local marks = nil

  vim.api.nvim_win_call(win, function()
    local buf = vim.api.nvim_win_get_buf(win)
    local start, end_

    -- '< and '> update only after visual ends; while still in visual use v + cursor.
    if is_visual_mode(mode) then
      start = vim.fn.getpos("v")
      end_ = vim.fn.getpos(".")
    else
      start = vim.fn.getpos("'<")
      end_ = vim.fn.getpos("'>")
    end

    if mark_buf(start, buf) ~= buf or mark_buf(end_, buf) ~= buf then
      return
    end

    start[1] = buf
    end_[1] = buf
    if start[2] == 0 or end_[2] == 0 then
      return
    end

    if start[2] > end_[2] or (start[2] == end_[2] and start[3] > end_[3]) then
      start, end_ = end_, start
    end

    local visual_mode = mode
    if not is_visual_mode(visual_mode) then
      visual_mode = "v"
      if start[3] == 1 and end_[3] >= vim.fn.col({ end_[2], "$" }) then
        visual_mode = "V"
      end
    end

    marks = {
      buf = buf,
      opener_win = win,
      start = start,
      ["end"] = end_,
      visual_mode = visual_mode,
    }

    freeze_region(win, marks, mode)
  end)

  return marks
end

---@param marks table
---@param lines string[]
---@param regtype string
local function replace_visual_range(marks, lines, regtype)
  local buf = marks.buf
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  if marks.s_row == nil then
    return false
  end

  vim.api.nvim_buf_set_text(buf, marks.s_row, marks.s_col, marks.e_row, marks.e_col, lines)

  if vim.api.nvim_get_current_buf() == buf then
    local row = marks.s_row + #lines
    local col = 0
    if #lines > 0 and not linewise(regtype) then
      row = marks.s_row + #lines - 1
      col = #lines[#lines]
    end
    vim.api.nvim_win_set_cursor(0, { row + 1, col })
  end

  return true
end

---@param entry ClipRingEntry
---@param opener_mode string
---@param visual_marks table|nil
---@param opener_win number|nil
---@param opener_cursor number[]|nil
function M.apply(entry, opener_mode, visual_marks, opener_win, opener_cursor)
  local lines = entry.lines
  local regtype = entry.regtype

  if visual_marks and opener_win and not visual_marks.opener_win then
    visual_marks.opener_win = opener_win
  end

  local function do_paste()
    if opener_mode == "i" then
      paste_insert_mode(lines, regtype, opener_cursor)
      return
    end

    if visual_marks then
      if replace_visual_range(visual_marks, lines, regtype) then
        return
      end
      vim.notify("ClipRing: could not replace the selection", vim.log.levels.WARN)
    end

    vim.fn.setreg('"', lines, regtype)
    if linewise(regtype) then
      vim.cmd([[normal! ""P]])
    else
      vim.cmd([[normal! ""p]])
    end
  end

  local win = opener_win or (visual_marks and visual_marks.opener_win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_call(win, do_paste)
  else
    do_paste()
  end
end

return M
