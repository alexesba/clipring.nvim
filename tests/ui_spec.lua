local h = require("tests.helpers")
local ring = require("clipring.ring")
local ui = require("clipring.ui")

describe("clipring.ui", function()
  local buf, win

  before_each(function()
    h.reset()
    ring.add({ "older" }, "v")
    ring.add({ "newer" }, "v")
    buf, win = h.open_buf({ "hello world" })
  end)

  after_each(function()
    ui.close()
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  it("opens picker in normal mode when launched from insert", function()
    vim.api.nvim_win_set_cursor(win, { 1, 5 })
    ui.open({ from_insert = true })
    assert.are.equal("n", vim.fn.mode())
  end)

  local function feed_clipring(keys)
    local clip_buf = h.find_clipring_buf()
    vim.api.nvim_set_current_win(vim.fn.bufwinid(clip_buf))
    vim.cmd("stopinsert")
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", true)
    return clip_buf
  end

  it("maps j to move down in the picker while insert mappings exist", function()
    ui.open({ from_insert = true })
    local clip_buf = h.find_clipring_buf()
    assert.are.equal(1, h.clipring_selected_line(clip_buf))

    feed_clipring("j")

    assert.are.equal(2, h.clipring_selected_line(clip_buf))
  end)

  it("maps Ctrl-j and Ctrl-k to reorder yanks in the ring", function()
    ui.open()
    assert.are.equal("newer", ring.get(1).lines[1])
    feed_clipring("<C-j>")
    assert.are.equal("older", ring.get(1).lines[1])
    assert.are.equal("newer", ring.get(2).lines[1])
    assert.are.equal(2, ui._state().index)
    feed_clipring("<C-k>")
    assert.are.equal("newer", ring.get(1).lines[1])
    assert.are.equal(1, ui._state().index)
  end)

  it("records insert opener when opened with from_insert", function()
    vim.api.nvim_win_set_cursor(win, { 1, 5 })
    ui.open({ from_insert = true })
    local s = ui._state()
    assert.are.equal("i", s.opener_mode)
    assert.is_true(#s.opener_cursor >= 4)
    assert.are.equal(1, s.opener_cursor[2])
    ui.close()
  end)

  it("pastes selected ring entry when confirming from insert opener", function()
    local paste = require("clipring.paste")
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, { "hola mundo " })
    vim.api.nvim_set_current_win(win)
    vim.fn.setpos(".", { 0, 1, 12, 0 })
    ui.open({ from_insert = true })
    local s = ui._state()
    ui.close(false)
    vim.api.nvim_set_current_win(win)
    paste.apply({ lines = { "foo" }, regtype = "v" }, "i", nil, win, s.opener_cursor)
    vim.cmd("stopinsert")
    assert.are.equal("hola mundo foo", h.buf_text(buf))
  end)
end)
