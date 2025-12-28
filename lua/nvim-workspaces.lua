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
      { "<leader>Ww", "<cmd>Workspaces switch<cr>", desc = "Switch Workspace" },
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
    persistence.save(M.state.name, M.state.folders, { silent = true })
  else
    persistence.save_current()
  end
end

---@class nvim-workspaces.AddOpts
---@field silent? boolean Suppress notifications and auto-save

---Add a folder to the workspace
---@param path string The folder path to add
---@param opts? nvim-workspaces.AddOpts
---@return boolean success Whether the folder was added
function M.add(path, opts)
  opts = opts or {}
  path = normalize_path(path)

  -- Check if path exists
  if vim.fn.isdirectory(path) == 0 then
    if not opts.silent then
      vim.notify("[nvim-workspaces] Directory does not exist: " .. path, vim.log.levels.ERROR)
    end
    return false
  end

  -- Check for duplicates
  if has_folder(path) then
    if not opts.silent then
      vim.notify("[nvim-workspaces] Already in workspace: " .. path, vim.log.levels.WARN)
    end
    return false
  end

  -- Add to state
  table.insert(M.state.folders, path)

  -- Add to LSP workspace folders
  vim.lsp.buf.add_workspace_folder(path)

  if not opts.silent then
    auto_save()
    vim.notify("[nvim-workspaces] Added: " .. path, vim.log.levels.INFO)
  end

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

---Remove all folders from the workspace (internal, no auto-save)
---@param silent? boolean Suppress notification
local function clear_internal(silent)
  -- Remove each folder from LSP
  for _, folder in ipairs(M.state.folders) do
    vim.lsp.buf.remove_workspace_folder(folder)
  end

  M.state.folders = {}
  M.state.name = nil

  if not silent then
    vim.notify("[nvim-workspaces] Cleared all workspace folders", vim.log.levels.INFO)
  end
end

---Remove all folders from the workspace
function M.clear()
  clear_internal(false)
  auto_save()
end

---@class nvim-workspaces.SwitchOpts
---@field silent? boolean Suppress notifications

---Switch to a workspace
---@param name string|nil Workspace name (nil for anonymous)
---@param folders string[] Folder paths to activate
---@param opts? nvim-workspaces.SwitchOpts
function M.switch_to(name, folders, opts)
  opts = opts or {}

  -- Clear current workspace without auto-save or notification
  clear_internal(true)

  -- Add folders silently
  local added = 0
  for _, folder in ipairs(folders) do
    if M.add(folder, { silent = true }) then
      added = added + 1
    end
  end

  -- Set workspace name
  M.state.name = name

  -- Save to _current.json for session restore
  local persistence = require("nvim-workspaces.persistence")
  persistence.save_current()

  -- Single notification
  if not opts.silent then
    local display_name = name or "workspace"
    vim.notify(
      string.format("[nvim-workspaces] Switched to: %s (%d folders)", display_name, added),
      vim.log.levels.INFO
    )
  end
end

return M
