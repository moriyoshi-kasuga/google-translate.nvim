---@diagnostic disable: duplicate-set-field

local gt = require("google-translate")
local client = require("google-translate.client")
local config = require("google-translate.config")
local text = require("google-translate.text")

describe("translate", function()
  local original_request = client.request
  local calls

  local function fake_request(body, source, target, callback)
    table.insert(calls, { body = body, source = source, target = target })
    vim.schedule(function()
      callback(nil, { text = body:upper(), source = "en" })
    end)
  end

  local function run(s, opts)
    local done, err, result = false, nil, nil
    gt.translate(s, opts, function(e, r)
      done, err, result = true, e, r
    end)
    assert.is_true(vim.wait(1000, function()
      return done
    end))
    return err, result
  end

  before_each(function()
    calls = {}
    client.request = fake_request
  end)

  after_each(function()
    client.request = original_request
    text.CHUNK_LIMIT = 4500
    config.setup()
  end)

  it("restores the whitespace the API strips", function()
    local err, result = run("\n  hello\nworld  \n", { target = "ja" })
    assert.is_nil(err)
    assert.are.same({ text = "\n  HELLO\nWORLD  \n", source = "en" }, result)
    assert.are.same({ { body = "hello\nworld", source = "auto", target = "ja" } }, calls)
  end)

  it("uses the configured target by default", function()
    config.setup({ target = "de" })
    run("hi")
    assert.are.equal("de", calls[1].target)
  end)

  it("translates chunks one at a time, keeping indentation at chunk boundaries", function()
    text.CHUNK_LIMIT = 5
    local in_flight, max_in_flight = 0, 0
    client.request = function(body, source, target, callback)
      in_flight = in_flight + 1
      max_in_flight = math.max(max_in_flight, in_flight)
      fake_request(body, source, target, function(...)
        in_flight = in_flight - 1
        callback(...)
      end)
    end
    local _, result = run("aaa\nbbb\n\n  ccc", { target = "ja" })
    assert.are.same({ text = "AAA\nBBB\n\n  CCC", source = "en" }, result)
    assert.are.same(
      { "aaa", "bbb", "ccc" },
      vim.tbl_map(function(c)
        return c.body
      end, calls)
    )
    assert.are.equal(1, max_in_flight)
  end)

  it("skips requests for whitespace-only chunks", function()
    text.CHUNK_LIMIT = 3
    local _, result = run("aa\n\n\n\nbb", { target = "ja" })
    assert.are.same({ text = "AA\n\n\n\nBB", source = "en" }, result)
    assert.are.equal(2, #calls)
  end)

  it("does not send a request for whitespace-only text", function()
    local err, result = run("  \n ", { target = "ja" })
    assert.is_nil(err)
    assert.are.same({ text = "  \n ", source = "auto" }, result)
    assert.are.equal(0, #calls)
  end)

  it("stops at the first error", function()
    text.CHUNK_LIMIT = 3
    client.request = function(body, _, _, callback)
      table.insert(calls, { body = body })
      vim.schedule(function()
        callback("boom")
      end)
    end
    local err, result = run("aaa\nbbb", { target = "ja" })
    assert.are.equal("boom", err)
    assert.is_nil(result)
    assert.are.equal(1, #calls)
  end)

  it("rejects unknown languages without sending a request", function()
    assert.are.equal("google-translate: unknown target language: xx", run("hi", { target = "xx" }))
    assert.are.equal(
      "google-translate: unknown source language: yy",
      run("hi", { source = "yy", target = "ja" })
    )
    assert.are.equal(0, #calls)
  end)

  it("never calls back synchronously", function()
    local called = false
    gt.translate("hi", { target = "xx" }, function()
      called = true
    end)
    assert.is_false(called)
    vim.wait(1000, function()
      return called
    end)
  end)
end)
