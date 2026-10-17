local M = {}

function M.check()
  vim.health.start("google-translate")

  if vim.fn.has("nvim-0.11") == 1 then
    vim.health.ok("Neovim " .. tostring(vim.version()))
  else
    vim.health.error("Neovim 0.11 or later is required")
  end

  if vim.fn.executable("curl") == 1 then
    local version = vim.system({ "curl", "--version" }, { text = true }):wait().stdout or ""
    vim.health.ok(vim.split(version, "\n", { plain = true })[1])
  else
    vim.health.error("curl not found", { "Install curl and make sure it is in $PATH" })
  end
end

return M
