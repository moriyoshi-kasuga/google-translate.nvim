local cache = require("google-translate.cache")
local client = require("google-translate.client")
local config = require("google-translate.config")
local languages = require("google-translate.languages")
local text = require("google-translate.text")

local M = {}

---@class google_translate.TranslateOpts
---@field source? string Defaults to "auto"
---@field target? string Defaults to the configured target

---@param opts? google_translate.UserConfig
function M.setup(opts)
  config.setup(opts)
end

---Translates `s`, splitting long text into sequential requests and keeping the
---whitespace that the API strips. Chunks found in the cache send no request.
---`callback` always runs later on the main loop.
---@param s string
---@param opts? google_translate.TranslateOpts
---@param callback fun(err: string?, result: google_translate.Result?)
function M.translate(s, opts, callback)
  opts = opts or {}
  local source = opts.source or "auto"
  local target = opts.target or config.options.target
  callback = vim.schedule_wrap(callback)

  -- Google answers unknown codes with the untranslated text, so check them here.
  if not vim.list_contains(languages.source, source) then
    callback("google-translate: unknown source language: " .. source)
    return
  end
  if not vim.list_contains(languages.target, target) then
    callback("google-translate: unknown target language: " .. target)
    return
  end

  local chunks = text.chunk(s, text.CHUNK_LIMIT)
  local results = {} ---@type string[]
  local detected ---@type string?

  ---@param i integer
  local function translate_chunk(i)
    if i > #chunks then
      callback(nil, { text = table.concat(results, "\n"), source = detected or source })
      return
    end
    local leading, body, trailing = text.split_padding(chunks[i])
    if body == "" then
      results[i] = chunks[i]
      translate_chunk(i + 1)
      return
    end

    ---@param result google_translate.Result
    local function apply(result)
      results[i] = leading .. result.text .. trailing
      detected = detected or result.source
      translate_chunk(i + 1)
    end

    local cached = cache.get(source, target, body)
    if cached then
      apply(cached)
      return
    end
    client.request(body, source, target, function(err, result)
      if not result then
        callback(err)
        return
      end
      cache.set(source, target, body, result)
      apply(result)
    end)
  end
  translate_chunk(1)
end

return M
