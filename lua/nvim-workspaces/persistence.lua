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
    updated = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }

  local json = vim.json.encode(data)
  vim.fn.writefile({ json }, file)
end

---Load current workspace state from _current.json
---@return string[] folders List of valid folder paths
function M.load_current()
  local dir = ensure_data_dir()
  local file = dir .. "/_current.json"

  if vim.fn.filereadable(file) == 0 then
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

---Save current workspace with a name
---@param name string The workspace name
function M.save(name)
  local dir = ensure_data_dir()
  local file = dir .. "/" .. name .. ".json"
  local workspaces = get_workspaces()

  local data = {
    folders = workspaces.state.folders,
    created = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }

  local json = vim.json.encode(data)
  vim.fn.writefile({ json }, file)
  vim.notify("[nvim-workspaces] Saved workspace: " .. name, vim.log.levels.INFO)
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

return M
