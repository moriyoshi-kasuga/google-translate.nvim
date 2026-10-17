---@diagnostic disable: missing-fields, duplicate-set-field

local command = require("google-translate.command")
local config = require("google-translate.config")
local float = require("google-translate.float")
local gt = require("google-translate")

local function set_buffer(lines)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

local function lines(buf)
  return vim.api.nvim_buf_get_lines(buf or 0, 0, -1, false)
end

describe("command.parse", function()
  it("parses options in any order", function()
    assert.are.same({ target = "ja", source = "auto", float = false }, command.parse({ "ja" }))
    assert.are.same(
      { target = "ja", source = "en", float = true },
      command.parse({ "--float", "ja", "--source=en" })
    )
    assert.are.same({ source = "auto", float = false }, command.parse({}))
  end)

  it("rejects bad arguments", function()
    assert.are.same(
      { nil, "google-translate: unknown option: --flaot" },
      { command.parse({ "--flaot" }) }
    )
    assert.are.same(
      { nil, "google-translate: too many arguments: de" },
      { command.parse({ "ja", "de" }) }
    )
    assert.are.same(
      { nil, "google-translate: --source requires a value" },
      { command.parse({ "--source=" }) }
    )
  end)
end)

describe("command.complete", function()
  it("completes target languages without auto", function()
    local items = command.complete("j", "Translate j", 11)
    assert.is_true(vim.list_contains(items, "ja"))
    assert.is_false(vim.list_contains(command.complete("a", "Translate a", 11), "auto"))
    for _, item in ipairs(items) do
      assert.is_true(vim.startswith(item, "j"))
    end
  end)

  it("completes options and source languages", function()
    assert.are.same({ "--float", "--source=" }, command.complete("--", "Translate --", 12))
    local items = command.complete("--source=zh", "Translate --source=zh", 21)
    assert.is_true(vim.list_contains(items, "--source=zh-CN"))
    for _, item in ipairs(items) do
      assert.is_true(vim.startswith(item, "--source=zh"))
    end
  end)
end)

