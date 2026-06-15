local M = {}

local function treesitter_lang(filetype)
  if not (vim.treesitter and vim.treesitter.language and vim.treesitter.language.get_lang) then
    return filetype
  end
  return vim.treesitter.language.get_lang(filetype) or filetype
end

local function attach_builtin_treesitter(buf, filetype)
  if not (vim.treesitter and vim.treesitter.start) then
    return false
  end
  local lang = treesitter_lang(filetype)
  pcall(vim.treesitter.stop, buf)
  return pcall(vim.treesitter.start, buf, lang)
end

local function attach_nvim_treesitter(buf, filetype)
  local lang = treesitter_lang(filetype)
  if not lang then
    return false
  end

  local ok, configs = pcall(require, "nvim-treesitter.configs")
  if ok and configs.get_module then
    local highlight = configs.get_module("highlight")
    if highlight and highlight.attach then
      return pcall(highlight.attach, buf, lang)
    end
  end

  for _, modname in ipairs({ "nvim-treesitter.highlight", "nvim-treesitter.highlighter" }) do
    local mod_ok, mod = pcall(require, modname)
    if mod_ok and mod.attach then
      return pcall(mod.attach, buf, lang)
    end
  end

  return false
end

local function attach_vim_syntax(buf, filetype)
  vim.api.nvim_buf_call(buf, function()
    vim.bo.filetype = filetype
    vim.bo.syntax = "on"
    vim.cmd("syntax sync fromstart")
  end)
  return true
end

---@param buf number
---@param filetype string
function M.attach(buf, filetype)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  if filetype == "clipring_preview" or filetype == "" then
    if vim.treesitter and vim.treesitter.stop then
      pcall(vim.treesitter.stop, buf)
    end
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_option(buf, "filetype", "clipring_preview")
    vim.api.nvim_buf_set_option(buf, "syntax", "off")
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    return
  end

  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  if vim.treesitter and vim.treesitter.stop then
    pcall(vim.treesitter.stop, buf)
  end
  vim.api.nvim_buf_set_option(buf, "filetype", filetype)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  vim.api.nvim_exec_autocmds("FileType", {
    buffer = buf,
    modeline = false,
    data = filetype,
  })

  local function run()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    if vim.api.nvim_buf_get_option(buf, "filetype") ~= filetype then
      return
    end
    attach_builtin_treesitter(buf, filetype)
    attach_nvim_treesitter(buf, filetype)
    attach_vim_syntax(buf, filetype)
  end

  run()
  vim.schedule(run)
  vim.defer_fn(run, 40)
end

return M
