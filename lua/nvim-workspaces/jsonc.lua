---@class nvim-workspaces.jsonc
local M = {}

---Strip JSONC comments (// and /* */) from a string
---@param str string The JSONC string
---@return string The JSON string without comments
function M.strip_comments(str)
  -- Remove block comments (/* ... */)
  str = str:gsub("/%*.-%*/", "")
  -- Remove single-line comments (// ...)
  str = str:gsub("//[^\n]*", "")
  return str
end

return M