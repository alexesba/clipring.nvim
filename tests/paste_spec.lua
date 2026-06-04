local h = require("tests.helpers")
local paste = require("clipring.paste")

describe("clipring.paste", function()
  local buf, win

  before_each(function()
    h.reset()
    buf, win = h.open_buf({ "hello world" })
  end)

  after_each(function()
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  it("captures marks while still in charwise visual mode", function()
    local mode = h.charwise_visual(win, h.pos(buf, 1, 7), h.pos(buf, 1, 11))
    assert.are.equal("v", mode)

    local marks = paste.capture_visual_marks(win, "v")
    assert.is_not_nil(marks)
    assert.are.equal(buf, marks.buf)
    assert.is_not_nil(marks.s_row)
    assert.is_not_nil(marks.e_col)
  end)

  it("captures marks from '< and '> after leaving visual mode", function()
    h.charwise_visual(win, h.pos(buf, 1, 7), h.pos(buf, 1, 11))
    vim.cmd("normal! \27")

    local marks = paste.capture_visual_marks(win, "n")
    assert.is_not_nil(marks)
    assert.are.equal(7, marks.start[3])
    assert.are.equal(11, marks["end"][3])
  end)

  it("replaces charwise visual selection instead of appending", function()
    h.charwise_visual(win, h.pos(buf, 1, 7), h.pos(buf, 1, 11))
    local marks = paste.capture_visual_marks(win, "v")
    assert.is_not_nil(marks)

    paste.apply(h.entry({ "universe" }, "v"), "n", marks, win)

    assert.are.equal("hello universe", h.buf_text(buf))
    assert.are_not.equal("hello worlduniverse", h.buf_text(buf))
    assert.are_not.equal("hello world universe", h.buf_text(buf))
  end)

  it("replaces selection after visual mode ended (normal opener)", function()
    h.charwise_visual(win, h.pos(buf, 1, 7), h.pos(buf, 1, 11))
    vim.cmd("normal! \27")

    local marks = paste.capture_visual_marks(win, "n")
    paste.apply(h.entry({ "universe" }, "v"), "n", marks, win)

    assert.are.equal("hello universe", h.buf_text(buf))
  end)

  it("pastes at cursor when there is no visual selection", function()
    vim.api.nvim_win_set_cursor(win, { 1, 4 }) -- 0-indexed: after "hello"
    paste.apply(h.entry({ "X" }, "v"), "n", nil, win)
    assert.are.equal("helloX world", h.buf_text(buf))
  end)

  it("inserts in insert mode without visual marks", function()
    vim.api.nvim_win_set_cursor(win, { 1, 5 }) -- 0-indexed: before space, after "hello"
    vim.cmd("startinsert")
    paste.apply(h.entry({ "X" }, "v"), "i", nil, win)
    vim.cmd("stopinsert")
    assert.are.equal("helloX world", h.buf_text(buf))
  end)

  it("insert mode paste preserves space after picker closes in normal mode", function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, { "hello world" })
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_win_set_cursor(win, { 1, 5 })
    vim.cmd("startinsert")
    vim.cmd("stopinsert")
    local cursor = vim.api.nvim_win_get_cursor(win)
    paste.apply(h.entry({ "X" }, "v"), "i", nil, win, cursor)
    vim.cmd("stopinsert")
    assert.are.equal("helloX world", h.buf_text(buf))
    assert.are_not.equal("helloXworld", h.buf_text(buf))
  end)

end)
