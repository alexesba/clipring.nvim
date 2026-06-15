local M = {}

local DEFAULT_FT = "clipring_preview"

-- Detection pipeline (first match wins):
--   1. Markdown ```lang fences in the yanked text
--   2. Shebang (#!…) in the yanked text
--   3. Source buffer filetype captured at yank time (see yank.lua)
--   4. Snippet heuristics — fallback for pastes and generic buffers (markdown, text, …)
--   5. vim.filetype.match on content
--   6. clipring_preview (plain text)

local SKIP_FILETYPES = {
  [""] = true,
  text = true,
  plaintext = true,
  plaintex = true,
  -- ClipRing picker buffers; not real languages (no treesitter parser).
  clipring = true,
  clipring_preview = true,
}

--- Filetypes too generic to trust as the yank source language.
local GENERIC_SOURCE_FT = {
  markdown = true,
  help = true,
  text = true,
  plaintext = true,
  plaintex = true,
  clipring = true,
  clipring_preview = true,
}

--- Markdown fence language id -> file extension for vim.filetype.match.
local LANG_EXT = {
  bash = "sh",
  c = "c",
  cpp = "cpp",
  csharp = "cs",
  cs = "cs",
  docker = "dockerfile",
  dockerfile = "dockerfile",
  elixir = "ex",
  ex = "ex",
  go = "go",
  golang = "go",
  html = "html",
  java = "java",
  javascript = "js",
  js = "js",
  json = "json",
  kotlin = "kt",
  kt = "kt",
  lua = "lua",
  markdown = "md",
  md = "md",
  perl = "pl",
  php = "php",
  python = "py",
  py = "py",
  r = "r",
  ruby = "rb",
  rb = "rb",
  rust = "rs",
  rs = "rs",
  scala = "scala",
  sh = "sh",
  shell = "sh",
  sql = "sql",
  swift = "swift",
  toml = "toml",
  typescript = "ts",
  ts = "ts",
  vim = "vim",
  yaml = "yaml",
  yml = "yaml",
  zsh = "sh",
}

--- Fence/shebang language id -> Vim filetype (when match is ambiguous or unavailable).
local LANG_FILETYPE = {
  bash = "bash",
  sh = "sh",
  shell = "sh",
  zsh = "zsh",
  lua = "lua",
  ruby = "ruby",
  rb = "ruby",
  python = "python",
  py = "python",
  javascript = "javascript",
  js = "javascript",
  typescript = "typescript",
  ts = "typescript",
  go = "go",
  golang = "go",
  rust = "rust",
  rs = "rust",
  json = "json",
  yaml = "yaml",
  yml = "yaml",
  vim = "vim",
  sql = "sql",
  html = "html",
  java = "java",
  kotlin = "kotlin",
  kt = "kotlin",
  php = "php",
  perl = "perl",
  c = "c",
  cpp = "cpp",
  csharp = "cs",
  cs = "cs",
  docker = "dockerfile",
  dockerfile = "dockerfile",
  elixir = "elixir",
  ex = "elixir",
  scala = "scala",
  swift = "swift",
  toml = "toml",
  markdown = "markdown",
  md = "markdown",
}

local FENCE_OPEN = "^```(%S*)%s*$"
local FENCE_CLOSE = "^```%s*$"

local function usable_filetype(ft)
  return ft and ft ~= "" and not SKIP_FILETYPES[ft]
end

local function usable_source_filetype(ft)
  return usable_filetype(ft) and not GENERIC_SOURCE_FT[ft]
end

