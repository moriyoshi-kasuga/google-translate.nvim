---@diagnostic disable: duplicate-set-field

local client = require("google-translate.client")

---@param name string
---@return google_translate.Endpoint
local function endpoint(name)
  for _, e in ipairs(client.ENDPOINTS) do
    if e.name == name then
      return e
    end
  end
  error("no endpoint named " .. name)
end

describe("client.build_cmd", function()
  it("posts the text from stdin and appends the HTTP status", function()
    assert.are.same({
      "curl",
      "--silent",
      "--show-error",
      "--max-time",
      "10",
      "--write-out",
      "\n%{http_code}",
      "--data-urlencode",
      "q@-",
      "https://translate.googleapis.com/translate_a/single?client=gtx&dt=t&dj=1&sl=en&tl=ja",
    }, client.build_cmd(endpoint("single/gtx"), "en", "ja"))
  end)
end)

describe("client.parse", function()
  local single = endpoint("single/gtx")
  local t = endpoint("t/gtx")

  it("joins the translated sentences and reports the detected language", function()
    local body = vim.json.encode({
      sentences = {
        { trans = "1行目。\n", orig = "line one.\n" },
        { trans = "2行目。", orig = "line two." },
        { translit = "ichigyoume" },
      },
      src = "en",
    })
    assert.are.same(
      { text = "1行目。\n2行目。", source = "en" },
      client.parse(single, body .. "\n200", "auto")
    )
  end)

  it("falls back to the requested source when the language is missing", function()
    local body = vim.json.encode({ sentences = { { trans = "x" } } })
    assert.are.same({ text = "x", source = "de" }, client.parse(single, body .. "\n200", "de"))
  end)

  it("reads the translation and the detected language from translate_a/t", function()
    assert.are.same(
      { text = "1行目。\n  2行目。", source = "en" },
      client.parse(t, '[["1行目。\\n  2行目。","en"]]\n200', "auto")
    )
  end)

  it("reads translate_a/t without a detected language", function()
    assert.are.same({ text = "訳", source = "en" }, client.parse(t, '["訳"]\n200', "en"))
  end)

  it("reports rate limiting", function()
    assert.are.same(
      { nil, "google-translate: rate limited by Google (HTTP 429)" },
      { client.parse(single, "<html></html>\n429", "auto") }
    )
    assert.are.same(
      { nil, "google-translate: rate limited by Google (HTTP 503)" },
      { client.parse(single, "<html></html>\n503", "auto") }
    )
  end)

  it("reports other HTTP errors", function()
    assert.are.same(
      { nil, "google-translate: request failed (HTTP 400)" },
      { client.parse(single, "<html>bad</html>\n400", "auto") }
    )
  end)

  it("treats an HTML page with status 200 as a failure", function()
    assert.are.same(
      { nil, "google-translate: unexpected response" },
      { client.parse(single, "<html>unusual traffic</html>\n200", "auto") }
    )
  end)

  it("rejects output without a translation or a status", function()
    local unexpected = { nil, "google-translate: unexpected response" }
    assert.are.same(unexpected, { client.parse(single, "{}\n200", "auto") })
    assert.are.same(unexpected, { client.parse(single, "", "auto") })
    assert.are.same(unexpected, { client.parse(t, "{}\n200", "auto") })
    assert.are.same(unexpected, { client.parse(t, "[]\n200", "auto") })
  end)
end)

describe("client.request", function()
  local original_system = vim.system
  local original_preferred = client.preferred
  local requested ---@type string[] Names of the endpoints, in request order

  local RATE_LIMITED = { code = 0, stdout = "<html></html>\n429", stderr = "" }

  ---@param s string
  local function translated(s)
    local body = vim.json.encode({ sentences = { { trans = s } }, src = "en" })
    return { code = 0, stdout = body .. "\n200", stderr = "" }
  end

  ---Answers each request with the output for its endpoint.
  ---@param outputs table<string, table> Keyed by endpoint name
  local function stub(outputs)
    vim.system = function(cmd, _, on_exit)
      local url = cmd[#cmd]
      for _, e in ipairs(client.ENDPOINTS) do
        if vim.startswith(url, e.url .. "&") then
          table.insert(requested, e.name)
          local out = assert(outputs[e.name], "unexpected request to " .. e.name)
          vim.schedule(function()
            on_exit(out)
          end)
          return {}
        end
      end
      error("unexpected command: " .. table.concat(cmd, " "))
    end
  end

  local function request()
    local done, err, result = false, nil, nil
    client.request("Hello", "auto", "ja", function(e, r)
      done, err, result = true, e, r
    end)
    assert.is_true(vim.wait(1000, function()
      return done
    end))
    return err, result
  end

  before_each(function()
    requested = {}
    client.preferred = 1
  end)

  after_each(function()
    vim.system = original_system
    client.preferred = original_preferred
  end)

  it("falls back to the next endpoint when one is rate limited", function()
    stub({
      ["single/gtx"] = RATE_LIMITED,
      ["single/dict-chrome-ex"] = translated("こんにちは"),
    })
    local err, result = request()
    assert.is_nil(err)
    assert.are.same({ text = "こんにちは", source = "en" }, result)
    assert.are.same({ "single/gtx", "single/dict-chrome-ex" }, requested)
  end)

  it("starts with the endpoint that answered last", function()
    stub({
      ["single/gtx"] = RATE_LIMITED,
      ["single/dict-chrome-ex"] = translated("こんにちは"),
    })
    request()
    request()
    assert.are.same({ "single/gtx", "single/dict-chrome-ex", "single/dict-chrome-ex" }, requested)
  end)

  it("wraps around to the endpoints before the one it starts with", function()
    client.preferred = 2
    stub({
      ["single/gtx"] = translated("こんにちは"),
      ["single/dict-chrome-ex"] = RATE_LIMITED,
      ["t/gtx"] = RATE_LIMITED,
    })
    local err = request()
    assert.is_nil(err)
    assert.are.same({ "single/dict-chrome-ex", "t/gtx", "single/gtx" }, requested)
    assert.are.equal(1, client.preferred)
  end)

  it("reports the error of the first endpoint when every endpoint fails", function()
    stub({
      ["single/gtx"] = RATE_LIMITED,
      ["single/dict-chrome-ex"] = { code = 0, stdout = "<html></html>\n500", stderr = "" },
      ["t/gtx"] = { code = 0, stdout = "{}\n200", stderr = "" },
    })
    local err, result = request()
    assert.are.equal("google-translate: rate limited by Google (HTTP 429)", err)
    assert.is_nil(result)
    assert.are.same({ "single/gtx", "single/dict-chrome-ex", "t/gtx" }, requested)
  end)

  it("does not fall back when curl fails", function()
    stub({
      ["single/gtx"] = { code = 6, stdout = "", stderr = "curl: (6) Could not resolve host\n" },
    })
    local err = request()
    assert.are.equal("google-translate: curl failed: curl: (6) Could not resolve host", err)
    assert.are.same({ "single/gtx" }, requested)
  end)
end)
