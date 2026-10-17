---@diagnostic disable: duplicate-set-field

local client = require("google-translate.client")
local health = require("google-translate.health")

describe("health.check", function()
  local original_system = vim.system
  local original_health = vim.health
  local reports ---@type string[][] `{ kind, message }`

  local RATE_LIMITED = { code = 0, stdout = "<html></html>\n429", stderr = "" }
  local TRANSLATED = {
    code = 0,
    stdout = vim.json.encode({ sentences = { { trans = "こんにちは" } }, src = "en" })
      .. "\n200",
    stderr = "",
  }

  ---Answers `curl --version` and the request to each endpoint.
  ---@param outputs table<string, table> Keyed by endpoint name
  local function stub(outputs)
    vim.system = function(cmd)
      local out = { code = 0, stdout = "curl 8.0.0\n", stderr = "" }
      for _, e in ipairs(client.ENDPOINTS) do
        if vim.startswith(cmd[#cmd], e.url .. "&") then
          out = outputs[e.name]
        end
      end
      return {
        wait = function()
          return out
        end,
      }
    end
  end

  ---@return string[][] The reports after the endpoint section starts
  local function endpoint_reports()
    health.check()
    for i, report in ipairs(reports) do
      if report[1] == "start" and report[2] == "Endpoints" then
        return vim.list_slice(reports, i + 1)
      end
    end
    error("no endpoint section")
  end

  before_each(function()
    reports = {}
    local function recorder(kind)
      return function(message)
        table.insert(reports, { kind, message })
      end
    end
    vim.health = {
      start = recorder("start"),
      ok = recorder("ok"),
      warn = recorder("warn"),
      error = recorder("error"),
      info = recorder("info"),
    }
  end)

  after_each(function()
    vim.system = original_system
    vim.health = original_health
  end)

  it("reports whether each endpoint translates", function()
    stub({
      ["single/gtx"] = RATE_LIMITED,
      ["single/dict-chrome-ex"] = TRANSLATED,
      ["t/gtx"] = { code = 6, stdout = "", stderr = "curl: (6) Could not resolve host\n" },
    })
    assert.are.same({
      { "warn", "single/gtx: rate limited by Google (HTTP 429)" },
      { "ok", "single/dict-chrome-ex" },
      { "warn", "t/gtx: curl failed: curl: (6) Could not resolve host" },
    }, endpoint_reports())
  end)

  it("reports an error when no endpoint translates", function()
    stub({
      ["single/gtx"] = RATE_LIMITED,
      ["single/dict-chrome-ex"] = RATE_LIMITED,
      ["t/gtx"] = RATE_LIMITED,
    })
    local last = endpoint_reports()[4]
    assert.are.same({ "error", "No endpoint translates" }, last)
  end)
end)
