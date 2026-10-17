local M = {}

---Request timeout in seconds.
M.TIMEOUT = 10

---@class google_translate.Result
---@field text string
---@field source string Detected language, or the requested one when the response has none

---@class google_translate.Endpoint
---@field name string
---@field url string Query parameters other than the languages included
---@field decode fun(response: any): text: string?, detected: string?

local UNEXPECTED = "google-translate: unexpected response"

---@param response any
---@return string? text
---@return string? detected
local function decode_single(response)
  if type(response) ~= "table" or type(response.sentences) ~= "table" then
    return nil
  end
  local parts = {}
  for _, sentence in ipairs(response.sentences) do
    -- Entries without `trans` carry transliterations.
    if type(sentence) == "table" and type(sentence.trans) == "string" then
      table.insert(parts, sentence.trans)
    end
  end
  return table.concat(parts), type(response.src) == "string" and response.src or nil
end

---@param response any
---@return string? text
---@return string? detected
local function decode_t(response)
  -- `[[translation, detected]]` with sl=auto, otherwise `[translation]`.
  local first = type(response) == "table" and response[1] or nil
  if type(first) == "string" then
    return first
  end
  if type(first) == "table" and type(first[1]) == "string" then
    return first[1], type(first[2]) == "string" and first[2] or nil
  end
  return nil
end

---Tried in order. Google rate limits each endpoint and client separately,
---so another one often works while one is blocked.
---@type google_translate.Endpoint[]
M.ENDPOINTS = {
  {
    name = "single/gtx",
    url = "https://translate.googleapis.com/translate_a/single?client=gtx&dt=t&dj=1",
    decode = decode_single,
  },
  {
    name = "single/dict-chrome-ex",
    url = "https://translate.googleapis.com/translate_a/single?client=dict-chrome-ex&dt=t&dj=1",
    decode = decode_single,
  },
  {
    name = "t/gtx",
    url = "https://translate.googleapis.com/translate_a/t?client=gtx",
    decode = decode_t,
  },
}

---Index in `ENDPOINTS` of the endpoint tried first: the last one that answered.
M.preferred = 1

---@param endpoint google_translate.Endpoint
---@param source string
---@param target string
---@return string[]
function M.build_cmd(endpoint, source, target)
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
    ("%s&sl=%s&tl=%s"):format(endpoint.url, source, target),
  }
end

---Parses the output of the command from `build_cmd`: the body, a newline and the HTTP status.
---@param endpoint google_translate.Endpoint
---@param stdout string
---@param source string The requested source language
---@return google_translate.Result?
---@return string? error
function M.parse(endpoint, stdout, source)
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
  if not ok then
    return nil, UNEXPECTED
  end
  local text, detected = endpoint.decode(response)
  if not text then
    return nil, UNEXPECTED
  end
  return { text = text, source = detected or source }
end

---Translates `text` with one request, trying the next endpoint while one fails.
---A curl failure ends the attempts, as the other endpoints share the network.
---`callback` runs on the main loop and gets the error of the first endpoint tried.
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

  local first_err ---@type string?

  ---@param attempt integer
  local function try(attempt)
    if attempt > #M.ENDPOINTS then
      callback(first_err)
      return
    end
    local index = (M.preferred + attempt - 2) % #M.ENDPOINTS + 1
    local endpoint = M.ENDPOINTS[index]
    -- On the main loop, so that the next attempt may call vim.fn.
    local on_exit = vim.schedule_wrap(function(out)
      if out.code ~= 0 then
        callback("google-translate: curl failed: " .. vim.trim(out.stderr or ""))
        return
      end
      local result, err = M.parse(endpoint, out.stdout or "", source)
      if result then
        M.preferred = index
        callback(nil, result)
        return
      end
      first_err = first_err or err
      try(attempt + 1)
    end)
    vim.system(M.build_cmd(endpoint, source, target), { stdin = text, text = true }, on_exit)
  end
  try(1)
end

return M
