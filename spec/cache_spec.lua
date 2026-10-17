local cache = require("google-translate.cache")

describe("cache", function()
  after_each(function()
    cache.LIMIT = 100
    cache.clear()
  end)

  it("keeps translations apart by language pair", function()
    cache.set("auto", "ja", "hello", { text = "こんにちは", source = "en" })
    assert.are.same({ text = "こんにちは", source = "en" }, cache.get("auto", "ja", "hello"))
    assert.is_nil(cache.get("auto", "de", "hello"))
    assert.is_nil(cache.get("en", "ja", "hello"))
  end)

  it("drops the oldest entry beyond the limit", function()
    cache.LIMIT = 2
    cache.set("auto", "ja", "a", { text = "A", source = "en" })
    cache.set("auto", "ja", "b", { text = "B", source = "en" })
    cache.set("auto", "ja", "a", { text = "A2", source = "en" })
    cache.set("auto", "ja", "c", { text = "C", source = "en" })
    assert.is_nil(cache.get("auto", "ja", "a"))
    assert.are.same({ text = "B", source = "en" }, cache.get("auto", "ja", "b"))
    assert.are.same({ text = "C", source = "en" }, cache.get("auto", "ja", "c"))
  end)
end)
