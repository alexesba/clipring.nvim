local config = require("clipring.config")

local M = {}

---@class ClipRingEntry
---@field lines string[]
---@field regtype string
---@field time number
---@field filetype string|nil filetype of the buffer when the yank was captured

---@type ClipRingEntry[]
local entries = {}

local function entry_key(entry)
  return table.concat(entry.lines, "\n") .. "\0" .. entry.regtype
end

local function same_entry(a, b)
  return entry_key(a) == entry_key(b)
end

function M.get_all()
  return entries
end

function M.count()
  return #entries
end

function M.get(index)
  return entries[index]
end

---@param lines string[]
---@param regtype string
---@param filetype string|nil
function M.add(lines, regtype, filetype)
  if not lines or #lines == 0 then
    return
  end

  local text = table.concat(lines, "\n")
  local opts = config.get()
  if #text < opts.min_length then
    return
  end

  local entry = {
    lines = lines,
    regtype = regtype,
    time = os.time(),
    filetype = filetype,
  }

  if opts.deduplicate and #entries > 0 and same_entry(entries[1], entry) then
    return
  end

  if opts.deduplicate then
    for i = #entries, 1, -1 do
      if same_entry(entries[i], entry) then
        table.remove(entries, i)
        break
      end
    end
  end

  table.insert(entries, 1, entry)

  while #entries > opts.max_entries do
    table.remove(entries)
  end
end

function M.remove(index)
  if index < 1 or index > #entries then
    return false
  end
  table.remove(entries, index)
  return true
end

--- Swap entry at {index} with its neighbor. Negative delta moves toward the top (index 1).
---@param index number 1-based
---@param delta number -1 or 1
---@return number|nil new index after move, or nil if unchanged
function M.move(index, delta)
  if delta == 0 or index < 1 or index > #entries then
    return nil
  end
  local new_index = index + delta
  if new_index < 1 or new_index > #entries then
    return nil
  end
  entries[index], entries[new_index] = entries[new_index], entries[index]
  return new_index
end

function M.clear()
  entries = {}
end

---@param list ClipRingEntry[]
function M.replace(list)
  entries = list or {}
  local opts = config.get()
  while #entries > opts.max_entries do
    table.remove(entries)
  end
end

return M
