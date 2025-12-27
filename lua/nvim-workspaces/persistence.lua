-- lua/nvim-workspaces/persistence.lua
local M = {}

---Get the main module (lazy require to avoid circular deps)
---@return nvim-workspaces
local function get_workspaces()
  return require("nvim-workspaces")
end

---Ensure data directory exists
local function ensure_data_dir()
  local dir = get_workspaces().config.data_dir
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return dir
end

---Save current workspace state to _current.json
function M.save_current()
  local dir = ensure_data_dir()
  local file = dir .. "/_current.json"
  local workspaces = get_workspaces()

  local data = {
    folders = workspaces.state.folders,
    name = workspaces.state.name,
    updated = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }

  local json = vim.json.encode(data)
  vim.fn.writefile({ json }, file)
end

---Load current workspace state from _current.json
---@return string[] folders List of valid folder paths
---@return string|nil name The workspace name
function M.load_current()
  local dir = ensure_data_dir()
  local file = dir .. "/_current.json"

  if vim.fn.filereadable(file) == 0 then
    return {}, nil
  end

  local content = vim.fn.readfile(file)
  local ok, data = pcall(vim.json.decode, table.concat(content, "\n"))

  if not ok or not data or not data.folders then
    return {}, nil
  end

  -- Filter out non-existent directories
  local valid = {}
  for _, folder in ipairs(data.folders) do
    if vim.fn.isdirectory(folder) == 1 then
      table.insert(valid, folder)
    end
  end

  return valid, data.name
end

---Save current workspace with a name
---@param name string The workspace name
---@param silent? boolean Whether to suppress notification
function M.save(name, silent)
  local dir = ensure_data_dir()
  local file = dir .. "/" .. name .. ".json"
  local workspaces = get_workspaces()

  local data = {
    folders = workspaces.state.folders,
    created = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }

  local json = vim.json.encode(data)
  vim.fn.writefile({ json }, file)
  if not silent then
    vim.notify("[nvim-workspaces] Saved workspace: " .. name, vim.log.levels.INFO)
  end
end

---Load a named workspace
---@param name string The workspace name
---@return string[] folders List of valid folder paths
function M.load(name)
  local dir = get_workspaces().config.data_dir
  local file = dir .. "/" .. name .. ".json"

  if vim.fn.filereadable(file) == 0 then
    vim.notify("[nvim-workspaces] Workspace not found: " .. name, vim.log.levels.ERROR)
    return {}
  end

  local content = vim.fn.readfile(file)
  local ok, data = pcall(vim.json.decode, table.concat(content, "\n"))

  if not ok or not data or not data.folders then
    return {}
  end

  -- Filter out non-existent directories
  local valid = {}
  for _, folder in ipairs(data.folders) do
    if vim.fn.isdirectory(folder) == 1 then
      table.insert(valid, folder)
    end
  end

  return valid
end

---Delete a named workspace
---@param name string The workspace name
function M.delete(name)
  local dir = get_workspaces().config.data_dir
  local file = dir .. "/" .. name .. ".json"

  if vim.fn.filereadable(file) == 1 then
    vim.fn.delete(file)
    vim.notify("[nvim-workspaces] Deleted workspace: " .. name, vim.log.levels.INFO)
  else
    vim.notify("[nvim-workspaces] Workspace not found: " .. name, vim.log.levels.WARN)
  end
end

---List all saved workspace names
---@return string[] names List of workspace names
function M.list_saved()
  local dir = get_workspaces().config.data_dir

  if vim.fn.isdirectory(dir) == 0 then
    return {}
  end

  local files = vim.fn.glob(dir .. "/*.json", false, true)
  local names = {}

  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    -- Exclude _current
    if name ~= "_current" then
      table.insert(names, name)
    end
  end

  return names
end

---Rename a saved workspace
---@param old_name string The current workspace name
---@param new_name string The new workspace name
---@return boolean success Whether the rename was successful
function M.rename(old_name, new_name)
  local dir = get_workspaces().config.data_dir
  local old_file = dir .. "/" .. old_name .. ".json"
  local new_file = dir .. "/" .. new_name .. ".json"

  if vim.fn.filereadable(old_file) == 0 then
    vim.notify("[nvim-workspaces] Workspace not found: " .. old_name, vim.log.levels.ERROR)
    return false
  end

  if vim.fn.filereadable(new_file) == 1 then
    vim.notify("[nvim-workspaces] Workspace already exists: " .. new_name, vim.log.levels.ERROR)
    return false
  end

  local success = vim.fn.rename(old_file, new_file)
  if success == 0 then
    vim.notify("[nvim-workspaces] Renamed workspace: " .. old_name .. " -> " .. new_name, vim.log.levels.INFO)
    return true
  else
    vim.notify("[nvim-workspaces] Failed to rename workspace", vim.log.levels.ERROR)
    return false
  end
end

---Get the path to a workspace file
---@param name string|nil The workspace name (nil for _current)
---@return string path The absolute path to the workspace file
function M.path(name)
  local dir = ensure_data_dir()
  if not name then
      return dir .. "/_current.json"
  end
  return dir .. "/" .. name .. ".json"
end

return M
