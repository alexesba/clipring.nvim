local h = require("tests.helpers")
local which_key = require("clipring.which_key")

describe("clipring.which_key", function()
  before_each(function()
    h.reset()
  end)

  it("reports whether which-key is installed", function()
    assert.is_boolean(which_key.available())
  end)

  it("show_help is a no-op when which-key is unavailable", function()
    if which_key.available() then
      return
    end
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    assert.has_no.errors(function()
      which_key.show_help()
    end)
    vim.api.nvim_buf_delete(buf, { force = true })
  end)
end)
