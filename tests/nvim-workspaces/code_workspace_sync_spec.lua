-- tests/nvim-workspaces/code_workspace_sync_spec.lua
local code_workspace = require("nvim-workspaces.code_workspace")

describe("code_workspace sync", function()
  local test_dir = "/tmp/test-nvim-workspaces-sync"
  local workspace_file = test_dir .. "/test.code-workspace"

  before_each(function()
    vim.fn.mkdir(test_dir, "p")
    vim.fn.mkdir(test_dir .. "/subfolder", "p")
    vim.fn.mkdir(test_dir .. "/other", "p")
    vim.fn.mkdir("/tmp/outside-folder", "p")
  end)

  after_each(function()
    vim.fn.delete(test_dir, "rf")
    vim.fn.delete("/tmp/outside-folder", "rf")
  end)

  it("writes valid JSON code-workspace file", function()
    local folders = { test_dir .. "/subfolder" }
    local success = code_workspace.write_workspace_file(workspace_file, folders)
    assert.is_true(success)
    assert.equals(1, vim.fn.filereadable(workspace_file))

    local content = vim.fn.readfile(workspace_file)
    local decoded = vim.json.decode(table.concat(content, "\n"))
    assert.is_not_nil(decoded.folders)
    assert.equals(1, #decoded.folders)
  end)

  it("converts child paths to relative paths", function()
    local folders = { test_dir .. "/subfolder", test_dir .. "/other" }
    code_workspace.write_workspace_file(workspace_file, folders)

    local content = vim.fn.readfile(workspace_file)
    local decoded = vim.json.decode(table.concat(content, "\n"))

    -- Should be relative paths
    assert.equals("subfolder", decoded.folders[1].path)
    assert.equals("other", decoded.folders[2].path)
  end)

  it("keeps outside paths absolute", function()
    local outside = "/tmp/outside-folder"
    local folders = { outside }
    code_workspace.write_workspace_file(workspace_file, folders)

    local content = vim.fn.readfile(workspace_file)
    local decoded = vim.json.decode(table.concat(content, "\n"))

    assert.equals(outside, decoded.folders[1].path)
  end)
end)
