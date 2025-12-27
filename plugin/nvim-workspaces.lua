-- plugin/nvim-workspaces.lua
-- Startup file: defines commands and <Plug> mappings
-- Actual implementation is lazy-loaded via require()

if vim.g.loaded_nvim_workspaces then
  return
end
vim.g.loaded_nvim_workspaces = true

-- Subcommand definitions
---@type table<string, { impl: function, complete?: function }>
local subcommands = {
  -- Add folder to workspace
  add = {
    impl = function(args)
      if args[1] then
        require("nvim-workspaces").add(args[1])
      else
        vim.ui.input({ prompt = "Add folder: ", completion = "dir" }, function(path)
          if path and path ~= "" then
            require("nvim-workspaces").add(path)
          end
        end)
      end
    end,
  },
  -- Remove folder from workspace
  remove = {
    impl = function(args)
      if args[1] then
        require("nvim-workspaces").remove(args[1])
      else
        require("nvim-workspaces.telescope").pick_remove()
      end
    end,
    -- Completion handled in workspaces_complete
  },
  -- List workspace folders
  list = {
    impl = function()
      local folders = require("nvim-workspaces").list()
      if #folders == 0 then
        vim.notify("[nvim-workspaces] No workspace folders", vim.log.levels.INFO)
      else
        vim.notify("[nvim-workspaces] Workspace folders:\n" .. table.concat(folders, "\n"), vim.log.levels.INFO)
      end
    end,
  },
  -- Clear workspace folders
  clear = {
    impl = function()
      vim.ui.select({ "Yes", "No" }, {
        prompt = "Clear current workspace?",
      }, function(choice)
        if choice == "Yes" then
          require("nvim-workspaces").clear()
        end
      end)
    end,
  },
  -- Save workspace
  save = {
    impl = function(args)
      local name = args[1]
      if name then
        -- Explicit "Save As" with name argument
        require("nvim-workspaces.persistence").save(name)
        require("nvim-workspaces").state.name = name
        require("nvim-workspaces.persistence").save_current()
      else
        -- "Save As" prompt
        vim.ui.input({ prompt = "Save Workspace As: " }, function(input_name)
          if input_name and input_name ~= "" then
            require("nvim-workspaces.persistence").save(input_name)
            require("nvim-workspaces").state.name = input_name
            require("nvim-workspaces.persistence").save_current()
          end
        end)
      end
    end,
  },
  -- Load workspace
  load = {
    impl = function(args)
      if args[1] then
        local folders = require("nvim-workspaces.persistence").load(args[1])
        local ws = require("nvim-workspaces")
        ws.clear()
        for _, folder in ipairs(folders) do
          ws.add(folder)
        end
        ws.state.name = args[1]
        vim.notify("[nvim-workspaces] Loaded workspace: " .. args[1], vim.log.levels.INFO)
      else
        require("nvim-workspaces.telescope").pick_load()
      end
    end,
    -- Completion handled in workspaces_complete
  },
  -- Delete workspace
  delete = {
    impl = function(args)
      if args[1] then
        require("nvim-workspaces.persistence").delete(args[1])
      else
        vim.ui.select(require("nvim-workspaces.persistence").list_saved(), {
          prompt = "Delete workspace:",
        }, function(name)
          if name then
            require("nvim-workspaces.persistence").delete(name)
          end
        end)
      end
    end,
    -- Completion handled in workspaces_complete
  },
  -- Rename workspace
  rename = {
    impl = function(args)
      local persistence = require("nvim-workspaces.persistence")
      local ws = require("nvim-workspaces")
      local current_name = ws.state.name

      -- Case 1: Both old and new names provided (explicit rename)
      if args[1] and args[2] then
        if persistence.rename(args[1], args[2]) then
          if current_name == args[1] then
            ws.state.name = args[2]
            persistence.save_current()
          end
        end
        return
      end

      -- Case 2: One name provided (new name for CURRENT workspace)
      if args[1] then
        if not current_name then
          vim.notify(
            "[nvim-workspaces] No workspace loaded. Use 'Workspaces rename <old> <new>' or load a workspace first.",
            vim.log.levels.ERROR
          )
          return
        end

        if persistence.rename(current_name, args[1]) then
          ws.state.name = args[1]
          persistence.save_current()
        end
        return
      end

      -- Case 3: No args provided
      -- If we have a current workspace, ask to rename it
      if current_name then
        vim.ui.input(
          { prompt = "Rename workspace '" .. current_name .. "' to: ", default = current_name },
          function(new_name)
            if new_name and new_name ~= "" and new_name ~= current_name then
              if persistence.rename(current_name, new_name) then
                ws.state.name = new_name
                persistence.save_current()
              end
            end
          end
        )
      else
        -- Fallback: Select workspace to rename
        vim.ui.select(persistence.list_saved(), {
          prompt = "Rename workspace:",
        }, function(old_name)
          if old_name then
            vim.ui.input({ prompt = "New name for " .. old_name .. ": " }, function(new_name)
              if new_name and new_name ~= "" then
                if persistence.rename(old_name, new_name) then
                  if ws.state.name == old_name then
                    ws.state.name = new_name
                    persistence.save_current()
                  end
                end
              end
            end)
          end
        end)
      end
    end,
    -- Completion handled in workspaces_complete
  },
  -- Find files in workspace
  find = {
    impl = function()
      require("nvim-workspaces.telescope").find_files()
    end,
  },
  -- Open workspace file
  open = {
    impl = function()
      local name = require("nvim-workspaces").state.name
      local path = require("nvim-workspaces.persistence").path(name)
      if vim.fn.filereadable(path) == 1 then
        vim.cmd("edit " .. vim.fn.fnameescape(path))
      else
        vim.notify("[nvim-workspaces] Workspace file not found: " .. path, vim.log.levels.ERROR)
      end
    end,
  },
  -- Export workspace to .code-workspace file
  export = {
    impl = function()
      local ws = require("nvim-workspaces")
      local code_workspace = require("nvim-workspaces.code_workspace")

      -- Determine default name
      local default_name = "workspace-nvim.code-workspace"

      -- If we have a tracked code workspace path, derive from it
      if ws.state.code_workspace_path then
        local basename = vim.fn.fnamemodify(ws.state.code_workspace_path, ":t:r")
        -- If already ends in -nvim, keep it, else append -nvim
        if not vim.endswith(basename, "-nvim") then
          basename = basename .. "-nvim"
        end
        default_name = basename .. ".code-workspace"
      elseif ws.state.name then
        -- Fallback to internal name
        default_name = ws.state.name .. "-nvim.code-workspace"
      end

      vim.ui.input({ prompt = "Export workspace to: ", default = default_name }, function(input)
        if input and input ~= "" then
          -- If input is just a filename, assume cwd; else allow full path
          local target_path = input
          if not vim.startswith(input, "/") then
            target_path = vim.fn.getcwd() .. "/" .. input
          end

          local folders = ws.list()
          if code_workspace.write_workspace_file(target_path, folders) then
            vim.notify("[nvim-workspaces] Exported to: " .. target_path, vim.log.levels.INFO)
          end
        end
      end)
    end,
  },
}

