-- lua/nvim-workspaces/telescope.lua
local M = {}

---Check if telescope is available
---@return boolean
local function has_telescope()
  local ok = pcall(require, "telescope")
  return ok
end

---Pick a folder to remove from workspace
function M.pick_remove()
  local workspaces = require("nvim-workspaces")
  local folders = workspaces.list()

  if #folders == 0 then
    vim.notify("[nvim-workspaces] No workspace folders to remove", vim.log.levels.INFO)
    return
  end

  if not has_telescope() then
    vim.ui.select(folders, { prompt = "Remove folder:" }, function(path)
      if path then
        workspaces.remove(path)
      end
    end)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Remove Workspace Folder",
    finder = finders.new_table({
      results = folders,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry,
          ordinal = entry,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          workspaces.remove(selection.value)
        end
      end)
      return true
    end,
  }):find()
end

---Pick a saved workspace to load
function M.pick_load()
  local persistence = require("nvim-workspaces.persistence")
  local saved = persistence.list_saved()

  if #saved == 0 then
    vim.notify("[nvim-workspaces] No saved workspaces", vim.log.levels.INFO)
    return
  end

  if not has_telescope() then
    vim.ui.select(saved, { prompt = "Load workspace:" }, function(name)
      if name then
        local folders = persistence.load(name)
        if #folders > 0 then
          require("nvim-workspaces").switch_to(name, folders)
        end
      end
    end)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Load Workspace",
    finder = finders.new_table({
      results = saved,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry,
          ordinal = entry,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          local folders = persistence.load(selection.value)
          if #folders > 0 then
            require("nvim-workspaces").switch_to(selection.value, folders)
          end
        end
      end)
      return true
    end,
  }):find()
end

---Get all search directories (workspace folders only)
---@return string[]
function M.get_search_dirs()
  local workspaces = require("nvim-workspaces")
  return workspaces.list()
end

---Search files across all workspace folders
function M.find_files()
  if not has_telescope() then
    vim.notify("[nvim-workspaces] Telescope is required for find_files", vim.log.levels.ERROR)
    return
  end

  local builtin = require("telescope.builtin")
  local dirs = M.get_search_dirs()

  builtin.find_files({
    search_dirs = dirs,
    prompt_title = "Find Files (Workspace)",
  })
end

return M
