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

  describe("setup", function()
    it("merges user config with defaults", function()
      workspaces.setup({ picker_cwd = "/custom/path" })
      assert.equals("/custom/path", workspaces.config.picker_cwd)
      -- defaults should still be present
      assert.is_true(workspaces.config.auto_restore)
    end)
  end)

  describe("add", function()
    before_each(function()
      workspaces.state.folders = {}
    end)

    it("adds a folder to state", function()
      local path = "/tmp/test-workspace"
      vim.fn.mkdir(path, "p")
      local realpath = vim.loop.fs_realpath(path)

      workspaces.add(path)

      assert.equals(1, #workspaces.state.folders)
      assert.equals(realpath, workspaces.state.folders[1])

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
      local realpath = vim.loop.fs_realpath(path)

      workspaces.add(path .. "/")

      assert.equals(realpath, workspaces.state.folders[1])

      vim.fn.delete(path, "d")
    end)

    -- Failing tests for 'add' function
    it("fails to add non-existent folder", function()
      local path = "/tmp/non-existent-workspace"
      workspaces.add(path)
      assert.equals(0, #workspaces.state.folders)
    end)

  end)

  describe("remove", function()
    before_each(function()
      workspaces.state.folders = {}
    end)

    it("removes a folder from state", function()
      local path = "/tmp/test-workspace"
      vim.fn.mkdir(path, "p")
      local realpath = vim.loop.fs_realpath(path)

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

  describe("list", function()
    before_each(function()
      workspaces.state.folders = {}
    end)

    it("returns current folders", function()
      workspaces.state.folders = { "/path/a", "/path/b" }

      local folders = workspaces.list()

      assert.equals(2, #folders)
      assert.equals("/path/a", folders[1])
      assert.equals("/path/b", folders[2])
    end)
  end)

  describe("clear", function()
    before_each(function()
      workspaces.state.folders = {}
    end)

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
end)
