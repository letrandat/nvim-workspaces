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
      -- Resolve symlinks in assertion if needed, but test logic uses path defined above which might be symlinked.
      -- Let's resolve expected paths to be safe.
      local real_frontend = vim.loop.fs_realpath(frontend)
      local real_backend = vim.loop.fs_realpath(backend)

      assert.equals(real_frontend, folders[1])
      assert.equals(real_backend, folders[2])
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
end)
