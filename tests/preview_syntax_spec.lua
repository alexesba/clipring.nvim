local preview_syntax = require("clipring.preview_syntax")

describe("clipring.preview_syntax", function()
  it("strips markdown fenced code blocks and detects the fence language", function()
    local body, lang = preview_syntax.strip_fenced_codeblock({
      "```ruby",
      "def foo",
      "end",
      "```",
    })
    assert.are.equal("ruby", lang)
    assert.same({ "def foo", "end" }, body)
  end)

  it("keeps plain lines when there is no fence", function()
    local body, lang = preview_syntax.strip_fenced_codeblock({ "hello", "world" })
    assert.is_nil(lang)
    assert.same({ "hello", "world" }, body)
  end)

  it("detects ruby from a fenced block", function()
    local _, ft = preview_syntax.analyze({
      "```ruby",
      "def foo",
      "  1",
      "end",
      "```",
    })
    assert.are.equal("ruby", ft)
  end)

  it("detects lua from a fenced block", function()
    local _, ft = preview_syntax.analyze({
      "```lua",
      "local function foo()",
      "  return 1",
      "end",
      "```",
    })
    assert.are.equal("lua", ft)
  end)

  it("heuristically detects ruby without a fence", function()
    local _, ft = preview_syntax.analyze({
      "class Widget",
      "  def name",
      "    'clipring'",
      "  end",
      "end",
    })
    assert.are.equal("ruby", ft)
  end)

  it("heuristically detects python without a fence", function()
    local _, ft = preview_syntax.analyze({
      "import os",
      "def main():",
      "    print('hi')",
    })
    assert.are.equal("python", ft)
  end)

  it("detects single-line lua without a fence", function()
    local _, ft = preview_syntax.analyze({ 'require("clipring").setup({})' })
    assert.are.equal("lua", ft)
  end)

  it("falls back to clipring_preview for plain prose", function()
    local lines, ft = preview_syntax.analyze({ "Just a short note." })
    assert.same({ "Just a short note." }, lines)
    assert.are.equal("clipring_preview", ft)
  end)

  it("can be disabled via config", function()
    local _, ft = preview_syntax.analyze({
      "```ruby",
      "def foo",
      "end",
      "```",
    }, { preview_syntax = false })
    assert.are.equal("clipring_preview", ft)
  end)
end)
