local M = {}

---Maximum number of characters sent in one request.
M.CHUNK_LIMIT = 4500

---Splits `s` into the whitespace around it and the body in between.
---The API strips that whitespace, so callers restore it around the translation.
---@param s string
---@return string leading
---@return string body
---@return string trailing
function M.split_padding(s)
  return s:match("^(%s*)(.-)(%s*)$")
end

---Splits `s` at line boundaries into chunks of at most `limit` characters.
---A line longer than `limit` becomes a chunk of its own.
---Joining the chunks with "\n" restores `s`.
---@param s string
---@param limit integer
---@return string[]
function M.chunk(s, limit)
  local chunks = {}
  local lines, size = {}, 0
  for _, line in ipairs(vim.split(s, "\n", { plain = true })) do
    local width = vim.fn.strchars(line)
    if #lines > 0 and size + 1 + width > limit then
      table.insert(chunks, table.concat(lines, "\n"))
      lines, size = {}, 0
    end
    if #lines > 0 then
      size = size + 1
    end
    table.insert(lines, line)
    size = size + width
  end
  table.insert(chunks, table.concat(lines, "\n"))
  return chunks
end

return M
