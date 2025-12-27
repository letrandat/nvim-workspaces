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

  describe("rename", function()
    it("renames a saved workspace", function()
      -- Create initial workspace
      local file_old = test_dir .. "/old_name.json"
      vim.fn.writefile({ "{}" }, file_old)

      local success = persistence.rename("old_name", "new_name")
      assert.is_true(success)

      local file_new = test_dir .. "/new_name.json"
      assert.equals(0, vim.fn.filereadable(file_old))
      assert.equals(1, vim.fn.filereadable(file_new))
    end)

    it("fails if old workspace does not exist", function()
      local success = persistence.rename("non_existent", "new_name")
      assert.is_false(success)
    end)

    it("fails if new workspace already exists", function()
      local file_old = test_dir .. "/old_name.json"
      local file_new = test_dir .. "/exists.json"
      vim.fn.writefile({ "{}" }, file_old)
      vim.fn.writefile({ "{}" }, file_new)

      local success = persistence.rename("old_name", "exists")
      assert.is_false(success)
      assert.equals(1, vim.fn.filereadable(file_old))
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
end)
