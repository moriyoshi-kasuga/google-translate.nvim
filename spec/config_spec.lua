---@diagnostic disable: assign-type-mismatch

local config = require("google-translate.config")

describe("config.setup", function()
  after_each(function()
    config.setup()
  end)

  it("uses the defaults when called without options", function()
    config.setup()
    assert.are.same({ target = "en", float = { height = 0.85, width = 0.75 } }, config.options)
  end)

  it("merges nested options over the defaults", function()
    config.setup({ float = { width = 0.5, border = "single" } })
    assert.are.same(
      { target = "en", float = { height = 0.85, width = 0.5, border = "single" } },
      config.options
    )
  end)

  it("starts from the defaults on every call", function()
    config.setup({ target = "ja" })
    config.setup({ float = { width = 0.5 } })
    assert.are.equal("en", config.options.target)
    assert.are.equal(0.75, config.defaults.float.width)
  end)

  it("rejects unknown keys", function()
    assert.error_matches(function()
      config.setup({ taget = "ja" })
    end, "google-translate: unknown option: taget", 1, true)
    assert.error_matches(function()
      config.setup({ float = { widht = 1 } })
    end, "google-translate: unknown option: float.widht", 1, true)
  end)

  it("rejects invalid values", function()
    assert.has_error(function()
      config.setup({ target = 1 })
    end)
    assert.error_matches(function()
      config.setup({ target = "xx" })
    end, "google-translate: unknown target language: xx", 1, true)
    assert.has_error(function()
      config.setup({ float = { height = 0 } })
    end)
    assert.has_error(function()
      config.setup({ float = { border = 1 } })
    end)
  end)

  it("keeps the previous options when validation fails", function()
    config.setup({ target = "ja" })
    pcall(config.setup, { target = 1 })
    assert.are.equal("ja", config.options.target)
  end)
end)