--- Strip common leading indentation so line-anchored patterns work on yanked blocks.
---@param lines string[]
---@return string[]
local function dedent_lines(lines)
  local min_indent = math.huge
  for _, line in ipairs(lines) do
    if line:match("%S") then
      min_indent = math.min(min_indent, #(line:match("^(%s*)") or ""))
    end
  end
  if min_indent == math.huge or min_indent == 0 then
    return lines
  end
  local out = {}
  for _, line in ipairs(lines) do
    if line == "" then
      out[#out + 1] = line
    else
      out[#out + 1] = line:sub(min_indent + 1)
    end
  end
  return out
end

---@param lang string
---@param contents string
---@return string|nil
local function filetype_from_lang(lang, contents)
  lang = lang:lower()
  -- vim.filetype.match maps bash → sh; prefer bash so the installed parser is used.
  if lang == "bash" then
    return "bash"
  end
  local candidates = { LANG_EXT[lang], lang }
  local seen = {}
  for _, ext in ipairs(candidates) do
    if ext and not seen[ext] then
      seen[ext] = true
      -- Neutral filename: "clipring.<ext>" can resolve to the plugin filetype.
      local ft = vim.filetype.match({ filename = "preview." .. ext, contents = contents })
      if usable_filetype(ft) then
        return ft
      end
    end
  end
  return LANG_FILETYPE[lang]
end

---@param contents string
---@return string|nil
local function filetype_from_contents(contents)
  local ft = vim.filetype.match({ contents = contents })
  if usable_filetype(ft) then
    return ft
  end
  return nil
end

---@param line string|nil
---@return string|nil
local function filetype_from_shebang(line)
  if not line or not line:find("^#!") then
    return nil
  end
  local lang = line:match("^#!%s*/usr/bin/env%s+(%S+)")
    or line:match("^#!%s*/usr/bin/%s*(%S+)")
    or line:match("^#!%s*/%S*/(%S+)%s*$")
  if not lang then
    return nil
  end
  lang = lang:gsub("^%-%S+", ""):match("^(%S+)")
  if not lang then
    return nil
  end
  return filetype_from_lang(lang, line)
end

--- Snippet heuristics — last resort when yank did not come from a typed source buffer.
---@param contents string
---@return string|nil
local function filetype_from_heuristics(contents)
  local rules = {
    { ft = "lua", re = "^require%s*%(" },
    { ft = "lua", re = "^return%s*{" },
    { ft = "python", re = "\ndef %w+%([^)]*%)%s*:" },
    { ft = "python", re = "^def %w+%([^)]*%)%s*:" },
    { ft = "python", re = "\nfrom %w+ import " },
    { ft = "python", re = "^from %w+ import " },
    { ft = "python", re = "\nimport %w+" },
    { ft = "python", re = "^import %w+" },
    { ft = "ruby", re = "^class %w" },
    { ft = "ruby", re = "^module %w" },
    { ft = "ruby", re = "\n%s+def %w" },
    { ft = "ruby", re = "\ndef %w+%([^)]*%)%s*$" },
    { ft = "ruby", re = "\ndef %w+%([^)]*%)%s*\n" },
    { ft = "ruby", re = "^def %w+%([^)]*%)%s*$" },
    { ft = "ruby", re = "create_table%s+" },
    { ft = "ruby", re = "add_column%s+" },
    { ft = "ruby", re = "change_table%s+" },
    { ft = "ruby", re = "drop_table%s+" },
    { ft = "ruby", re = "enable_extension%s+" },
    { ft = "ruby", re = "add_foreign_key%s+" },
    { ft = "ruby", re = "remove_column%s+" },
    { ft = "ruby", re = "rename_column%s+" },
    { ft = "ruby", re = "ActiveRecord::Migration" },
    { ft = "ruby", re = "do%s*|%w+|%s*do" },
    { ft = "ruby", re = "t%.%w+%s*[\"']" },
    { ft = "javascript", re = "function%s+%w+%s*%(" },
    { ft = "javascript", re = "const%s+%w+%s*=" },
    { ft = "javascript", re = "=>%s*[%({]" },
    { ft = "typescript", re = "interface%s+%w+" },
    { ft = "lua", re = "\nlocal %w+" },
    { ft = "lua", re = "^local %w+" },
    { ft = "lua", re = "\nfunction%s+%w+%s*%(" },
    { ft = "lua", re = "^function%s+%w+%s*%(" },
    { ft = "go", re = "^package %w" },
    { ft = "go", re = "\nfunc %w" },
    { ft = "rust", re = "\nfn %w" },
    { ft = "rust", re = "^fn %w" },
    { ft = "rust", re = "\nuse %w" },
    { ft = "sql", re = "^%s*SELECT%s+" },
    { ft = "sql", re = "^%s*INSERT%s+INTO" },
    { ft = "sql", re = "^%s*CREATE%s+TABLE" },
    { ft = "html", re = "^<!%-%-" },
    { ft = "html", re = "<%s*[a-zA-Z]+[%s/>]" },
    { ft = "json", re = "^%s*[%[{]" },
    { ft = "yaml", re = "^%s*[%w_%-]+%s*:" },
    { ft = "vim", re = "^%s*function%!" },
    { ft = "vim", re = "^%s*autocmd%s" },
    { ft = "bash", re = "^%s*set%s+%-" },
    { ft = "bash", re = "^%s*export%s+%w" },
    { ft = "bash", re = "^%s*echo%s+" },
    { ft = "bash", re = "^%s*source%s+" },
    { ft = "bash", re = "\n%s*source%s+" },
    { ft = "bash", re = "^%s*function%s+%w+" },
    { ft = "bash", re = "^%s*%w+%)%s*{" },
    { ft = "bash", re = "if%s+%[" },
    { ft = "bash", re = "^%s*%w+=%$%(" },
    { ft = "bash", re = "^%s*%[%[%s+" },
    { ft = "bash", re = "^%s*alias%s+%w" },
    { ft = "bash", re = "^%s*%.%s+" },
  }

  for _, rule in ipairs(rules) do
    if contents:find(rule.re) then
      return rule.ft
    end
  end

  return nil
end

---@param lines string[]
---@return string[] body, string|nil lang
function M.strip_fenced_codeblock(lines)
  if #lines == 0 then
    return lines, nil
  end

  local lang = lines[1]:match(FENCE_OPEN)
  if not lang then
    return lines, nil
  end

  lang = lang ~= "" and lang or nil
  local body = {}
  local last = #lines
  if last > 1 and lines[last]:match(FENCE_CLOSE) then
    last = last - 1
  end
  for i = 2, last do
    body[#body + 1] = lines[i]
  end
  return body, lang
end

---@param lines string[]
---@param opts ClipRingConfig|nil opts.source_filetype from the buffer where the yank happened
---@return string[] content_lines, string filetype
function M.analyze(lines, opts)
  opts = opts or {}
  if opts.preview_syntax == false then
    return vim.deepcopy(lines), DEFAULT_FT
  end

  local body, fence_lang = M.strip_fenced_codeblock(lines)
  local sniff_lines = dedent_lines(body)
  local contents = table.concat(sniff_lines, "\n")
  local ft

  if fence_lang then
    ft = filetype_from_lang(fence_lang, contents)
  end

  if not ft then
    ft = filetype_from_shebang(sniff_lines[1])
  end

  if not ft and opts.source_filetype then
    ft = usable_source_filetype(opts.source_filetype) and opts.source_filetype or nil
  end

  if not ft then
    ft = filetype_from_heuristics(contents)
  end

  if not ft then
    ft = filetype_from_contents(contents)
  end

  if not ft then
    ft = DEFAULT_FT
  end

  return body, ft
end

return M
