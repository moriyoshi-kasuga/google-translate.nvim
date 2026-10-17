local text = require("google-translate.text")

describe("text.split_padding", function()
  it("separates leading and trailing whitespace from the body", function()
    assert.are.same({ "\n  ", "foo\n  bar", "  \n" }, { text.split_padding("\n  foo\n  bar  \n") })
  end)

  it("returns an empty body for whitespace-only input", function()
    assert.are.same({ " \n ", "", "" }, { text.split_padding(" \n ") })
  end)

  it("returns empty padding when there is none", function()
    assert.are.same({ "", "foo", "" }, { text.split_padding("foo") })
  end)
end)

describe("text.chunk", function()
  it("returns a single chunk when the text fits", function()
    assert.are.same({ "a\nb" }, text.chunk("a\nb", 10))
  end)

  it("splits at line boundaries without exceeding the limit", function()
    assert.are.same({ "aaa\nbbb", "ccc" }, text.chunk("aaa\nbbb\nccc", 7))
  end)

  it("counts characters, not bytes", function()
    assert.are.same({ "あいう\nえお" }, text.chunk("あいう\nえお", 6))
  end)

  it("keeps a line longer than the limit as its own chunk", function()
    assert.are.same({ "a", "bbbbbbbbbb", "c" }, text.chunk("a\nbbbbbbbbbb\nc", 3))
  end)

  it("preserves blank lines so that joining with newlines restores the input", function()
    local s = "aa\n\n\nbb\n"
    assert.are.equal(s, table.concat(text.chunk(s, 3), "\n"))
  end)
end)
