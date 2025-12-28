local stub = require("luassert.stub")

describe("telescope integration", function()
  local telescope_integration
  local workspaces
  local persistence
  local snapshot

  before_each(function()
    package.loaded["nvim-workspaces"] = nil
    package.loaded["nvim-workspaces.telescope"] = nil
    workspaces = require("nvim-workspaces")
    telescope_integration = require("nvim-workspaces.telescope")

    -- Mock the verify_path functionality to avoid filesystem checks during test setup if needed
    -- But core logic uses normalization. Let's just mock vim.fn.isdirectory/getcwd
    stub(vim.fn, "isdirectory")
    vim.fn.isdirectory.on_call_with("/tmp/project-a").returns(1)
    vim.fn.isdirectory.on_call_with("/tmp/project-b").returns(1)

    stub(vim.fn, "getcwd").returns("/tmp/current-project")

    -- Mock plenary/telescope dependencies slightly?
    -- Actually we want to test the `find_files` logic.
  end)

  after_each(function()
    if vim.fn.isdirectory.revert then vim.fn.isdirectory:revert() end
    if vim.fn.getcwd.revert then vim.fn.getcwd:revert() end
    workspaces.state.folders = {} -- Reset state
  end)

  it("get_search_dirs returns workspace folders only", function()
    -- Add some folders to workspace
    workspaces.state.folders = { "/tmp/project-a", "/tmp/project-b" }

    local dirs = telescope_integration.get_search_dirs()

    assert.equals(2, #dirs)
    -- Check contents
    local has_a = false
    local has_b = false

    for _, d in ipairs(dirs) do
      if d == "/tmp/project-a" then has_a = true end
      if d == "/tmp/project-b" then has_b = true end
    end

    assert.is_true(has_a, "Should include project-a")
    assert.is_true(has_b, "Should include project-b")
  end)

  it("get_search_dirs returns empty when no workspace folders", function()
    workspaces.state.folders = {}

    local dirs = telescope_integration.get_search_dirs()

    assert.equals(0, #dirs)
  end)
end)
