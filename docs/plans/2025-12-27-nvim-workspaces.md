# nvim-workspaces Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Neovim plugin for managing multi-root workspaces with LSP integration, .code-workspace file support, and persistence.

**Architecture:** Plugin uses vim.lsp.buf.add_workspace_folder() as the core mechanism. State is managed in-memory and persisted to JSON files. Telescope provides the UI for folder selection. JSONC parser strips comments before vim.json.decode().

**Tech Stack:** Lua 5.1, Neovim >= 0.10, telescope.nvim (optional), plenary.nvim (testing)

---

## Task 1: JSONC Parser Module

**Files:**
- Create: `lua/nvim-workspaces/jsonc.lua`
- Test: `tests/nvim-workspaces/jsonc_spec.lua`

**Step 1: Write the failing test for line comment stripping**

```lua
-- tests/nvim-workspaces/jsonc_spec.lua
local jsonc = require("nvim-workspaces.jsonc")

describe("jsonc", function()
  describe("strip_comments", function()
    it("strips line comments", function()
      local input = [[{
  // this is a comment
  "key": "value"
}]]
      local result = jsonc.strip_comments(input)
      assert.is_nil(result:find("//"))
      assert.is_not_nil(result:find('"key"'))
    end)
  end)
end)
```

**Step 2: Run test to verify it fails**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: FAIL with "module 'nvim-workspaces.jsonc' not found"

**Step 3: Write minimal implementation**

```lua
-- lua/nvim-workspaces/jsonc.lua
---@class nvim-workspaces.jsonc
local M = {}

---Strip JSONC comments (// and /* */) from a string
---@param str string The JSONC string
---@return string The JSON string without comments
function M.strip_comments(str)
  -- Remove single-line comments (// ...)
  str = str:gsub("//[^\n]*", "")
  return str
end

return M
```

**Step 4: Run test to verify it passes**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: PASS

**Step 5: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add lua/nvim-workspaces/jsonc.lua tests/nvim-workspaces/jsonc_spec.lua
git commit -m "feat(jsonc): add line comment stripping"
```

---

**Step 6: Write failing test for block comment stripping**

Add to `tests/nvim-workspaces/jsonc_spec.lua`:

```lua
    it("strips block comments", function()
      local input = [[{
  /* this is a
     block comment */
  "key": "value"
}]]
      local result = jsonc.strip_comments(input)
      assert.is_nil(result:find("/*"))
      assert.is_nil(result:find("*/"))
      assert.is_not_nil(result:find('"key"'))
    end)
```

**Step 7: Run test to verify it fails**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: FAIL (block comments not stripped)

**Step 8: Update implementation**

```lua
-- lua/nvim-workspaces/jsonc.lua
---@class nvim-workspaces.jsonc
local M = {}

