local config = require("google-translate.config")
local float = require("google-translate.float")

describe("float.geometry", function()
  local cfg = { width = 0.75, height = 0.85 }

  it("shrinks to the content and the title", function()
    assert.are.same(
      { width = 10, height = 1, row = 19, col = 45 },
      float.geometry({ "hello" }, " en to ja ", cfg, 100, 40)
    )
  end)

  it("caps the width at the ratio and wraps long lines", function()
    assert.are.same(
      { width = 75, height = 2, row = 19, col = 12 },
      float.geometry({ string.rep("a", 150) }, "", cfg, 100, 40)
    )
  end)

  it("caps the height at the ratio", function()
    local lines = {}
    for i = 1, 100 do
      lines[i] = "x"
    end
    assert.are.equal(34, float.geometry(lines, "", cfg, 100, 40).height)
  end)

  it("treats values greater than 1 as cells and clamps them to the screen", function()
    local g = float.geometry({ string.rep("a", 50) }, "", { width = 20, height = 5 }, 100, 40)
    assert.are.same({ 20, 3 }, { g.width, g.height })
    g = float.geometry({ string.rep("a", 200) }, "", { width = 500, height = 500 }, 100, 40)
    assert.are.same({ 100, 2 }, { g.width, g.height })
  end)

  it("measures display width and counts blank lines", function()
    local g = float.geometry({ "こんにちは", "", "b" }, "", cfg, 100, 40)
    assert.are.same({ 10, 3 }, { g.width, g.height })
  end)
end)

describe("float.open", function()
  after_each(function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(win).relative ~= "" then
        vim.api.nvim_win_close(win, true)
      end
    end
    vim.o.winborder = ""
    config.setup()
  end)

  it("shows the text in a focused, read-only, wrapping float", function()
    local win = float.open("line1\nline2", " en to ja ")
    local buf = vim.api.nvim_win_get_buf(win)
    assert.are.equal(win, vim.api.nvim_get_current_win())
    assert.are.equal("editor", vim.api.nvim_win_get_config(win).relative)
    assert.are.same({ "line1", "line2" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    assert.is_false(vim.bo[buf].modifiable)
    assert.is_true(vim.wo[win].wrap)
  end)

  it("closes with q", function()
    local win = float.open("x", " en to ja ")
    vim.cmd("normal q")
    assert.is_false(vim.api.nvim_win_is_valid(win))
  end)

  it("closes when leaving the window", function()
    local win = float.open("x", " en to ja ")
    vim.cmd.wincmd("p")
    assert.is_true(vim.wait(1000, function()
      return not vim.api.nvim_win_is_valid(win)
    end))
  end)

  it("shows the title when there is a border", function()
    config.setup({ float = { border = "single" } })
    local win = float.open("x", " en to ja ")
    assert.are.equal(" en to ja ", vim.api.nvim_win_get_config(win).title[1][1])
  end)

  it("fits rows lost to wide characters at wrap boundaries", function()
    local columns = vim.o.columns
    finally(function()
      vim.o.columns = columns
    end)
    vim.o.columns = 101
    config.setup({ float = { border = "single" } })
    local win = float.open(string.rep("あ", 75), " en to ja ")
    assert.are.equal(vim.api.nvim_win_text_height(win, {}).all, vim.api.nvim_win_get_height(win))
    assert.are.equal(" en to ja ", vim.api.nvim_win_get_config(win).title[1][1])
  end)

  it("follows 'winborder' and omits the title without a border", function()
    local win = float.open("x", " en to ja ")
    assert.is_nil(vim.api.nvim_win_get_config(win).title)
  end)
end)
