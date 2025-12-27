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

---Decode a JSONC string to a Lua table
---@param str string The JSONC string
---@return table|nil result The decoded table, or nil on error
---@return string|nil error The error message, or nil on success
function M.decode(str)
  local json_str = M.strip_comments(str)
  local ok, result = pcall(vim.json.decode, json_str)
  if ok then
    return result, nil
  else
    return nil, result
  end
end

return M