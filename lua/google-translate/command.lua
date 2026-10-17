local config = require("google-translate.config")
local float = require("google-translate.float")
local gt = require("google-translate")
local languages = require("google-translate.languages")

local M = {}

---@class google_translate.Args
---@field target? string
---@field source string
---@field float boolean

---@class google_translate.Region
---@field bufnr integer
---@field start_row integer 0-based
---@field start_col integer 0-based byte
---@field end_row integer 0-based
---@field end_col integer 0-based byte, exclusive

local OPTIONS = { "--float", "--source=" }

---Parses `:Translate [{target}] [--source={source}] [--float]`.
---@param fargs string[]
---@return google_translate.Args?
---@return string? error
function M.parse(fargs)
  ---@type google_translate.Args
  local args = { source = "auto", float = false }
  for _, arg in ipairs(fargs) do
    local source = arg:match("^%-%-source=(.*)$")
    if arg == "--float" then
      args.float = true
    elseif source then
      if source == "" then
        return nil, "google-translate: --source requires a value"
      end
      args.source = source
    elseif vim.startswith(arg, "-") then
      return nil, "google-translate: unknown option: " .. arg
    elseif args.target then
      return nil, "google-translate: too many arguments: " .. arg
    else
      args.target = arg
    end
  end
  return args
end

---@param arglead string
---@param _cmdline string
---@param _cursorpos integer
---@return string[]
function M.complete(arglead, _cmdline, _cursorpos)
  local items
  if vim.startswith(arglead, "--source=") then
    items = vim.tbl_map(function(code)
      return "--source=" .. code
    end, languages.source)
  elseif vim.startswith(arglead, "-") then
    items = OPTIONS
  else
    items = languages.target
  end
  return vim.tbl_filter(function(item)
    return vim.startswith(item, arglead)
  end, items)
end

---Returns the text the command applies to in the current buffer.
---A range equal to the last Visual selection is taken as that selection,
---so a characterwise selection covers only the selected characters.
---@param cmd vim.api.keyset.create_user_command.command_args
---@return google_translate.Region?
---@return string? error
function M.region(cmd)
  local bufnr = vim.api.nvim_get_current_buf()
  local from_visual = cmd.range == 2
    and cmd.line1 == vim.fn.line("'<")
    and cmd.line2 == vim.fn.line("'>")
  local mode = from_visual and vim.fn.visualmode() or "V"

  if mode == "\22" then
    return nil, "google-translate: blockwise selection is not supported"
  end
  if mode == "v" then
    -- getregionpos() follows 'selection', includes composing characters and
    -- stops at the end of the line after `$`.
    local positions = vim.fn.getregionpos(vim.fn.getpos("'<"), vim.fn.getpos("'>"), { type = "v" })
    local first, last = positions[1][1], positions[#positions][2]
    return {
      bufnr = bufnr,
      start_row = first[2] - 1,
      -- Column 0 marks an empty line.
      start_col = math.max(first[3] - 1, 0),
      end_row = last[2] - 1,
      -- The last byte, 1-based and inclusive, is the 0-based exclusive end.
      end_col = last[3],
    }
  end

  local last = vim.api.nvim_buf_get_lines(bufnr, cmd.line2 - 1, cmd.line2, true)[1]
  return {
    bufnr = bufnr,
    start_row = cmd.line1 - 1,
    start_col = 0,
    end_row = cmd.line2 - 1,
    end_col = #last,
  }
end

---Implements `:Translate`.
---@param cmd vim.api.keyset.create_user_command.command_args
function M.run(cmd)
  local args, args_err = M.parse(cmd.fargs)
  if not args then
    vim.notify(assert(args_err), vim.log.levels.ERROR)
    return
  end
  local region, region_err = M.region(cmd)
  if not region then
    vim.notify(assert(region_err), vim.log.levels.ERROR)
    return
  end

  local lines = vim.api.nvim_buf_get_text(
    region.bufnr,
    region.start_row,
    region.start_col,
    region.end_row,
    region.end_col,
    {}
  )
  local text = table.concat(lines, "\n")
  if text:match("^%s*$") then
    return
  end
  if not args.float and not vim.bo[region.bufnr].modifiable then
    vim.notify("google-translate: buffer is not modifiable", vim.log.levels.ERROR)
    return
  end

  local target = args.target or config.options.target
  local changedtick = vim.api.nvim_buf_get_changedtick(region.bufnr)
  gt.translate(text, { source = args.source, target = target }, function(err, result)
    if not result then
      vim.notify(assert(err), vim.log.levels.ERROR)
      return
    end

    if args.float then
      local source = args.source == "auto" and result.source or args.source
      float.open(result.text, (" %s to %s "):format(source, target))
      return
    end

    if
      not vim.api.nvim_buf_is_valid(region.bufnr)
      or vim.api.nvim_buf_get_changedtick(region.bufnr) ~= changedtick
    then
      vim.notify(
        "google-translate: buffer changed during translation; skipped replacement",
        vim.log.levels.WARN
      )
      return
    end
    vim.api.nvim_buf_set_text(
      region.bufnr,
      region.start_row,
      region.start_col,
      region.end_row,
      region.end_col,
      vim.split(result.text, "\n", { plain = true })
    )
  end)
end

return M
