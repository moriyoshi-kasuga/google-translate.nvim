# google-translate.nvim

Translate text in Neovim with the free Google Translate web endpoints. No API key is needed.
Replace the text with its translation, or read the translation in a floating window.

## Requirements

- Neovim 0.11 or later
- curl

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "moriyoshi-kasuga/google-translate.nvim" }
```

`vim.pack` (Neovim 0.12):

```lua
vim.pack.add({ "https://github.com/moriyoshi-kasuga/google-translate.nvim" })
```

Calling `setup()` is optional.

## Usage

```
:[range]Translate [{target}] [--source={source}] [--float]
```

- `{target}`: the language to translate into. Defaults to the `target` option (`"en"`).
- `--source={source}`: the language of the text. Defaults to `auto`, which lets Google detect it.
- `--float`: show the translation in a floating window instead of replacing the text.

Arguments may appear in any order, and language codes complete with `<Tab>`.

Without a range, the current line is translated.
From Visual mode (`:'<,'>`), a characterwise selection translates only the selected characters.
Blockwise selections are not supported.

```vim
:Translate ja
:'<,'>Translate ja --float
:%Translate en --source=ja
```

Replacement runs in the background and a single `u` undoes it.
If you edit the buffer before the translation arrives, nothing is replaced.

The floating window takes the focus and closes with `q` or when you leave it.

The plugin defines no mappings. For example:

```lua
vim.keymap.set("x", "<leader>tr", ":Translate ja<CR>")
vim.keymap.set("x", "<leader>tf", ":Translate ja --float<CR>")
```

## Configuration

The defaults:

```lua
require("google-translate").setup({
  -- Language used when :Translate is run without a target.
  target = "en",
  float = {
    -- Maximum size: a ratio of the editor when 1 or less, otherwise rows or columns.
    -- The window shrinks to fit the translation.
    height = 0.85,
    width = 0.75,
    -- Border as in nvim_open_win(). Uses 'winborder' when nil.
    border = nil,
  },
})
```

Each call starts from the defaults. Unknown keys and invalid values raise an error.

## Lua API

```lua
local gt = require("google-translate")
gt.translate("Hello", { source = "auto", target = "ja" }, function(err, result)
  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  print(result.text) -- the translation
  print(result.source) -- the detected language
end)
```

The callback runs on the main loop.
Leading and trailing whitespace is kept, and text longer than about 4500 characters is sent in several requests.
The results of the last 100 requests are kept in memory, so translating the same text into the same language again sends no request.

## Health

```vim
:checkhealth google-translate
```

This sends a short request to each endpoint and shows which ones translate.

## Limitations

- The endpoints are unofficial and undocumented. Google may change or block them at any time.
- Google rate limits heavy use, separately for each endpoint.
  When an endpoint is rate limited or answers with an error, the plugin tries the next one and keeps using the one that answers.
  When every endpoint fails, the error of the first one is shown, and HTTP 429 and 503 are reported as "rate limited".
  The limit usually lifts after some hours.
- Each line break ends a sentence. Text wrapped over several lines, such as a comment block, is translated line by line.
- The detected source language is sometimes wrong.

## License

[MIT](LICENSE)
