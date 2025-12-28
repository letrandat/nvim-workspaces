# nvim-workspaces Architecture

A Neovim plugin for managing multi-root workspaces with LSP integration.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           nvim-workspaces                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐     ┌──────────────────┐     ┌───────────────────┐    │
│  │  plugin/        │     │  lua/            │     │  lua/nvim-        │    │
│  │  nvim-          │────>│  nvim-           │<────│  workspaces/      │    │
│  │  workspaces.lua │     │  workspaces.lua  │     │  *.lua            │    │
│  │                 │     │                  │     │                   │    │
│  │  - Commands     │     │  - State         │     │  - persistence    │    │
│  │  - <Plug> maps  │     │  - Config        │     │  - telescope      │    │
│  │  - Autocmds     │     │  - Core API      │     │  - code_workspace │    │
│  └─────────────────┘     └──────────────────┘     │  - jsonc          │    │
│                                                   └───────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │      vim.lsp.buf.*            │
                    │  add_workspace_folder()       │
                    │  remove_workspace_folder()    │
                    └───────────────────────────────┘
```

## Module Responsibilities

| Module | Responsibility |
|--------|----------------|
| `plugin/nvim-workspaces.lua` | Entry point: commands, keymaps, autocmds |
| `lua/nvim-workspaces.lua` | Core API: state, config, add/remove/switch_to |
| `lua/nvim-workspaces/persistence.lua` | Pure I/O: save/load JSON files |
| `lua/nvim-workspaces/telescope.lua` | Telescope pickers (with vim.ui fallback) |
| `lua/nvim-workspaces/code_workspace.lua` | VS Code .code-workspace file support |
| `lua/nvim-workspaces/jsonc.lua` | JSONC parser (strips comments) |

---

## Core Data Flow

### State Management

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              M.state                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  {                                                                          │
│    folders = { "/path/a", "/path/b" },  -- Active workspace folders         │
│    name = "my-project",                 -- Current workspace name (or nil)  │
│    code_workspace_path = nil            -- Path to loaded .code-workspace   │
│  }                                                                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### switch_to() Flow (Unified Load Operation)

All workspace loading goes through `switch_to()` for consistency:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         switch_to(name, folders, opts)                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Callers:                                                                  │
│   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐         │
│   │ :Workspaces load │  │ telescope picker │  │ VimEnter autocmd │         │
│   └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘         │
│            │                     │                     │                    │
│            └─────────────────────┼─────────────────────┘                    │
│                                  ▼                                          │
│                    ┌─────────────────────────┐                              │
│                    │      switch_to()        │                              │
│                    └─────────────────────────┘                              │
│                                  │                                          │
│            ┌─────────────────────┼─────────────────────┐                    │
│            ▼                     ▼                     ▼                    │
│   ┌────────────────┐   ┌────────────────┐   ┌────────────────┐             │
│   │ clear_internal │   │ add() silent   │   │ save_current() │             │
│   │ (no auto-save) │   │ (no notify)    │   │ (for restore)  │             │
│   └────────────────┘   └────────────────┘   └────────────────┘             │
│                                  │                                          │
│                                  ▼                                          │
│                    ┌─────────────────────────┐                              │
│                    │  Single notification:   │                              │
│                    │  "Switched to: X (N)"   │                              │
│                    └─────────────────────────┘                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Persistence Layer (Pure I/O)

The persistence module is a pure I/O layer with no side effects:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Persistence Module                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Functions take data as parameters, return results:                        │
│                                                                             │
│   save(name, folders, opts)     ──────>  writes {name}.json                 │
│                                          returns: boolean success           │
│                                                                             │
│   load(name)                    ──────>  reads {name}.json                  │
│                                          returns: string[] folders          │
│                                                                             │
│   save_current()                ──────>  writes _current.json               │
│                                          (reads from M.state)               │
│                                          returns: boolean success           │
│                                                                             │
│   load_current()                ──────>  reads _current.json                │
│                                          returns: folders, name             │
│                                                                             │
│   ❌ NO state mutation inside persistence module                            │
│   ❌ NO side effects beyond file I/O                                        │
│   ✅ Caller controls state updates                                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Startup Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              VimEnter                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                           VimEnter Event                                    │
│                                  │                                          │
│                                  ▼                                          │
│                    ┌─────────────────────────┐                              │
│                    │ auto_load_code_workspace│                              │
│                    │       enabled?          │                              │
│                    └─────────────────────────┘                              │
│                          │            │                                     │
│                         YES          NO                                     │
│                          │            │                                     │
│                          ▼            │                                     │
│              ┌───────────────────┐    │                                     │
│              │ find_workspace_   │    │                                     │
│              │ file() upward     │    │                                     │
│              └───────────────────┘    │                                     │
│                   │          │        │                                     │
│                 found    not found    │                                     │
│                   │          │        │                                     │
│                   ▼          └────────┼──────────┐                          │
│     ┌─────────────────────┐           │          │                          │
│     │ switch_to(nil,      │           ▼          ▼                          │
│     │   folders, silent)  │  ┌─────────────────────────┐                    │
│     │ + set code_ws_path  │  │   auto_restore enabled? │                    │
│     └─────────────────────┘  └─────────────────────────┘                    │
│              │                    │            │                            │
│              │                   YES          NO                            │
│              │                    │            │                            │
│              │                    ▼            ▼                            │
│              │       ┌───────────────────┐   (done)                         │
│              │       │ load_current()    │                                  │
│              │       │ switch_to(name,   │                                  │
│              │       │   folders, silent)│                                  │
│              │       └───────────────────┘                                  │
│              │                    │                                         │
│              └────────────────────┼─────────────────────────────────────┐   │
│                                   ▼                                     │   │
│                    ┌─────────────────────────┐                          │   │
│                    │   Notify user what      │                          │   │
│                    │   was loaded            │                          │   │
│                    └─────────────────────────┘                          │   │
│                                                                         │   │
└─────────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────┐
│                              LspAttach                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Problem: At VimEnter, LSP clients aren't attached yet.                    │
│            vim.lsp.buf.add_workspace_folder() does nothing.                 │
│                                                                             │
│   Solution: Sync folders when each LSP client attaches.                     │
│                                                                             │
│                        LspAttach Event                                      │
│                              │                                              │
│                              ▼                                              │
│              ┌───────────────────────────────┐                              │
│              │ client.supports_method(       │                              │
│              │   "workspace/didChange...")?  │                              │
│              └───────────────────────────────┘                              │
│                      │              │                                       │
│                    YES             NO                                       │
│                      │              │                                       │
│                      ▼              ▼                                       │
│        ┌────────────────────┐    (skip)                                     │
│        │ for each folder:   │                                               │
│        │   add_workspace_   │                                               │
│        │   folder(folder)   │                                               │
│        └────────────────────┘                                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## .code-workspace Export Flow

When exporting, existing file content is preserved:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     write_workspace_file(path, folders)                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Before (file exists):              After:                                 │
│   ┌─────────────────────┐           ┌─────────────────────┐                 │
│   │ {                   │           │ {                   │                 │
│   │   "folders": [...], │  ──────>  │   "folders": [NEW], │ ◄── updated    │
│   │   "settings": {...},│           │   "settings": {...},│ ◄── preserved  │
│   │   "extensions": [...│           │   "extensions": [...│ ◄── preserved  │
│   │ }                   │           │ }                   │                 │
│   └─────────────────────┘           └─────────────────────┘                 │
│                                                                             │
│   Process:                                                                  │
│   1. Read existing file (if exists)                                         │
│   2. Parse with JSONC decoder                                               │
│   3. Replace only "folders" key                                             │
│   4. Encode and write back                                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Design Decisions

### 1. Unified Load via switch_to()

**Problem:** Load logic was duplicated in 3 places with subtle bugs.

**Solution:** Single `switch_to(name, folders, opts)` function handles all loading.

| Benefit | Description |
|---------|-------------|
| Consistency | Same behavior everywhere |
| No data loss | Proper clear before load |
| Single notification | N+1 notifications → 1 |

### 2. Persistence as Pure I/O

**Problem:** `persistence.save()` was mutating `M.state.name` as a side effect.

**Solution:** Persistence is pure I/O. Callers control state.

```lua
-- Before (bad)
persistence.save(name)  -- silently sets state.name!

