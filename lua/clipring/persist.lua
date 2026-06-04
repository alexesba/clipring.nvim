local config = require("clipring.config")
local ring = require("clipring.ring")

local M = {}
local augroup = nil

local function ensure_parent(path)
  local dir = vim.fs.dirname(path)
  if dir and vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

function M.load()
  local opts = config.get()
  if not opts.persist then
    return
  end

  local path = opts.persist_path
  if vim.fn.filereadable(path) ~= 1 then
    return
  end

  local fd = io.open(path, "r")
  if not fd then
    return
  end

  local raw = fd:read("*a")
  fd:close()

  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" then
    vim.notify("ClipRing: could not load history from " .. path, vim.log.levels.WARN)
    return
  end

  local entries = {}
  for _, item in ipairs(data) do
    if type(item) == "table" and type(item.lines) == "table" and type(item.regtype) == "string" then
      table.insert(entries, {
        lines = item.lines,
        regtype = item.regtype,
        time = item.time or os.time(),
      })
    end
  end

  ring.replace(entries)
end

function M.save()
  local opts = config.get()
  if not opts.persist then
    return
  end

  local path = opts.persist_path
  ensure_parent(path)

  local payload = {}
  for _, entry in ipairs(ring.get_all()) do
    table.insert(payload, {
      lines = entry.lines,
      regtype = entry.regtype,
      time = entry.time,
    })
  end

  local fd = io.open(path, "w")
  if not fd then
    vim.notify("ClipRing: could not save history to " .. path, vim.log.levels.WARN)
    return
  end

  fd:write(vim.json.encode(payload))
  fd:close()
end

function M.setup()
  M.load()

  if augroup then
    return
  end

  augroup = vim.api.nvim_create_augroup("ClipRingPersist", { clear = true })

  vim.api.nvim_create_autocmd({ "VimLeavePre", "VimSuspend" }, {
    group = augroup,
    desc = "ClipRing: persist history",
    callback = function()
      M.save()
    end,
  })
end

return M