---Strip JSONC comments (// and /* */) from a string
---@param str string The JSONC string
---@return string The JSON string without comments
function M.strip_comments(str)
  -- Remove block comments (/* ... */)
  str = str:gsub("/%*.-%*/", "")
  -- Remove single-line comments (// ...)
  str = str:gsub("//[^\n]*", "")
  return str
end

return M
```

**Step 9: Run test to verify it passes**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: PASS

**Step 10: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(jsonc): add block comment stripping"
```

---

**Step 11: Write failing test for decode function**

Add to `tests/nvim-workspaces/jsonc_spec.lua`:

```lua
  describe("decode", function()
    it("decodes JSONC with comments", function()
      local input = [[{
  // comment
  "folders": [
    { "path": "frontend" },
    /* block */ { "path": "backend" }
  ]
}]]
      local result = jsonc.decode(input)
      assert.is_not_nil(result)
      assert.is_not_nil(result.folders)
      assert.equals(2, #result.folders)
      assert.equals("frontend", result.folders[1].path)
      assert.equals("backend", result.folders[2].path)
    end)

    it("returns nil and error for invalid JSON", function()
      local result, err = jsonc.decode("{ invalid }")
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)
  end)
```

**Step 12: Run test to verify it fails**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: FAIL (decode function not defined)

**Step 13: Implement decode function**

Update `lua/nvim-workspaces/jsonc.lua`:

```lua
---@class nvim-workspaces.jsonc
local M = {}

---Strip JSONC comments (// and /* */) from a string
---@param str string The JSONC string
---@return string The JSON string without comments
function M.strip_comments(str)
  -- Remove block comments (/* ... */)
  str = str:gsub("/%*.-%*/", "")
  -- Remove single-line comments (// ...)
  str = str:gsub("//[^\n]*", "")
  return str
end

---Decode a JSONC string to a Lua table
---@param str string The JSONC string
---@return table|nil result The decoded table, or nil on error
---@return string|nil error The error message, or nil on success
function M.decode(str)
  local json_str = M.strip_comments(str)
  local ok, result = pcall(vim.json.decode, json_str)
  if ok then
    return result, nil
  else
    return nil, result
  end
end

return M
```

**Step 14: Run test to verify it passes**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: PASS

**Step 15: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(jsonc): add decode function with error handling"
```

---

## Task 2: Core Module - State and Config

**Files:**
- Create: `lua/nvim-workspaces.lua`
- Test: `tests/nvim-workspaces/core_spec.lua`

**Step 1: Write failing test for default config**

```lua
-- tests/nvim-workspaces/core_spec.lua
local workspaces = require("nvim-workspaces")

describe("nvim-workspaces", function()
  describe("config", function()
    it("has sensible defaults", function()
      assert.is_true(workspaces.config.auto_restore)
      assert.is_true(workspaces.config.auto_load_code_workspace)
      assert.is_false(workspaces.config.sync_to_code_workspace)
      assert.is_not_nil(workspaces.config.data_dir)
      assert.is_not_nil(workspaces.config.picker_cwd)
    end)
  end)
end)
```

**Step 2: Run test to verify it fails**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: FAIL (module not found)

**Step 3: Write minimal implementation**

```lua
-- lua/nvim-workspaces.lua
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

return M
```

**Step 4: Run test to verify it passes**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: PASS

**Step 5: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(core): add config with sensible defaults"
```

---

**Step 6: Write failing test for setup function**

Add to `tests/nvim-workspaces/core_spec.lua`:

```lua
  describe("setup", function()
    it("merges user config with defaults", function()
      workspaces.setup({ picker_cwd = "/custom/path" })
      assert.equals("/custom/path", workspaces.config.picker_cwd)
      -- defaults should still be present
      assert.is_true(workspaces.config.auto_restore)
    end)
  end)
```

**Step 7: Run test to verify it fails**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: FAIL (setup function not defined)

**Step 8: Implement setup function**

Add to `lua/nvim-workspaces.lua`:

```lua
---Configure the plugin (optional - works without calling this)
---@param opts nvim-workspaces.Config|nil User configuration
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end
```

**Step 9: Run test to verify it passes**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: PASS

**Step 10: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(core): add setup function for optional config"
```

---

## Task 3: Core Module - Add/Remove/List/Clear

**Files:**
- Modify: `lua/nvim-workspaces.lua`
- Modify: `tests/nvim-workspaces/core_spec.lua`

**Step 1: Write failing test for add function**

Add to `tests/nvim-workspaces/core_spec.lua`:

```lua
  describe("add", function()
    before_each(function()
      workspaces.state.folders = {}
    end)

    it("adds a folder to state", function()
      local path = "/tmp/test-workspace"
      vim.fn.mkdir(path, "p")

      workspaces.add(path)

      assert.equals(1, #workspaces.state.folders)
      assert.equals(path, workspaces.state.folders[1])

      vim.fn.delete(path, "d")
    end)

    it("does not add duplicates", function()
      local path = "/tmp/test-workspace"
      vim.fn.mkdir(path, "p")

      workspaces.add(path)
      workspaces.add(path)

      assert.equals(1, #workspaces.state.folders)

      vim.fn.delete(path, "d")
    end)

    it("normalizes paths", function()
      local path = "/tmp/test-workspace"
      vim.fn.mkdir(path, "p")

      workspaces.add(path .. "/")

      assert.equals(path, workspaces.state.folders[1])

      vim.fn.delete(path, "d")
    end)
  end)
```

**Step 2: Run test to verify it fails**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: FAIL (add function not defined)

**Step 3: Implement add function**

Add to `lua/nvim-workspaces.lua`:

```lua
---Normalize a path (resolve symlinks, remove trailing slash)
---@param path string
---@return string
local function normalize_path(path)
  -- Expand ~ and environment variables
  path = vim.fn.expand(path)
  -- Resolve to absolute path
  local resolved = vim.uv.fs_realpath(path)
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

  vim.notify("[nvim-workspaces] Added: " .. path, vim.log.levels.INFO)
  return true
end
```

**Step 4: Run test to verify it passes**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: PASS

**Step 5: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(core): add function to add workspace folders"
```

---

**Step 6: Write failing test for remove function**

Add to `tests/nvim-workspaces/core_spec.lua`:

```lua
  describe("remove", function()
    before_each(function()
      workspaces.state.folders = {}
    end)

    it("removes a folder from state", function()
      local path = "/tmp/test-workspace"
      vim.fn.mkdir(path, "p")

      workspaces.add(path)
      assert.equals(1, #workspaces.state.folders)

      workspaces.remove(path)
      assert.equals(0, #workspaces.state.folders)

      vim.fn.delete(path, "d")
    end)

    it("returns false for non-existent folder", function()
      local result = workspaces.remove("/nonexistent")
      assert.is_false(result)
    end)
  end)
```

**Step 7: Run test to verify it fails**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: FAIL (remove function not defined)

**Step 8: Implement remove function**

Add to `lua/nvim-workspaces.lua`:

```lua
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

      vim.notify("[nvim-workspaces] Removed: " .. path, vim.log.levels.INFO)
      return true
    end
  end

  vim.notify("[nvim-workspaces] Not in workspace: " .. path, vim.log.levels.WARN)
  return false
end
```

**Step 9: Run test to verify it passes**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: PASS

**Step 10: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(core): add function to remove workspace folders"
```

---

**Step 11: Write failing test for list and clear functions**

Add to `tests/nvim-workspaces/core_spec.lua`:

```lua
  describe("list", function()
    it("returns current folders", function()
      workspaces.state.folders = { "/path/a", "/path/b" }

      local folders = workspaces.list()

      assert.equals(2, #folders)
      assert.equals("/path/a", folders[1])
      assert.equals("/path/b", folders[2])
    end)
  end)

  describe("clear", function()
    it("removes all folders", function()
      local path1 = "/tmp/test-workspace-1"
      local path2 = "/tmp/test-workspace-2"
      vim.fn.mkdir(path1, "p")
      vim.fn.mkdir(path2, "p")

      workspaces.add(path1)
      workspaces.add(path2)
      assert.equals(2, #workspaces.state.folders)

      workspaces.clear()
      assert.equals(0, #workspaces.state.folders)

      vim.fn.delete(path1, "d")
      vim.fn.delete(path2, "d")
    end)
  end)
```

**Step 12: Run test to verify it fails**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: FAIL (list/clear functions not defined)

**Step 13: Implement list and clear functions**

Add to `lua/nvim-workspaces.lua`:

```lua
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
  vim.notify("[nvim-workspaces] Cleared all workspace folders", vim.log.levels.INFO)
end
```

**Step 14: Run test to verify it passes**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: PASS

**Step 15: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(core): add list and clear functions"
```

---

## Task 4: Persistence Module

**Files:**
- Create: `lua/nvim-workspaces/persistence.lua`
- Test: `tests/nvim-workspaces/persistence_spec.lua`

**Step 1: Write failing test for save_current**

```lua
-- tests/nvim-workspaces/persistence_spec.lua
local persistence = require("nvim-workspaces.persistence")
local workspaces = require("nvim-workspaces")

describe("persistence", function()
  local test_dir = "/tmp/nvim-workspaces-test"

  before_each(function()
    vim.fn.mkdir(test_dir, "p")
    workspaces.config.data_dir = test_dir
    workspaces.state.folders = {}
  end)

  after_each(function()
    vim.fn.delete(test_dir, "rf")
  end)

  describe("save_current", function()
    it("saves current state to _current.json", function()
      workspaces.state.folders = { "/path/a", "/path/b" }

      persistence.save_current()

      local file = test_dir .. "/_current.json"
      assert.equals(1, vim.fn.filereadable(file))

      local content = vim.fn.readfile(file)
      local data = vim.json.decode(table.concat(content, "\n"))
      assert.equals(2, #data.folders)
    end)
  end)
end)
```

**Step 2: Run test to verify it fails**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: FAIL (module not found)

**Step 3: Implement save_current**

```lua
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

return M
```

**Step 4: Run test to verify it passes**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: PASS

**Step 5: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(persistence): add save_current function"
```

---

**Step 6: Write failing test for load_current**

Add to `tests/nvim-workspaces/persistence_spec.lua`:

```lua
  describe("load_current", function()
    it("loads state from _current.json", function()
      -- Create test directories
      local path1 = "/tmp/test-ws-1"
      local path2 = "/tmp/test-ws-2"
      vim.fn.mkdir(path1, "p")
      vim.fn.mkdir(path2, "p")

      -- Save a state file
      local file = test_dir .. "/_current.json"
      local data = vim.json.encode({ folders = { path1, path2 } })
      vim.fn.writefile({ data }, file)

      -- Load it
      local folders = persistence.load_current()

      assert.equals(2, #folders)
      assert.equals(path1, folders[1])
      assert.equals(path2, folders[2])

      vim.fn.delete(path1, "d")
      vim.fn.delete(path2, "d")
    end)

    it("returns empty table if no file exists", function()
      local folders = persistence.load_current()
      assert.equals(0, #folders)
    end)

    it("skips non-existent directories", function()
      local file = test_dir .. "/_current.json"
      local data = vim.json.encode({ folders = { "/nonexistent/path" } })
      vim.fn.writefile({ data }, file)

      local folders = persistence.load_current()
      assert.equals(0, #folders)
    end)
  end)
```

**Step 7: Run test to verify it fails**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: FAIL (load_current not defined)

**Step 8: Implement load_current**

Add to `lua/nvim-workspaces/persistence.lua`:

```lua
---Load current workspace state from _current.json
---@return string[] folders List of valid folder paths
function M.load_current()
  local dir = get_workspaces().config.data_dir
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
```

**Step 9: Run test to verify it passes**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: PASS

**Step 10: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(persistence): add load_current function"
```

---

**Step 11: Write failing test for save/load named workspaces**

Add to `tests/nvim-workspaces/persistence_spec.lua`:

```lua
  describe("save", function()
    it("saves workspace with a name", function()
      workspaces.state.folders = { "/path/a" }

      persistence.save("my-project")

      local file = test_dir .. "/my-project.json"
      assert.equals(1, vim.fn.filereadable(file))
    end)
  end)

  describe("load", function()
    it("loads a named workspace", function()
      local path = "/tmp/test-ws"
      vim.fn.mkdir(path, "p")

      local file = test_dir .. "/my-project.json"
      local data = vim.json.encode({ folders = { path } })
      vim.fn.writefile({ data }, file)

      local folders = persistence.load("my-project")
      assert.equals(1, #folders)

      vim.fn.delete(path, "d")
    end)
  end)

  describe("delete", function()
    it("deletes a named workspace", function()
      local file = test_dir .. "/my-project.json"
      vim.fn.writefile({ "{}" }, file)
      assert.equals(1, vim.fn.filereadable(file))

      persistence.delete("my-project")
      assert.equals(0, vim.fn.filereadable(file))
    end)
  end)

  describe("list_saved", function()
    it("lists all saved workspaces", function()
      vim.fn.writefile({ "{}" }, test_dir .. "/project-a.json")
      vim.fn.writefile({ "{}" }, test_dir .. "/project-b.json")
      vim.fn.writefile({ "{}" }, test_dir .. "/_current.json")

      local saved = persistence.list_saved()

      -- Should not include _current
      assert.equals(2, #saved)
      assert.is_true(vim.tbl_contains(saved, "project-a"))
      assert.is_true(vim.tbl_contains(saved, "project-b"))
    end)
  end)
```

**Step 12: Run test to verify it fails**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: FAIL

**Step 13: Implement save/load/delete/list_saved**

Add to `lua/nvim-workspaces/persistence.lua`:

```lua
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
```

**Step 14: Run test to verify it passes**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: PASS

**Step 15: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(persistence): add save/load/delete/list_saved functions"
```

---

## Task 5: .code-workspace File Support

**Files:**
- Create: `lua/nvim-workspaces/code_workspace.lua`
- Test: `tests/nvim-workspaces/code_workspace_spec.lua`

**Step 1: Write failing test for find_workspace_file**

```lua
-- tests/nvim-workspaces/code_workspace_spec.lua
local code_workspace = require("nvim-workspaces.code_workspace")

describe("code_workspace", function()
  local test_dir = "/tmp/nvim-workspaces-test-cw"

  before_each(function()
    vim.fn.mkdir(test_dir .. "/subdir", "p")
  end)

  after_each(function()
    vim.fn.delete(test_dir, "rf")
  end)

  describe("find_workspace_file", function()
    it("finds .code-workspace file in current dir", function()
      local ws_file = test_dir .. "/test.code-workspace"
      vim.fn.writefile({ "{}" }, ws_file)

      local found = code_workspace.find_workspace_file(test_dir)
      assert.equals(ws_file, found)
    end)

    it("finds .code-workspace file in parent dir", function()
      local ws_file = test_dir .. "/test.code-workspace"
      vim.fn.writefile({ "{}" }, ws_file)

      local found = code_workspace.find_workspace_file(test_dir .. "/subdir")
      assert.equals(ws_file, found)
    end)

    it("returns nil if no file found", function()
      local found = code_workspace.find_workspace_file(test_dir)
      assert.is_nil(found)
    end)
  end)
end)
```

**Step 2: Run test to verify it fails**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: FAIL (module not found)

**Step 3: Implement find_workspace_file**

```lua
-- lua/nvim-workspaces/code_workspace.lua
local M = {}

---Find a .code-workspace file by searching upward from a directory
---@param start_dir string|nil Starting directory (defaults to cwd)
---@return string|nil path Path to the .code-workspace file, or nil if not found
function M.find_workspace_file(start_dir)
  start_dir = start_dir or vim.fn.getcwd()

  local files = vim.fs.find(function(name)
    return vim.fn.fnamemodify(name, ":e") == "code-workspace"
  end, { upward = true, path = start_dir })

  return files[1]
end

return M
```

**Step 4: Run test to verify it passes**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: PASS

**Step 5: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(code-workspace): add find_workspace_file function"
```

---

**Step 6: Write failing test for load_workspace_file**

Add to `tests/nvim-workspaces/code_workspace_spec.lua`:

```lua
  describe("load_workspace_file", function()
    it("loads folders from .code-workspace file", function()
      -- Create test directories
      local frontend = test_dir .. "/frontend"
      local backend = test_dir .. "/backend"
      vim.fn.mkdir(frontend, "p")
      vim.fn.mkdir(backend, "p")

      -- Create workspace file with JSONC
      local ws_file = test_dir .. "/test.code-workspace"
      local content = [[{
  // Project folders
  "folders": [
    { "path": "frontend" },
    { "path": "backend" }
  ]
}]]
      vim.fn.writefile(vim.split(content, "\n"), ws_file)

      local folders = code_workspace.load_workspace_file(ws_file)

      assert.equals(2, #folders)
      assert.equals(frontend, folders[1])
      assert.equals(backend, folders[2])
    end)

    it("skips non-existent folders", function()
      local ws_file = test_dir .. "/test.code-workspace"
      local content = [[{
  "folders": [
    { "path": "nonexistent" }
  ]
}]]
      vim.fn.writefile(vim.split(content, "\n"), ws_file)

      local folders = code_workspace.load_workspace_file(ws_file)
      assert.equals(0, #folders)
    end)
  end)
```

**Step 7: Run test to verify it fails**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: FAIL

**Step 8: Implement load_workspace_file**

Add to `lua/nvim-workspaces/code_workspace.lua`:

```lua
local jsonc = require("nvim-workspaces.jsonc")

---Load folders from a .code-workspace file
---@param file_path string Path to the .code-workspace file
---@return string[] folders List of resolved folder paths
function M.load_workspace_file(file_path)
  local content = vim.fn.readfile(file_path)
  local data, err = jsonc.decode(table.concat(content, "\n"))

  if not data then
    vim.notify("[nvim-workspaces] Failed to parse workspace file: " .. (err or "unknown error"), vim.log.levels.ERROR)
    return {}
  end

  if not data.folders then
    return {}
  end

  local base_dir = vim.fs.dirname(file_path)
  local folders = {}

  for _, folder in ipairs(data.folders) do
    local path = folder.path
    -- Resolve relative paths
    if not vim.startswith(path, "/") then
      path = vim.fs.joinpath(base_dir, path)
    end
    -- Normalize
    local real_path = vim.uv.fs_realpath(path)
    if real_path and vim.fn.isdirectory(real_path) == 1 then
      table.insert(folders, real_path)
    end
  end

  return folders
end
```

**Step 9: Run test to verify it passes**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: PASS

**Step 10: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(code-workspace): add load_workspace_file function"
```

---

## Task 6: Plugin Startup File (Commands and Keymaps)

**Files:**
- Create: `plugin/nvim-workspaces.lua`

**Step 1: Create the plugin startup file**

```lua
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
  add = {
    impl = function(args)
      if args[1] then
        require("nvim-workspaces").add(args[1])
      else
        require("nvim-workspaces.telescope").pick_add()
      end
    end,
    complete = function(arg_lead)
      -- Complete directory paths
      local paths = vim.fn.glob(arg_lead .. "*", false, true)
      return vim.tbl_filter(function(p)
        return vim.fn.isdirectory(p) == 1
      end, paths)
    end,
  },
  remove = {
    impl = function(args)
      if args[1] then
        require("nvim-workspaces").remove(args[1])
      else
        require("nvim-workspaces.telescope").pick_remove()
      end
    end,
    complete = function()
      return require("nvim-workspaces").list()
    end,
  },
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
  clear = {
    impl = function()
      require("nvim-workspaces").clear()
    end,
  },
  save = {
    impl = function(args)
      if args[1] then
        require("nvim-workspaces.persistence").save(args[1])
      else
        vim.ui.input({ prompt = "Workspace name: " }, function(name)
          if name and name ~= "" then
            require("nvim-workspaces.persistence").save(name)
          end
        end)
      end
    end,
  },
  load = {
    impl = function(args)
      if args[1] then
        local folders = require("nvim-workspaces.persistence").load(args[1])
        local ws = require("nvim-workspaces")
        ws.clear()
        for _, folder in ipairs(folders) do
          ws.add(folder)
        end
      else
        require("nvim-workspaces.telescope").pick_load()
      end
    end,
    complete = function()
      return require("nvim-workspaces.persistence").list_saved()
    end,
  },
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
    complete = function()
      return require("nvim-workspaces.persistence").list_saved()
    end,
  },
}

-- Main command handler
local function workspaces_cmd(opts)
  local args = opts.fargs
  local subcmd = args[1]

  if not subcmd then
    vim.notify("[nvim-workspaces] Usage: :Workspaces <add|remove|list|clear|save|load|delete>", vim.log.levels.INFO)
    return
  end

  local cmd = subcommands[subcmd]
  if not cmd then
    vim.notify("[nvim-workspaces] Unknown subcommand: " .. subcmd, vim.log.levels.ERROR)
    return
  end

  local cmd_args = vim.list_slice(args, 2)
  cmd.impl(cmd_args)
end

-- Command completion
local function workspaces_complete(arg_lead, cmdline, _)
  local subcmd, subcmd_arg_lead = cmdline:match("^['<,'>]*Workspaces[!]?%s+(%S+)%s+(.*)$")

  if subcmd and subcmd_arg_lead and subcommands[subcmd] and subcommands[subcmd].complete then
    return subcommands[subcmd].complete(subcmd_arg_lead)
  end

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
  require("nvim-workspaces.telescope").pick_add()
end, { desc = "Add workspace folder" })

vim.keymap.set("n", "<Plug>(nvim-workspaces-remove)", function()
  require("nvim-workspaces.telescope").pick_remove()
end, { desc = "Remove workspace folder" })

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
```

**Step 2: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(plugin): add commands and <Plug> mappings"
```

---

## Task 7: Telescope Integration

**Files:**
- Create: `lua/nvim-workspaces/telescope.lua`
- Test: (manual testing - telescope requires interactive session)

**Step 1: Create telescope module**

```lua
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
```

**Step 2: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(telescope): add pickers for add/remove/load"
```

---

## Task 8: Auto-Restore on Startup

**Files:**
- Modify: `plugin/nvim-workspaces.lua`

**Step 1: Add auto-restore logic to plugin file**

Add to the end of `plugin/nvim-workspaces.lua`:

```lua
-- Auto-restore on startup
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("nvim-workspaces-restore", { clear = true }),
  callback = function()
    vim.schedule(function()
      local workspaces = require("nvim-workspaces")

      -- Try to load .code-workspace file first
      if workspaces.config.auto_load_code_workspace then
        local code_workspace = require("nvim-workspaces.code_workspace")
        local ws_file = code_workspace.find_workspace_file()
        if ws_file then
          local folders = code_workspace.load_workspace_file(ws_file)
          for _, folder in ipairs(folders) do
            workspaces.add(folder)
          end
          return
        end
      end

      -- Fall back to restoring previous session
      if workspaces.config.auto_restore then
        local persistence = require("nvim-workspaces.persistence")
        local folders = persistence.load_current()
        for _, folder in ipairs(folders) do
          workspaces.add(folder)
        end
      end
    end)
  end,
})

-- Auto-save on workspace change
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("nvim-workspaces-autosave", { clear = true }),
  callback = function()
    -- Debounced save
    vim.defer_fn(function()
      local workspaces = require("nvim-workspaces")
      if #workspaces.state.folders > 0 then
        require("nvim-workspaces.persistence").save_current()
      end
    end, 1000)
  end,
})
```

**Step 2: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(plugin): add auto-restore and auto-save"
```

---

## Task 9: Health Checks

**Files:**
- Create: `lua/nvim-workspaces/health.lua`

**Step 1: Create health check module**

```lua
-- lua/nvim-workspaces/health.lua
local M = {}

function M.check()
  vim.health.start("nvim-workspaces")

  -- Check Neovim version
  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim >= 0.10")
  else
    vim.health.error("Neovim >= 0.10 required")
  end

  -- Check telescope (optional)
  local has_telescope = pcall(require, "telescope")
  if has_telescope then
    vim.health.ok("telescope.nvim found")
  else
    vim.health.warn("telescope.nvim not found (optional, using vim.ui.select fallback)")
  end

  -- Check data directory
  local workspaces = require("nvim-workspaces")
  local data_dir = workspaces.config.data_dir
  if vim.fn.isdirectory(data_dir) == 1 then
    vim.health.ok("Data directory exists: " .. data_dir)
  else
    vim.health.info("Data directory will be created: " .. data_dir)
  end

  -- Check current workspace state
  local folders = workspaces.list()
  vim.health.info("Current workspace folders: " .. #folders)
  for _, folder in ipairs(folders) do
    vim.health.info("  - " .. folder)
  end

  -- Check for .code-workspace file
  local code_workspace = require("nvim-workspaces.code_workspace")
  local ws_file = code_workspace.find_workspace_file()
  if ws_file then
    vim.health.ok(".code-workspace file found: " .. ws_file)
  else
    vim.health.info("No .code-workspace file found in current directory tree")
  end
end

return M
```

**Step 2: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(health): add health checks"
```

---

## Task 10: Final Integration - Wire Up Core Module

**Files:**
- Modify: `lua/nvim-workspaces.lua`

**Step 1: Add auto-save trigger to add/remove functions**

Update `lua/nvim-workspaces.lua` to trigger auto-save after modifications:

Add near the end of the `add` function:

```lua
  -- Trigger auto-save
  vim.schedule(function()
    require("nvim-workspaces.persistence").save_current()
  end)
```

Add near the end of the `remove` function (after successful removal):

```lua
  -- Trigger auto-save
  vim.schedule(function()
    require("nvim-workspaces.persistence").save_current()
  end)
```

Add near the end of the `clear` function:

```lua
  -- Trigger auto-save
  vim.schedule(function()
    require("nvim-workspaces.persistence").save_current()
  end)
```

**Step 2: Run all tests**

Run: `cd ~/workspace/nvim-workspaces && make test`
Expected: All tests PASS

**Step 3: Commit**

```bash
cd ~/workspace/nvim-workspaces
git add -A
git commit -m "feat(core): add auto-save triggers to add/remove/clear"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | JSONC Parser | `lua/nvim-workspaces/jsonc.lua` |
| 2 | Core Config/State | `lua/nvim-workspaces.lua` |
| 3 | Add/Remove/List/Clear | `lua/nvim-workspaces.lua` |
| 4 | Persistence | `lua/nvim-workspaces/persistence.lua` |
| 5 | .code-workspace | `lua/nvim-workspaces/code_workspace.lua` |
| 6 | Commands/Keymaps | `plugin/nvim-workspaces.lua` |
| 7 | Telescope | `lua/nvim-workspaces/telescope.lua` |
| 8 | Auto-Restore | `plugin/nvim-workspaces.lua` |
| 9 | Health Checks | `lua/nvim-workspaces/health.lua` |
| 10 | Final Integration | `lua/nvim-workspaces.lua` |

---

## Testing the Plugin

After implementation, test manually:

```vim
" Add the plugin to runtimepath for development
:set rtp+=~/workspace/nvim-workspaces

" Test commands
:Workspaces add ~/workspace/project-a
:Workspaces add ~/workspace/project-b
:Workspaces list
:Workspaces save my-project
:Workspaces clear
:Workspaces load my-project

" Test with .code-workspace file
:cd ~/my-monorepo
" (should auto-load if .code-workspace exists)

" Check health
:checkhealth nvim-workspaces
```