-- After (good)
if persistence.save(name, folders) then
  M.state.name = name  -- caller controls state
end
```

### 3. LspAttach Sync

**Problem:** At `VimEnter`, LSP isn't ready. Folders weren't added to LSP.

**Solution:** `LspAttach` autocmd syncs folders to each newly attached client.

### 4. Workspace-Only Search

**Problem:** `find_files` included CWD even if unrelated to workspace.

**Solution:** `get_search_dirs()` returns only `state.folders`.

### 5. Confirmation for Destructive Actions

**Problem:** `<Plug>(nvim-workspaces-clear)` had no confirmation.

**Solution:** Both command and `<Plug>` mapping use confirmation prompt.

---

## File Structure

```
nvim-workspaces/
├── lua/
│   ├── nvim-workspaces.lua           # Core module (state, config, API)
│   └── nvim-workspaces/
│       ├── persistence.lua           # Pure I/O for JSON persistence
│       ├── telescope.lua             # Telescope pickers
│       ├── code_workspace.lua        # .code-workspace file support
│       ├── jsonc.lua                 # JSONC parser
│       └── health.lua                # :checkhealth integration
├── plugin/
│   └── nvim-workspaces.lua           # Entry point (commands, autocmds)
├── tests/
│   └── nvim-workspaces/
│       ├── core_spec.lua
│       ├── persistence_spec.lua
│       ├── telescope_spec.lua
│       ├── code_workspace_spec.lua
│       └── jsonc_spec.lua
├── docs/
│   └── ARCHITECTURE.md               # This document
├── Makefile                          # Test runner
└── README.md                         # User documentation
```

---

## API Reference

### Core Module (`require("nvim-workspaces")`)

```lua
-- Add a folder to workspace
M.add(path, opts?)                    -- opts: { silent?: boolean }

-- Remove a folder from workspace
M.remove(path)                        -- returns: boolean

-- List current folders
M.list()                              -- returns: string[]

-- Clear all folders
M.clear()                             -- triggers auto-save

-- Switch to a workspace (unified load)
M.switch_to(name, folders, opts?)     -- opts: { silent?: boolean }

-- Setup configuration
M.setup(opts?)                        -- optional, has defaults
```

### Persistence Module (`require("nvim-workspaces.persistence")`)

```lua
-- Save named workspace
M.save(name, folders, opts?)          -- returns: boolean

-- Load named workspace
M.load(name)                          -- returns: string[]

-- Save current state
M.save_current()                      -- returns: boolean

-- Load current state
M.load_current()                      -- returns: folders, name

-- Delete workspace
M.delete(name)

-- List saved workspaces
M.list_saved()                        -- returns: string[]

-- Rename workspace
M.rename(old, new)                    -- returns: boolean

-- Get workspace file path
M.path(name?)                         -- returns: string
```