-- Main command handler
local function workspaces_cmd(opts)
  local args = opts.fargs
  local subcmd = args[1]

  if not subcmd then
    local keys = vim.tbl_keys(subcommands)
    table.sort(keys)
    local usage = "[nvim-workspaces] Usage: :Workspaces <" .. table.concat(keys, "|") .. ">"
    vim.notify(usage, vim.log.levels.INFO)
    return
  end

  local cmd = subcommands[subcmd]

  if not cmd then
    local keys = vim.tbl_keys(subcommands)
    table.sort(keys)
    local usage = "[nvim-workspaces] Usage: :Workspaces <" .. table.concat(keys, "|") .. ">"
    vim.notify("[nvim-workspaces] Unknown subcommand: " .. subcmd .. "\n" .. usage, vim.log.levels.ERROR)
    return
  end

  local cmd_args = vim.list_slice(args, 2)
  cmd.impl(cmd_args)
end

-- Command completion
local function workspaces_complete(arg_lead, cmdline, _)
  local subcmd, subcmd_arg_lead = cmdline:match("^['<,'>]*Workspaces[!]?%s+(%S+)%s+(.*)$")

  -- Special handling for 'add' subcommand - use built-in dir completion
  if subcmd == "add" and subcmd_arg_lead then
    return vim.fn.getcompletion(subcmd_arg_lead, "dir")
  end

  -- Handle workspace-specific completions
  if subcmd and subcmd_arg_lead then
    if subcmd == "remove" then
      return require("nvim-workspaces").list()
    elseif subcmd == "load" or subcmd == "delete" or subcmd == "rename" then
      return require("nvim-workspaces.persistence").list_saved()
    end
  end

  -- Fallback to custom completion if defined
  if subcmd and subcmd_arg_lead and subcommands[subcmd] and subcommands[subcmd].complete then
    return subcommands[subcmd].complete(subcmd_arg_lead)
  end

  -- Complete subcommand names
  if cmdline:match("^['<,'>]*Workspaces[!]?%s+%w*$") then
    return vim.tbl_filter(function(key)
      return key:find(arg_lead, 1, true) == 1
    end, vim.tbl_keys(subcommands))
  end

  return {}
