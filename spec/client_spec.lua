local client = require("google-translate.client")

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
    }, client.build_cmd("en", "ja"))
  end)
end)

describe("client.parse", function()
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
      client.parse(body .. "\n200")
    )
  end)

  it("falls back to auto when the language is missing", function()
    local body = vim.json.encode({ sentences = { { trans = "x" } } })
    assert.are.same({ text = "x", source = "auto" }, client.parse(body .. "\n200"))
  end)

  it("reports rate limiting", function()
    assert.are.same(
      { nil, "google-translate: rate limited by Google (HTTP 429)" },
      { client.parse("<html></html>\n429") }
    )
    assert.are.same(
      { nil, "google-translate: rate limited by Google (HTTP 503)" },
      { client.parse("<html></html>\n503") }
    )
  end)

  it("reports other HTTP errors", function()
    assert.are.same(
      { nil, "google-translate: request failed (HTTP 400)" },
      { client.parse("<html>bad</html>\n400") }
    )
  end)

  it("treats an HTML page with status 200 as a failure", function()
    assert.are.same(
      { nil, "google-translate: unexpected response" },
      { client.parse("<html>unusual traffic</html>\n200") }
    )
  end)

  it("rejects output without sentences or a status", function()
    assert.are.same({ nil, "google-translate: unexpected response" }, { client.parse("{}\n200") })
    assert.are.same({ nil, "google-translate: unexpected response" }, { client.parse("") })
  end)
end)
