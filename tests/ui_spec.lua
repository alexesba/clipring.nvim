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

  it("maps Ctrl-w without a which-key trigger on the picker buffer", function()
    ui.open()
    local clip_buf = h.find_clipring_buf()
    vim.api.nvim_set_current_win(vim.fn.bufwinid(clip_buf))
    local map = vim.fn.maparg("<C-w>", "n", false, true)
    assert.is_true(type(map) == "table")
    assert.is_true(map.callback ~= nil)
    if map.desc then
      assert.is_nil(map.desc:find("which%-key%-trigger", 1, true))
    end
  end)

  it("blocks Ctrl-w window switch while picker is focused", function()
    local buf2 = vim.api.nvim_create_buf(true, true)
    local win2 = vim.api.nvim_open_win(buf2, false, {
      relative = "editor",
      width = 20,
      height = 5,
      row = 0,
      col = 0,
      style = "minimal",
    })
    ui.open()
    local clip_win = vim.fn.bufwinid(h.find_clipring_buf())
    vim.api.nvim_set_current_win(clip_win)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-w>w", true, false, true), "x", true)
    assert.are.equal(clip_win, vim.api.nvim_get_current_win())
    if vim.api.nvim_win_is_valid(win2) then
      vim.api.nvim_win_close(win2, true)
    end
    if vim.api.nvim_buf_is_valid(buf2) then
      vim.api.nvim_buf_delete(buf2, { force = true })
    end
  end)

  it("maps K to move up without invoking man on the preview word", function()
    ui.open()
    local clip_buf = h.find_clipring_buf()
    feed_clipring("j")
    assert.are.equal(2, h.clipring_selected_line(clip_buf))
    feed_clipring("K")
    assert.are.equal(1, h.clipring_selected_line(clip_buf))
  end)

  it("hides the preview pane when the ring is empty", function()
    ring.clear()
    ui.open()
    assert.is_nil(h.clipring_preview_win())
    ui.close()
  end)

  it("hides the preview pane after deleting the last entry", function()
    ring.clear()
    ring.add({ "only one" }, "v")
    ui.open()
    assert.is_not_nil(h.clipring_preview_win())
    feed_clipring("dd")
    assert.is_nil(h.clipring_preview_win())
    ui.close()
  end)

  it("sets ruby filetype for fenced code blocks in the preview pane", function()
    ring.clear()
    ring.add({
      "```ruby",
      "def foo",
      "  1",
      "end",
      "```",
    }, "V")
    ui.open()
    local preview_buf = h.find_clipring_preview_buf()
    assert.are.equal("ruby", vim.api.nvim_buf_get_option(preview_buf, "filetype"))
    assert.same({ "  def foo", "    1", "  end" }, vim.api.nvim_buf_get_lines(preview_buf, 0, -1, false))
    ui.close()
  end)

  it("shows multiline yank content in the preview pane", function()
    ring.clear()
    ring.add({ "alpha", "beta", "gamma" }, "V")
    ui.open()
    local preview_buf = h.find_clipring_preview_buf()
    assert.is_not_nil(preview_buf)
    assert.same({ "  alpha", "  beta", "  gamma" }, vim.api.nvim_buf_get_lines(preview_buf, 0, -1, false))
    ui.close()
  end)

  it("updates preview when selection moves", function()
    ring.clear()
    ring.add({ "one", "two" }, "v")
    ring.add({ "solo" }, "v")
    ui.open()
    local preview_buf = h.find_clipring_preview_buf()
    assert.same({ "  solo" }, vim.api.nvim_buf_get_lines(preview_buf, 0, -1, false))
    feed_clipring("j")
    assert.same({ "  one", "  two" }, vim.api.nvim_buf_get_lines(preview_buf, 0, -1, false))
    ui.close()
  end)

  it("keeps the list window fixed while navigating and resizing preview", function()
    ring.clear()
    ring.add({ "short" }, "v")
    ring.add({ "alpha", "beta", "gamma", "delta", "epsilon" }, "V")
    ui.open()
    local list_win = vim.fn.bufwinid(h.find_clipring_buf())
    local col_before = vim.api.nvim_win_get_config(list_win).col
    local row_before = vim.api.nvim_win_get_config(list_win).row
    assert.is_not_nil(h.clipring_preview_win())
    feed_clipring("j")
    assert.are.equal(col_before, vim.api.nvim_win_get_config(list_win).col)
    assert.are.equal(row_before, vim.api.nvim_win_get_config(list_win).row)
    assert.is_not_nil(h.clipring_preview_win())
    ui.close()
  end)

  it("shows preview again when moving from a whitespace-only entry to real content", function()
    ring.clear()
    ring.add({ "visible", "lines" }, "V")
    ring.add({ "   " }, "v")
    ui.open()
    assert.is_nil(h.clipring_preview_win())
    feed_clipring("j")
    assert.is_not_nil(h.clipring_preview_win())
    local preview_buf = h.find_clipring_preview_buf()
    assert.same({ "  visible", "  lines" }, vim.api.nvim_buf_get_lines(preview_buf, 0, -1, false))
    ui.close()
  end)

  it("keeps preview when wrapping from last entry to first and back", function()
    ring.clear()
    for i = 1, 5 do
      ring.add({ "entry-" .. i }, "v")
    end
    ui.open()
    for _ = 1, 4 do
      feed_clipring("j")
    end
    assert.are.equal(5, h.clipring_selected_line(h.find_clipring_buf()))
    assert.is_not_nil(h.clipring_preview_win())
    feed_clipring("j")
    assert.are.equal(1, h.clipring_selected_line(h.find_clipring_buf()))
    assert.is_not_nil(h.clipring_preview_win())
    feed_clipring("k")
    assert.are.equal(5, h.clipring_selected_line(h.find_clipring_buf()))
    assert.is_not_nil(h.clipring_preview_win())
    ui.close()
  end)

  it("restores preview after toggling through whitespace-only entries", function()
    ring.clear()
    ring.add({ "keep", "preview" }, "V")
    ring.add({ "   " }, "v")
    ring.add({ "first" }, "v")
    ui.open()
    assert.is_not_nil(h.clipring_preview_win())
    feed_clipring("j") -- whitespace
    assert.is_nil(h.clipring_preview_win())
    feed_clipring("j") -- back to keep preview
    assert.is_not_nil(h.clipring_preview_win())
    feed_clipring("k") -- whitespace again
    assert.is_nil(h.clipring_preview_win())
    feed_clipring("k") -- first
    assert.is_not_nil(h.clipring_preview_win())
    ui.close()
  end)

  it("truncates long previews with a more-lines indicator", function()
    require("clipring.config").setup({
      max_entries = 20,
      deduplicate = true,
      min_length = 1,
      persist = false,
      preview_max_lines = 2,
    })
    ring.clear()
    ring.add({ "a", "b", "c", "d" }, "V")
    ui.open()
    local preview_buf = h.find_clipring_preview_buf()
    local lines = vim.api.nvim_buf_get_lines(preview_buf, 0, -1, false)
    assert.are.equal("  a", lines[1])
    assert.are.equal("  b", lines[2])
    assert.matches("2 more lines", lines[3])
    ui.close()
  end)

  it("resizes list height when entries are deleted", function()
    ring.clear()
    for i = 1, 8 do
      ring.add({ "entry-" .. i }, "v")
    end
    ui.open()
    local list_win = vim.fn.bufwinid(h.find_clipring_buf())
    local tall = vim.api.nvim_win_get_height(list_win)
    feed_clipring("dd")
    local shorter = vim.api.nvim_win_get_height(list_win)
    assert.is_true(shorter < tall)
    ui.close()
  end)

  it("resizes preview height when selection changes", function()
    ring.clear()
    ring.add({ "short" }, "v")
    ring.add({ "a", "b", "c", "d", "e" }, "V")
    ui.open()
    local preview_win = vim.fn.bufwinid(h.find_clipring_preview_buf())
    local tall_height = vim.api.nvim_win_get_height(preview_win)
    feed_clipring("j")
    local short_height = vim.api.nvim_win_get_height(preview_win)
    assert.is_true(tall_height > short_height)
    ui.close()
  end)

  it("maps j to move down in the picker while insert mappings exist", function()
    ui.open({ from_insert = true })
    local clip_buf = h.find_clipring_buf()
    assert.are.equal(1, h.clipring_selected_line(clip_buf))

    feed_clipring("j")

    assert.are.equal(2, h.clipring_selected_line(clip_buf))
  end)

  it("maps custom reorder keys from config", function()
    require("clipring.config").setup({
      max_entries = 20,
      deduplicate = true,
      min_length = 1,
      persist = false,
      reorder_down_mapping = "<C-n>",
      reorder_up_mapping = "<C-p>",
    })
    ui.open()
    feed_clipring("<C-n>")
    assert.are.equal("older", ring.get(1).lines[1])
    feed_clipring("<C-p>")
    assert.are.equal("newer", ring.get(1).lines[1])
    ui.close()
  end)

  it("maps y to copy the selected entry to clipboard registers without closing", function()
    ui.open()
    local clip_buf = feed_clipring("j")
    assert.are.equal(2, h.clipring_selected_line(clip_buf))
    feed_clipring("y")
    assert.are.equal("older", vim.fn.getreg('"'))
    assert.is_true(vim.fn.bufwinid(clip_buf) > 0)
    ui.close()
  end)

  it("prompts to clear all entries and clears on confirm", function()
    ui.open()
    feed_clipring("C")
    local clip_buf = h.find_clipring_buf()
    local lines = vim.api.nvim_buf_get_lines(clip_buf, 0, -1, false)
    assert.matches("Clear all 2 entries", lines[1])
    feed_clipring("y")
    assert.are.equal(0, ring.count())
    assert.matches("No yanks yet", vim.api.nvim_buf_get_lines(clip_buf, 0, -1, false)[1])
    ui.close()
  end)

  it("cancels clear all on n or Esc", function()
    ui.open()
    feed_clipring("C")
    feed_clipring("n")
    assert.are.equal(2, ring.count())
    feed_clipring("C")
    feed_clipring("\27")
    assert.are.equal(2, ring.count())
    ui.close()
  end)

  it("can disable clear all mapping from config", function()
    require("clipring.config").setup({
      max_entries = 20,
      deduplicate = true,
      min_length = 1,
      persist = false,
      clear_all_mapping = false,
    })
    ui.open()
    feed_clipring("C")
    assert.are.equal(2, ring.count())
    ui.close()
  end)

  it("maps custom copy key from config", function()
    require("clipring.config").setup({
      max_entries = 20,
      deduplicate = true,
      min_length = 1,
      persist = false,
      copy_mapping = "c",
    })
    ui.open()
    feed_clipring("c")
    assert.are.equal("newer", vim.fn.getreg('"'))
    ui.close()
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

  it("ignores stale visual marks when opened from normal mode", function()
    local lines = {}
    for i = 1, 8 do
      lines[i] = "x" .. i
    end
    lines[9] = "hola"
    lines[10] = ""
    lines[11] = ""
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
    h.charwise_visual(win, h.pos(buf, 9, 1), h.pos(buf, 9, 4))
    vim.cmd("normal! \27")
    vim.api.nvim_win_set_cursor(win, { 11, 0 })
    ui.open()
    assert.is_nil(ui._state().visual_marks)
    ui.close()
  end)

  it("pastes on empty line after stale visual when opened from normal mode", function()
    local paste = require("clipring.paste")
    local lines = {}
    for i = 1, 8 do
      lines[i] = "x" .. i
    end
    lines[9] = "hola"
    lines[10] = ""
    lines[11] = ""
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
    h.charwise_visual(win, h.pos(buf, 9, 1), h.pos(buf, 9, 4))
    vim.cmd("normal! \27")
    vim.api.nvim_win_set_cursor(win, { 11, 0 })
    ui.open()
    local s = ui._state()
    ui.close(false)
    vim.api.nvim_set_current_win(win)
    paste.apply({ lines = { "PASTE" }, regtype = "v" }, "n", nil, win, s.opener_cursor)
    assert.are.equal("hola", vim.api.nvim_buf_get_lines(buf, 8, 9, false)[1])
    assert.are.equal("PASTE", vim.api.nvim_buf_get_lines(buf, 10, 11, false)[1])
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
