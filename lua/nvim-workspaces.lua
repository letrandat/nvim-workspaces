---@class nvim-workspaces.Config
---@field auto_restore boolean Auto-restore last session's workspace on startup
---@field auto_load_code_workspace boolean Auto-load .code-workspace file if found
---@field sync_to_code_workspace boolean Sync changes back to .code-workspace file
---@field data_dir string Directory for persistence
---@field picker_cwd string Default directory for Telescope picker

---@class nvim-workspaces.State
---@field folders string[] Currently active workspace folders

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
}

---@type nvim-workspaces.State
M.state = {
  folders = {},
}

---Configure the plugin (optional - works without calling this)
---@param opts nvim-workspaces.Config|nil User configuration
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

return M
