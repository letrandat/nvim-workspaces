---@class nvim-workspaces.Config
---@field auto_restore? boolean Auto-restore last session's workspace on startup
---@field auto_load_code_workspace? boolean Auto-load .code-workspace file if found
---@field sync_to_code_workspace? boolean Sync changes back to .code-workspace file
---@field data_dir? string Directory for persistence
---@field picker_cwd? string Default directory for Telescope picker
---@field enable_keymaps? boolean Enable default keymaps

---@class nvim-workspaces.State
---@field folders string[] Currently active workspace folders
---@field name string|nil Current workspace name
---@field code_workspace_path string|nil Path to the loaded .code-workspace file

---@class nvim-workspaces
---@field config nvim-workspaces.Config
---@field state nvim-workspaces.State
local M = {}

---@type nvim-workspaces.Config
M.config = {
  auto_restore = true,
  auto_load_code_workspace = true,
  sync_to_code_workspace = false,
  data_dir = vim.fn.stdpath("data") .. "/nvim-workspaces",
  picker_cwd = vim.fn.expand("~/workspace"),
  enable_keymaps = true,
}

---@type nvim-workspaces.State
M.state = {
  folders = {},
  name = nil,
  code_workspace_path = nil,
}

---Configure the plugin (optional - works without calling this)
---@param opts nvim-workspaces.Config|nil User configuration
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  if M.config.enable_keymaps then
    local maps = {
      { "<leader>Wa", "<cmd>Workspaces add<cr>", desc = "Add Workspace Folder" },
      { "<leader>Wr", "<cmd>Workspaces remove<cr>", desc = "Remove Workspace Folder" },
      { "<leader>Wl", "<cmd>Workspaces load<cr>", desc = "Load Workspace" },
      { "<leader>Ws", "<cmd>Workspaces save<cr>", desc = "Save Workspace" },
      { "<leader>WL", "<cmd>Workspaces list<cr>", desc = "List Workspace Folders" },
      { "<leader>Wc", "<cmd>Workspaces clear<cr>", desc = "Clear Workspace" },
      { "<leader>Wd", "<cmd>Workspaces delete<cr>", desc = "Delete Saved Workspace" },
      { "<leader>We", "<cmd>Workspaces export<cr>", desc = "Export Workspace to File" },
      { "<leader>Wn", "<cmd>Workspaces rename<cr>", desc = "Rename Workspace" },
      { "<leader>Wf", "<cmd>Workspaces find<cr>", desc = "Find Files in Workspace" },
      { "<leader>Wo", "<cmd>Workspaces open<cr>", desc = "Open Workspace File" },
    }

    for _, map in ipairs(maps) do
      vim.keymap.set("n", map[1], map[2], { desc = map.desc })
    end

    -- Try to register group with which-key
    local ok, wk = pcall(require, "which-key")
    if ok and wk.add then
      wk.add({ { "<leader>W", group = "workspaces" } })
    end
  end
end

---Normalize a path (resolve symlinks, remove trailing slash)
---@param path string
---@return string
local function normalize_path(path)
  -- Expand ~ and environment variables
  path = vim.fn.expand(path)
  -- Resolve to absolute path
  local resolved = vim.loop.fs_realpath(path)
  if resolved then
    path = resolved
  end
  -- Remove trailing slash
  path = path:gsub("/$", "")
  return path
end

---Check if a folder is already in the workspace
---@param path string
---@return boolean
local function has_folder(path)
  for _, folder in ipairs(M.state.folders) do
    if folder == path then
      return true
    end
  end
  return false
end

---Auto-save current workspace state
---Saves to named workspace if loaded, otherwise to _current.json
local function auto_save()
  local persistence = require("nvim-workspaces.persistence")
  if M.state.name then
    persistence.save(M.state.name, true)
  else
    persistence.save_current()
  end
end

---Add a folder to the workspace
---@param path string The folder path to add
---@return boolean success Whether the folder was added
function M.add(path)
  path = normalize_path(path)

  -- Check if path exists
  if vim.fn.isdirectory(path) == 0 then
    vim.notify("[nvim-workspaces] Directory does not exist: " .. path, vim.log.levels.ERROR)
    return false
  end

  -- Check for duplicates
  if has_folder(path) then
    vim.notify("[nvim-workspaces] Already in workspace: " .. path, vim.log.levels.WARN)
    return false
  end

  -- Add to state
  table.insert(M.state.folders, path)

  -- Add to LSP workspace folders
  vim.lsp.buf.add_workspace_folder(path)

  -- Auto-save
  auto_save()

  vim.notify("[nvim-workspaces] Added: " .. path, vim.log.levels.INFO)
  return true
end

---Remove a folder from the workspace
---@param path string The folder path to remove
---@return boolean success Whether the folder was removed
function M.remove(path)
  path = normalize_path(path)

  -- Find and remove from state
  for i, folder in ipairs(M.state.folders) do
    if folder == path then
      table.remove(M.state.folders, i)

      -- Remove from LSP workspace folders
      vim.lsp.buf.remove_workspace_folder(path)

      -- Auto-save
      auto_save()

      vim.notify("[nvim-workspaces] Removed: " .. path, vim.log.levels.INFO)
      return true
    end
  end

  vim.notify("[nvim-workspaces] Not in workspace: " .. path, vim.log.levels.WARN)
  return false
end

---Get list of current workspace folders
---@return string[] folders List of folder paths
function M.list()
  return vim.deepcopy(M.state.folders)
end

---Remove all folders from the workspace
function M.clear()
  -- Remove each folder from LSP
  for _, folder in ipairs(M.state.folders) do
    vim.lsp.buf.remove_workspace_folder(folder)
  end

  M.state.folders = {}

  -- Auto-save BEFORE clearing the name, so it saves to the correct workspace
  auto_save()

  vim.notify("[nvim-workspaces] Cleared all workspace folders", vim.log.levels.INFO)
end

return M