end

-- Register command
vim.api.nvim_create_user_command("Workspaces", workspaces_cmd, {
  nargs = "*",
  complete = workspaces_complete,
  desc = "Manage workspace folders",
})

-- <Plug> mappings
vim.keymap.set("n", "<Plug>(nvim-workspaces-add)", function()
  subcommands.add.impl({})
end, { desc = "Add folder to workspace" })

vim.keymap.set("n", "<Plug>(nvim-workspaces-remove)", function()
  require("nvim-workspaces.telescope").pick_remove()
end, { desc = "Remove folder from workspace" })

vim.keymap.set("n", "<Plug>(nvim-workspaces-list)", function()
  subcommands.list.impl()
end, { desc = "List workspace folders" })

vim.keymap.set("n", "<Plug>(nvim-workspaces-clear)", function()
  require("nvim-workspaces").clear()
end, { desc = "Clear workspace folders" })

vim.keymap.set("n", "<Plug>(nvim-workspaces-save)", function()
  subcommands.save.impl({})
end, { desc = "Save workspace" })

vim.keymap.set("n", "<Plug>(nvim-workspaces-load)", function()
  require("nvim-workspaces.telescope").pick_load()
end, { desc = "Load workspace" })

vim.keymap.set("n", "<Plug>(nvim-workspaces-find)", function()
  require("nvim-workspaces.telescope").find_files()
end, { desc = "Find files in workspace" })

vim.keymap.set("n", "<Plug>(nvim-workspaces-rename)", function()
  subcommands.rename.impl({})
end, { desc = "Rename workspace" })

vim.keymap.set("n", "<Plug>(nvim-workspaces-open)", function()
  subcommands.open.impl({})
end, { desc = "Open workspace file" })

vim.keymap.set("n", "<Plug>(nvim-workspaces-export)", function()
  subcommands.export.impl({})
end, { desc = "Export workspace to .code-workspace" })

-- Auto-load logic
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local workspaces = require("nvim-workspaces")

    -- 1. Try to load .code-workspace file
    if workspaces.config.auto_load_code_workspace then
      local code_workspace = require("nvim-workspaces.code_workspace")
      local ws_file = code_workspace.find_workspace_file()
      if ws_file then
        local folders = code_workspace.load_workspace_file(ws_file)
        if #folders > 0 then
          for _, folder in ipairs(folders) do
            workspaces.add(folder)
          end
          workspaces.state.code_workspace_path = ws_file
          vim.notify(
            "[nvim-workspaces] Loaded workspace from " .. vim.fn.fnamemodify(ws_file, ":t"),
            vim.log.levels.INFO
          )
          return -- Prioritize code-workspace over auto-restore
        end
      end
    end

    -- 2. Try to restore last session
    if workspaces.config.auto_restore then
      local persistence = require("nvim-workspaces.persistence")
      local folders, name = persistence.load_current()
      if #folders > 0 then
        for _, folder in ipairs(folders) do
          workspaces.add(folder)
        end
        workspaces.state.name = name
        if name then
          vim.notify("[nvim-workspaces] Restored workspace: " .. name, vim.log.levels.INFO)
        else
          vim.notify("[nvim-workspaces] Restored previous workspace", vim.log.levels.INFO)
        end
      end
    end
  end,
})
