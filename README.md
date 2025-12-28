# nvim-workspaces

A Neovim plugin for managing multi-root workspaces with LSP integration and `.code-workspace` file support.

## Features

- **Multi-root workspace management** - Add/remove directories to your workspace dynamically
- **LSP integration** - Workspace folders are synced with `vim.lsp.buf.add_workspace_folder()`
- **`.code-workspace` support** - Load VSCode-style workspace files (with JSONC comment support)
- **Persistence** - Save and restore workspace configurations
- **Telescope integration** - Fuzzy find folders to add/remove
- **Auto-restore** - Automatically restore last session's workspace on startup

## Requirements

- Neovim >= 0.10.0
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional, for pickers)

## Installation

### lazy.nvim

```lua
{
  "dat/nvim-workspaces",
  dependencies = {
    "nvim-telescope/telescope.nvim", -- optional
  },
  opts = {},
  keys = {
    { "<leader>Wa", "<Plug>(nvim-workspaces-add)", desc = "Add workspace folder" },
    { "<leader>Wr", "<Plug>(nvim-workspaces-remove)", desc = "Remove workspace folder" },
    { "<leader>Ww", "<Plug>(nvim-workspaces-switch)", desc = "Switch workspace" },
    { "<leader>Ws", "<Plug>(nvim-workspaces-save)", desc = "Save workspace" },
    { "<leader>WL", "<Plug>(nvim-workspaces-list)", desc = "List workspace folders" },
    { "<leader>Wc", "<Plug>(nvim-workspaces-clear)", desc = "Clear all workspace folders" },
  },
}
```

## Commands

All commands are grouped under `:Workspaces`:

| Command                     | Description                                                |
| --------------------------- | ---------------------------------------------------------- |
| `:Workspaces add [path]`    | Add folder to workspace (Telescope picker if no path)      |
| `:Workspaces remove [path]` | Remove folder from workspace (Telescope picker if no path) |
| `:Workspaces list`          | Show current workspace folders                             |
| `:Workspaces clear`         | Remove all workspace folders                               |
| `:Workspaces save [name]`   | Save current workspace configuration                       |
| `:Workspaces switch [name]` | Switch to a saved workspace configuration                  |
| `:Workspaces delete [name]` | Delete a saved workspace configuration                     |

## Configuration

```lua
require("nvim-workspaces").setup({
  -- Auto-load .code-workspace file if found
  auto_load_code_workspace = true,

  -- Auto-restore last session's workspace on startup
  auto_restore = true,

  -- Sync changes back to .code-workspace file
  sync_to_code_workspace = false,

  -- Default directory for Telescope picker
  picker_cwd = vim.fn.expand("~/workspace"),

  -- Persistence directory
  data_dir = vim.fn.stdpath("data") .. "/nvim-workspaces",
})
```

## Project Structure

```
nvim-workspaces/
├── .github/
│   └── workflows/              # CI/CD workflows
├── lua/
│   ├── nvim-workspaces/
│   │   ├── jsonc.lua           # JSONC parser (handles comments)
│   │   ├── persistence.lua     # Save/load workspace configs
│   │   ├── telescope.lua       # Telescope pickers
│   │   ├── code_workspace.lua  # .code-workspace file handling
│   │   └── health.lua          # Health checks (:checkhealth)
│   └── nvim-workspaces.lua     # Main module (setup, config, public API)
├── plugin/
│   └── nvim-workspaces.lua     # Startup: commands, <Plug> mappings
├── tests/
│   ├── minimal_init.lua        # Test runner init
│   └── nvim-workspaces/
│       ├── jsonc_spec.lua      # JSONC parser tests
│       └── core_spec.lua       # Core functionality tests
├── doc/
│   └── nvim-workspaces.txt     # Vimdoc
├── .gitignore
├── .stylua.toml                # Lua formatter config
├── Makefile                    # Test runner
├── LICENSE
└── README.md
```

## How It Works

### claudecode.nvim Integration

This plugin works seamlessly with [claudecode.nvim](https://github.com/anthropics/claude-code). When you add workspace folders:

1. Plugin calls `vim.lsp.buf.add_workspace_folder(path)`
2. claudecode.nvim reads LSP workspace folders and exposes them to Claude Code
3. Claude Code can now see and access files from all your workspace folders

### .code-workspace Files

The plugin can read VSCode-style `.code-workspace` files:

```jsonc
{
  // This is a comment (supported!)
  "folders": [
    { "path": "frontend" },
    { "path": "backend" },
    { "path": "../shared-lib" }
  ]
}
```

## License

MIT
