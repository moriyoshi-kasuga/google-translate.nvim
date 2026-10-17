local M = {}

M.ENDPOINT = "https://translate.googleapis.com/translate_a/single"

---Request timeout in seconds.
M.TIMEOUT = 10

---@class google_translate.Result
---@field text string
---@field source string Detected language, or "auto" when the response has none

local UNEXPECTED = "google-translate: unexpected response"

---@param source string
---@param target string
---@return string[]
function M.build_cmd(source, target)
  return {
    "curl",
    "--silent",
    "--show-error",
    "--max-time",
    tostring(M.TIMEOUT),
    -- The status tells error pages apart from translations.
    "--write-out",
    "\n%{http_code}",
    -- Reading the text from stdin avoids argument and URL length limits.
    "--data-urlencode",
    "q@-",
    ("%s?client=gtx&dt=t&dj=1&sl=%s&tl=%s"):format(M.ENDPOINT, source, target),
  }
end

---Parses the output of the command from `build_cmd`: the body, a newline and the HTTP status.
---@param stdout string
---@return google_translate.Result?
---@return string? error
function M.parse(stdout)
  local body, status = stdout:match("^(.*)\n(%d%d%d)$")
  if not body then
    return nil, UNEXPECTED
  end
  if status == "429" or status == "503" then
    return nil, ("google-translate: rate limited by Google (HTTP %s)"):format(status)
  end
  if status ~= "200" then
    return nil, ("google-translate: request failed (HTTP %s)"):format(status)
  end

  local ok, response = pcall(vim.json.decode, body)
  if not ok or type(response) ~= "table" or type(response.sentences) ~= "table" then
    return nil, UNEXPECTED
  end
  local parts = {}
  for _, sentence in ipairs(response.sentences) do
    -- Entries without `trans` carry transliterations.
    if type(sentence) == "table" and type(sentence.trans) == "string" then
      table.insert(parts, sentence.trans)
    end
  end
  return {
    text = table.concat(parts),
    source = type(response.src) == "string" and response.src or "auto",
  }
end

---Translates `text` with one request. `callback` runs on the main loop.
---@param text string
---@param source string
---@param target string
---@param callback fun(err: string?, result: google_translate.Result?)
function M.request(text, source, target, callback)
  callback = vim.schedule_wrap(callback)
  if vim.fn.executable("curl") == 0 then
    callback("google-translate: curl not found")
    return
  end
  vim.system(M.build_cmd(source, target), { stdin = text, text = true }, function(out)
    if out.code ~= 0 then
      callback("google-translate: curl failed: " .. vim.trim(out.stderr or ""))
      return
    end
    local result, err = M.parse(out.stdout or "")
    callback(err, result)
  end)
end

return M
