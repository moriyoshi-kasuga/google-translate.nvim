---Translations kept for the session, so that translating the same text again sends no request.
local M = {}

---Maximum number of translations kept. The oldest is dropped first.
M.LIMIT = 100

local entries = {} ---@type table<string, google_translate.Result>
local keys = {} ---@type string[] In insertion order

---@param source string
---@param target string
---@param text string
---@return string
local function key(source, target, text)
  -- Language codes contain no newline, so the key is unambiguous.
  return table.concat({ source, target, text }, "\n")
end

---@param source string
---@param target string
---@param text string
---@return google_translate.Result?
function M.get(source, target, text)
  return entries[key(source, target, text)]
end

---@param source string
---@param target string
---@param text string
---@param result google_translate.Result
function M.set(source, target, text, result)
  local k = key(source, target, text)
  if entries[k] == nil then
    table.insert(keys, k)
    if #keys > M.LIMIT then
      entries[table.remove(keys, 1)] = nil
    end
  end
  entries[k] = result
end

function M.clear()
  entries, keys = {}, {}
end

return M
