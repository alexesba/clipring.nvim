local M = {}

local DEFAULT_FT = "clipring_preview"

local SKIP_FILETYPES = {
  [""] = true,
  text = true,
  plaintext = true,
  plaintex = true,
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

local FENCE_OPEN = "^```(%S*)%s*$"
local FENCE_CLOSE = "^```%s*$"

local function usable_filetype(ft)
  return ft and ft ~= "" and not SKIP_FILETYPES[ft]
end

---@param lang string
---@param contents string
---@return string|nil
local function filetype_from_lang(lang, contents)
  lang = lang:lower()
  local candidates = { LANG_EXT[lang], lang }
  local seen = {}
  for _, ext in ipairs(candidates) do
    if ext and not seen[ext] then
      seen[ext] = true
      local ft = vim.filetype.match({ filename = "clipring." .. ext, contents = contents })
      if usable_filetype(ft) then
        return ft
      end
    end
  end
  return nil
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

--- Heuristic content sniffing when there is no fence or shebang.
---@param lines string[]
---@param contents string
---@return string|nil
local function filetype_from_heuristics(lines, contents)
  if #lines < 2 then
    return nil
  end

  local rules = {
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
---@param opts ClipRingConfig|nil
---@return string[] content_lines, string filetype
function M.analyze(lines, opts)
  opts = opts or {}
  if opts.preview_syntax == false then
    return vim.deepcopy(lines), DEFAULT_FT
  end

  local body, fence_lang = M.strip_fenced_codeblock(lines)
  local contents = table.concat(body, "\n")
  local ft

  if fence_lang then
    ft = filetype_from_lang(fence_lang, contents)
  end

  if not ft then
    ft = filetype_from_shebang(body[1])
  end

  if not ft then
    ft = filetype_from_contents(contents)
  end

  if not ft then
    ft = filetype_from_heuristics(body, contents)
  end

  if not ft then
    ft = DEFAULT_FT
  end

  return body, ft
end

return M