describe("command.region", function()
  it("covers whole lines for a plain range", function()
    local buf = set_buffer({ "one", "two", "three" })
    assert.are.same(
      { bufnr = buf, start_row = 1, start_col = 0, end_row = 2, end_col = 5 },
      command.region({ range = 2, line1 = 2, line2 = 3 })
    )
  end)

  it("uses the characterwise selection", function()
    local buf = set_buffer({ "hello world" })
    vim.api.nvim_win_set_cursor(0, { 1, 6 })
    vim.cmd("normal! ve\27")
    assert.are.same(
      { bufnr = buf, start_row = 0, start_col = 6, end_row = 0, end_col = 11 },
      command.region({ range = 2, line1 = 1, line2 = 1 })
    )
  end)

  it("includes a multibyte last character", function()
    local buf = set_buffer({ "これはペン" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd("normal! v2l\27")
    assert.are.same(
      { bufnr = buf, start_row = 0, start_col = 0, end_row = 0, end_col = 9 },
      command.region({ range = 2, line1 = 1, line2 = 1 })
    )
  end)

  it("follows 'selection' when it is exclusive", function()
    local selection = vim.o.selection
    finally(function()
      vim.o.selection = selection
    end)
    vim.o.selection = "exclusive"
    local buf = set_buffer({ "hello world" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd("normal! vl\27")
    assert.are.same(
      { bufnr = buf, start_row = 0, start_col = 0, end_row = 0, end_col = 1 },
      command.region({ range = 2, line1 = 1, line2 = 1 })
    )
  end)

  it("includes composing characters of the last character", function()
    -- "e" followed by U+0301 COMBINING ACUTE ACCENT
    local buf = set_buffer({ "cafe\204\129 au lait" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd("normal! v3l\27")
    assert.are.same(
      { bufnr = buf, start_row = 0, start_col = 0, end_row = 0, end_col = 6 },
      command.region({ range = 2, line1 = 1, line2 = 1 })
    )
  end)

  it("stops at the end of the line for a selection extended with $", function()
    local buf = set_buffer({ "abc" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd("normal! v$\27")
    assert.are.same(
      { bufnr = buf, start_row = 0, start_col = 0, end_row = 0, end_col = 3 },
      command.region({ range = 2, line1 = 1, line2 = 1 })
    )
  end)

  it("handles a selection on an empty line", function()
    local buf = set_buffer({ "" })
    vim.cmd("normal! v\27")
    assert.are.same(
      { bufnr = buf, start_row = 0, start_col = 0, end_row = 0, end_col = 0 },
      command.region({ range = 2, line1 = 1, line2 = 1 })
    )
  end)

  it("ignores the selection when the range does not match it", function()
    local buf = set_buffer({ "one", "two", "three" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd("normal! vl\27")
    assert.are.same(
      { bufnr = buf, start_row = 1, start_col = 0, end_row = 2, end_col = 5 },
      command.region({ range = 2, line1 = 2, line2 = 3 })
    )
  end)

  it("treats a linewise selection as lines", function()
    local buf = set_buffer({ "one", "two" })
    vim.api.nvim_win_set_cursor(0, { 1, 1 })
    vim.cmd("normal! Vj\27")
    assert.are.same(
      { bufnr = buf, start_row = 0, start_col = 0, end_row = 1, end_col = 3 },
      command.region({ range = 2, line1 = 1, line2 = 2 })
    )
  end)

  it("rejects a blockwise selection", function()
    set_buffer({ "one", "two" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd("normal! \22jl\27")
    assert.are.same(
      { nil, "google-translate: blockwise selection is not supported" },
      { command.region({ range = 2, line1 = 1, line2 = 2 }) }
    )
  end)
end)

describe("command.run", function()
  local original_translate, original_open, original_notify = gt.translate, float.open, vim.notify
  local requests, notifications, opened

  before_each(function()
    requests, notifications, opened = {}, {}, {}
    gt.translate = function(s, opts, callback)
      table.insert(requests, { text = s, opts = opts, callback = callback })
    end
    float.open = function(s, title)
      table.insert(opened, { text = s, title = title })
    end
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end
  end)

  after_each(function()
    gt.translate, float.open, vim.notify = original_translate, original_open, original_notify
    config.setup()
  end)

  it("replaces the lines with the translation", function()
    local buf = set_buffer({ "one", "two", "three" })
    command.run({ fargs = { "ja" }, range = 2, line1 = 1, line2 = 2 })
    assert.are.equal("one\ntwo", requests[1].text)
    assert.are.same({ source = "auto", target = "ja" }, requests[1].opts)
    requests[1].callback(nil, { text = "ichi\nni\nsan", source = "en" })
    assert.are.same({ "ichi", "ni", "san", "three" }, lines(buf))
  end)

  it("replaces only the characterwise selection, across lines", function()
    local buf = set_buffer({ "ab cd", "ef gh" })
    vim.api.nvim_win_set_cursor(0, { 1, 3 })
    vim.cmd("normal! vj\27")
    command.run({ fargs = { "ja" }, range = 2, line1 = 1, line2 = 2 })
    assert.are.equal("cd\nef g", requests[1].text)
    requests[1].callback(nil, { text = "X", source = "en" })
    assert.are.same({ "ab Xh" }, lines(buf))
  end)

  it("uses the configured target when none is given", function()
    config.setup({ target = "de" })
    set_buffer({ "one" })
    command.run({ fargs = {}, range = 0, line1 = 1, line2 = 1 })
    assert.are.equal("de", requests[1].opts.target)
  end)

  it("does nothing for whitespace-only text", function()
    set_buffer({ "   " })
    command.run({ fargs = { "ja" }, range = 0, line1 = 1, line2 = 1 })
    assert.are.equal(0, #requests)
    assert.are.equal(0, #notifications)
  end)

  it("does not replace when the buffer changed during translation", function()
    local buf = set_buffer({ "one" })
    command.run({ fargs = { "ja" }, range = 0, line1 = 1, line2 = 1 })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "edited" })
    requests[1].callback(nil, { text = "ichi", source = "en" })
    assert.are.same({ "edited" }, lines(buf))
    assert.are.same({
      msg = "google-translate: buffer changed during translation; skipped replacement",
      level = vim.log.levels.WARN,
    }, notifications[1])
  end)

  it("does not fail when the buffer was wiped during translation", function()
    local buf = set_buffer({ "one" })
    command.run({ fargs = { "ja" }, range = 0, line1 = 1, line2 = 1 })
    vim.api.nvim_buf_delete(buf, { force = true })
    requests[1].callback(nil, { text = "ichi", source = "en" })
    assert.are.equal(vim.log.levels.WARN, notifications[1].level)
  end)

  it("refuses to replace in a non-modifiable buffer", function()
    local buf = set_buffer({ "one" })
    vim.bo[buf].modifiable = false
    command.run({ fargs = { "ja" }, range = 0, line1 = 1, line2 = 1 })
    assert.are.equal(0, #requests)
    assert.are.same(
      { msg = "google-translate: buffer is not modifiable", level = vim.log.levels.ERROR },
      notifications[1]
    )
  end)

  it("reports argument and translation errors", function()
    local buf = set_buffer({ "one" })
    command.run({ fargs = { "--bogus" }, range = 0, line1 = 1, line2 = 1 })
    assert.are.equal(0, #requests)
    assert.are.same(
      { msg = "google-translate: unknown option: --bogus", level = vim.log.levels.ERROR },
      notifications[1]
    )
    command.run({ fargs = { "ja" }, range = 0, line1 = 1, line2 = 1 })
    requests[1].callback("google-translate: rate limited by Google (HTTP 429)")
    assert.are.same({
      msg = "google-translate: rate limited by Google (HTTP 429)",
      level = vim.log.levels.ERROR,
    }, notifications[2])
    assert.are.same({ "one" }, lines(buf))
  end)

  it("shows the translation in a float with --float", function()
    local buf = set_buffer({ "hello" })
    command.run({ fargs = { "ja", "--float" }, range = 0, line1 = 1, line2 = 1 })
    requests[1].callback(nil, { text = "こんにちは", source = "en" })
    assert.are.same({ { text = "こんにちは", title = " en to ja " } }, opened)
    command.run({ fargs = { "ja", "--float", "--source=fr" }, range = 0, line1 = 1, line2 = 1 })
    requests[2].callback(nil, { text = "こんにちは", source = "en" })
    assert.are.equal(" fr to ja ", opened[2].title)
    assert.are.same({ "hello" }, lines(buf))
  end)
end)

describe("plugin/google-translate.lua", function()
  it("registers :Translate", function()
    vim.opt.rtp:prepend(vim.fn.getcwd())
    vim.cmd.runtime("plugin/google-translate.lua")
    local original = gt.translate
    local received
    gt.translate = function(s)
      received = s
    end
    set_buffer({ "one", "two" })
    vim.cmd("2Translate ja")
    gt.translate = original
    assert.are.equal("two", received)
  end)
end)
