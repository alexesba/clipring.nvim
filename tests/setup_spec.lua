local h = require("tests.helpers")
local clipring = require("clipring")

describe("clipring.setup", function()
  before_each(function()
    h.reset()
  end)

  it("registers open_mapping in normal and insert modes", function()
    clipring.setup({ open_mapping = "<leader>cr" })
    assert.are_not.equal("", vim.fn.maparg("<leader>cr", "n"))
    assert.are_not.equal("", vim.fn.maparg("<leader>cr", "i"))
  end)

  it("supports multiple open_mapping keys", function()
    clipring.setup({ open_mapping = { "<leader>cr", "<M-y>" } })
    assert.are_not.equal("", vim.fn.maparg("<leader>cr", "n"))
    assert.are_not.equal("", vim.fn.maparg("<M-y>", "n"))
  end)

  it("registers clipring filetype with which-key disable when installed", function()
    local ok, wk_config = pcall(require, "which-key.config")
    if not ok then
      return
    end
    require("clipring.which_key").setup()
    assert.is_true(vim.tbl_contains(wk_config.disable.ft, "clipring"))
  end)

  it("clears open_mapping when setup sets open_mapping to false", function()
    clipring.setup({ open_mapping = "<leader>cr" })
    clipring.setup({ open_mapping = false })
    assert.are.equal("", vim.fn.maparg("<leader>cr", "n"))
  end)
end)
