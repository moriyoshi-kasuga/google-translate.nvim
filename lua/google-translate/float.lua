local config = require("google-translate.config")

local M = {}

---@class google_translate.FloatGeometry
---@field width integer
---@field height integer
---@field row integer
---@field col integer

---Resolves a size option: a ratio of `total` when <= 1, otherwise cells.
---@param value number
---@param total integer
---@return integer
local function resolve(value, total)
  if value <= 1 then
    return math.max(1, math.floor(total * value))
  end
  return math.min(math.floor(value), total)
end

---Computes a centered window that fits `lines` and `title`, wrapping lines
---and staying within the maximum size from `cfg`.
---@param lines string[]
---@param title string
---@param cfg google_translate.FloatConfig
---@param columns integer
---@param rows integer
---@return google_translate.FloatGeometry
function M.geometry(lines, title, cfg, columns, rows)
  local widths = {} ---@type integer[]
  local content_width = math.max(1, vim.fn.strdisplaywidth(title))
  for i, line in ipairs(lines) do
    widths[i] = vim.fn.strdisplaywidth(line)
    content_width = math.max(content_width, widths[i])
  end
  local width = math.min(resolve(cfg.width, columns), content_width)

  local wrapped_rows = 0
  for _, line_width in ipairs(widths) do
    wrapped_rows = wrapped_rows + math.max(1, math.ceil(line_width / width))
  end
  local height = math.min(resolve(cfg.height, rows), wrapped_rows)

  return {
    width = width,
    height = height,
    row = math.floor((rows - height) / 2),
    col = math.floor((columns - width) / 2),
  }
end

---Shows `text` in a focused, read-only float centered in the editor.
---@param text string
---@param title string
---@return integer winid
function M.open(text, title)
  local cfg = config.options.float
  local lines = vim.split(text, "\n", { plain = true })
  local geometry = M.geometry(lines, title, cfg, vim.o.columns, vim.o.lines - vim.o.cmdheight)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  -- Some Neovim versions reject a title on a window without a border.
  local border = cfg.border or vim.o.winborder
  local has_border = border ~= "" and border ~= "none"
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    style = "minimal",
    width = geometry.width,
    height = geometry.height,
    row = geometry.row,
    col = geometry.col,
    border = cfg.border,
    title = has_border and title or nil,
    title_pos = has_border and "center" or nil,
  })
  vim.wo[win].wrap = true

  vim.keymap.set("n", "q", "<Cmd>close<CR>", {
    buffer = buf,
    nowait = true,
    desc = "Close the translation",
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      -- Closing windows inside WinLeave can fail, so do it afterwards.
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end)
    end,
  })
  return win
end

return M
