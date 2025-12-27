-- lua/nvim-workspaces/telescope.lua
local M = {}

---Check if telescope is available
---@return boolean
local function has_telescope()
  local ok = pcall(require, "telescope")
  return ok
end

---Pick a directory to add to workspace
function M.pick_add()
  if not has_telescope() then
    vim.ui.input({ prompt = "Add folder: ", completion = "dir" }, function(path)
      if path and path ~= "" then
        require("nvim-workspaces").add(path)
      end
    end)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local workspaces = require("nvim-workspaces")
  local cwd = workspaces.config.picker_cwd

  -- Get directories
  local dirs = vim.fn.glob(cwd .. "/*", false, true)
  dirs = vim.tbl_filter(function(d)
    return vim.fn.isdirectory(d) == 1
  end, dirs)

  pickers.new({}, {
    prompt_title = "Add Workspace Folder",
    finder = finders.new_table({
      results = dirs,
      entry_maker = function(entry)
        return {
          value = entry,
          display = vim.fn.fnamemodify(entry, ":t"),
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
          workspaces.add(selection.value)
        end
      end)
      return true
    end,
  }):find()
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
        local workspaces = require("nvim-workspaces")
        workspaces.clear()
        for _, folder in ipairs(folders) do
          workspaces.add(folder)
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
          local workspaces = require("nvim-workspaces")
          workspaces.clear()
          for _, folder in ipairs(folders) do
            workspaces.add(folder)
          end
        end
      end)
      return true
    end,
  }):find()
end

return M
