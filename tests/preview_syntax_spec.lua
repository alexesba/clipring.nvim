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

  it("detects multi-line lua with clipring requires without matching plugin filetype", function()
    local _, ft = preview_syntax.analyze({
      'local config = require("clipring.config")',
      'local yank = require("clipring.yank")',
      'local persist = require("clipring.persist")',
      'local ui = require("clipring.ui")',
      'local which_key = require("clipring.which_key")',
    })
    assert.are.equal("lua", ft)
  end)

  it("detects bash from a fenced block", function()
    local _, ft = preview_syntax.analyze({
      "```bash",
      "echo hello",
      "```",
    })
    assert.are.equal("bash", ft)
  end)

  it("detects bash from shebang", function()
    local _, ft = preview_syntax.analyze({
      "#!/usr/bin/env bash",
      "set -euo pipefail",
      'echo "hi"',
    })
    assert.are.equal("bash", ft)
  end)

  it("heuristically detects bash without a fence or shebang", function()
    local _, ft = preview_syntax.analyze({
      "set -euo pipefail",
      'export FOO="bar"',
      "echo hello",
    })
    assert.are.equal("bash", ft)
  end)

  it("heuristically detects rails schema.rb as ruby", function()
    local _, ft = preview_syntax.analyze({
      '  create_table "active_storage_attachments", force: :cascade do |t|',
      '    t.bigint "blob_id", null: false',
      '    t.datetime "created_at", precision: nil, null: false',
      '    t.string "name", null: false',
      '    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"',
      "  end",
    })
    assert.are.equal("ruby", ft)
  end)

  it("heuristically detects indented source lines as bash", function()
    local _, ft = preview_syntax.analyze({
      '  source "$DOTFILES_DIR/shell/common/functions.sh"',
      '  source "$DOTFILES_DIR/shell/common/terminal/use.sh"',
    })
    assert.are.equal("bash", ft)
  end)

  it("uses source_filetype from the yank buffer when snippet sniffing is ambiguous", function()
    local _, ft = preview_syntax.analyze({
      '  source "$DOTFILES_DIR/shell/common/functions.sh"',
    }, { source_filetype = "sh" })
    assert.are.equal("sh", ft)
  end)

  it("ignores generic source buffers like markdown", function()
    local _, ft = preview_syntax.analyze({
      '  create_table "widgets" do |t|',
      '    t.string "name"',
      "  end",
    }, { source_filetype = "markdown" })
    assert.are.equal("ruby", ft)
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
