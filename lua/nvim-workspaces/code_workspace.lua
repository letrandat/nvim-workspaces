-- lua/nvim-workspaces/code_workspace.lua
local M = {}

---Find a .code-workspace file by searching upward from a directory
---@param start_dir string|nil Starting directory (defaults to cwd)
---@return string|nil path Path to the .code-workspace file, or nil if not found
function M.find_workspace_file(start_dir)
  start_dir = start_dir or vim.fn.getcwd()

  local files = vim.fs.find(function(name)
    return vim.fn.fnamemodify(name, ":e") == "code-workspace"
  end, { upward = true, path = start_dir })

  return files[1]
end

local jsonc = require("nvim-workspaces.jsonc")

---Load folders from a .code-workspace file
---@param file_path string Path to the .code-workspace file
---@return string[] folders List of resolved folder paths
function M.load_workspace_file(file_path)
  local content = vim.fn.readfile(file_path)
  local data, err = jsonc.decode(table.concat(content, "\n"))

  if not data then
    vim.notify("[nvim-workspaces] Failed to parse workspace file: " .. (err or "unknown error"), vim.log.levels.ERROR)
    return {}
  end

  if not data.folders then
    return {}
  end

  local base_dir = vim.fs.dirname(file_path)
  local folders = {}

  for _, folder in ipairs(data.folders) do
    local path = folder.path
    -- Resolve relative paths
    if not vim.startswith(path, "/") then
      path = vim.fs.joinpath(base_dir, path)
    end
    -- Normalize
    local real_path = vim.loop.fs_realpath(path)
    if real_path and vim.fn.isdirectory(real_path) == 1 then
      table.insert(folders, real_path)
    end
  end

  return folders
end

---Write folders to a .code-workspace file
---@param file_path string Path to the .code-workspace file
---@param folders string[] List of absolute folder paths
---@return boolean success
function M.write_workspace_file(file_path, folders)
  local base_dir = vim.fs.dirname(file_path)
  local data = { folders = {} }

  for _, folder in ipairs(folders) do
    local path_Obj = {}
    -- Try to make relative
    local relative = vim.fs.normalize(folder)
    local base = vim.fs.normalize(base_dir)

    -- simple check if folder is inside base or nice relative
    -- for robust relative path, we can use a helper or just check prefix
    if vim.startswith(relative, base .. "/") then
       path_Obj.path = relative:sub(#base + 2)
    else
        -- Fallback to absolute if not child
        -- OR TODO: calculate ../ relative path safely?
        -- For now, let's stick to absolute if not simple child, or use absolute
        path_Obj.path = folder
    end

    table.insert(data.folders, path_Obj)
  end

  local json = vim.json.encode(data)
  local ok, err = pcall(vim.fn.writefile, { json }, file_path)

  if not ok then
      vim.notify("[nvim-workspaces] Failed to write workspace file: " .. (err or "unknown"), vim.log.levels.ERROR)
      return false
  end
  return true
end

return M
