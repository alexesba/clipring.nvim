local h = require("tests.helpers")
local ring = require("clipring.ring")

describe("clipring.yank", function()
  before_each(function()
    h.reset()
    require("clipring.yank").setup()
  end)

  it("records yanks via TextYankPost", function()
    local buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, { "clipring" })
    vim.api.nvim_set_current_buf(buf)

    vim.fn.setreg('"', "clipring")
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("normal! yy")
    end)

    assert.are.equal(1, ring.count())
    assert.are.equal("clipring", ring.get(1).lines[1])

    vim.api.nvim_buf_delete(buf, { force = true })
  end)
end)
