local client = require("google-translate.client")

local M = {}

---Translates a short text with `endpoint` alone.
---@param endpoint google_translate.Endpoint
---@return string? error Without the plugin name
local function probe(endpoint)
  local cmd = client.build_cmd(endpoint, "en", "ja")
  local out = vim.system(cmd, { stdin = "Hello", text = true }):wait()
  local err
  if out.code ~= 0 then
    err = "curl failed: " .. vim.trim(out.stderr or "")
  else
    _, err = client.parse(endpoint, out.stdout or "", "en")
  end
  return err and (err:gsub("^google%-translate: ", ""))
end

function M.check()
  vim.health.start("google-translate")

  if vim.fn.has("nvim-0.11") == 1 then
    vim.health.ok("Neovim " .. tostring(vim.version()))
  else
    vim.health.error("Neovim 0.11 or later is required")
  end

  if vim.fn.executable("curl") == 0 then
    vim.health.error("curl not found", { "Install curl and make sure it is in $PATH" })
    return
  end
  local version = vim.system({ "curl", "--version" }, { text = true }):wait().stdout or ""
  vim.health.ok(vim.split(version, "\n", { plain = true })[1])

  -- Each endpoint gets one request, so that a rate limit shows up here.
  vim.health.start("Endpoints")
  local available = false
  for _, endpoint in ipairs(client.ENDPOINTS) do
    local err = probe(endpoint)
    if err then
      vim.health.warn(("%s: %s"):format(endpoint.name, err))
    else
      available = true
      vim.health.ok(endpoint.name)
    end
  end
  if not available then
    vim.health.error("No endpoint translates")
  end
end

return M
