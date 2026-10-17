local languages = require("google-translate.languages")

describe("languages", function()
  it("lists auto only as a source language", function()
    assert.is_true(vim.list_contains(languages.source, "auto"))
    assert.is_false(vim.list_contains(languages.target, "auto"))
  end)

  it("uses the codes Google expects", function()
    local missing = vim.tbl_filter(function(code)
      return not vim.list_contains(languages.target, code)
    end, { "en", "ja", "zh-CN", "zh-TW", "iw" })
    assert.are.same({}, missing)
  end)

  it("is sorted", function()
    for _, list in ipairs({ languages.source, languages.target }) do
      local sorted = vim.deepcopy(list)
      table.sort(sorted)
      assert.are.same(sorted, list)
    end
  end)
end)
