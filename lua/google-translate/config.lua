local languages = require("google-translate.languages")

local M = {}

---@class google_translate.FloatConfig
---@field height number Maximum height: a ratio of the editor when <= 1, otherwise rows
---@field width number Maximum width: a ratio of the editor when <= 1, otherwise columns
---@field border? string|string[] Falls back to 'winborder' when nil

---@class google_translate.Config
---@field target string
---@field float google_translate.FloatConfig

---@class google_translate.UserConfig
---@field target? string
---@field float? { height?: number, width?: number, border?: string|string[] }

---@type google_translate.Config
M.defaults = {
  target = "en",
  float = { height = 0.85, width = 0.75 },
}

---Current options. `setup` replaces the whole table, so read it at call time.
---@type google_translate.Config
M.options = vim.deepcopy(M.defaults)

---@param tbl table
---@param known string[]
---@param prefix string
local function reject_unknown_keys(tbl, known, prefix)
  for key in pairs(tbl) do
    if not vim.list_contains(known, key) then
      error(("google-translate: unknown option: %s%s"):format(prefix, key), 0)
    end
  end
end

---@param value any
---@return boolean
local function is_positive_number(value)
  return type(value) == "number" and value > 0
end

---Validates `opts` and applies them over the defaults.
---Options from earlier calls are discarded.
---@param opts? google_translate.UserConfig
function M.setup(opts)
  opts = opts or {}
  vim.validate("opts", opts, "table")
  reject_unknown_keys(opts, { "target", "float" }, "")
  vim.validate("float", opts.float, "table", true)
  reject_unknown_keys(opts.float or {}, { "height", "width", "border" }, "float.")

  local options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
  vim.validate("target", options.target, "string")
  if not vim.list_contains(languages.target, options.target) then
    error("google-translate: unknown target language: " .. options.target, 0)
  end
  vim.validate("float.height", options.float.height, is_positive_number, "positive number")
  vim.validate("float.width", options.float.width, is_positive_number, "positive number")
  vim.validate("float.border", options.float.border, { "string", "table" }, true)
  M.options = options
end

return M
