if vim.g.loaded_google_translate then
  return
end
vim.g.loaded_google_translate = true

if vim.fn.has("nvim-0.11") == 0 then
  vim.notify("google-translate: Neovim 0.11 or later is required", vim.log.levels.ERROR)
  return
end

vim.api.nvim_create_user_command("Translate", function(cmd)
  require("google-translate.command").run(cmd)
end, {
  nargs = "*",
  range = true,
  complete = function(...)
    return require("google-translate.command").complete(...)
  end,
  desc = "Translate text with Google Translate",
})
