-- tests/nvim-workspaces/plugin_spec.lua
---@diagnostic disable: undefined-field

describe("plugin commands", function()
  -- Helper to capture notify messages
  local messages = {}
  local original_notify = vim.notify

  before_each(function()
    messages = {}
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(msg, level)
      table.insert(messages, { msg = msg, level = level })
    end
    -- Ensure plugin is loaded (since it might be lazy loaded or not sourced in test env)
    -- We assume the plugin file is sourced or we can simulate the command logic
    -- Since we can't easily source the plugin file again without side effects,
    -- we might need to rely on the fact that if this runs in a proper nvim test runner,
    -- the plugin should be active or we can manually source it.
    -- However, for robustness in unit-test style, we verify the command exists.
    -- If not, we source it.
    if vim.fn.exists(":Workspaces") == 0 then
      vim.cmd("source plugin/nvim-workspaces.lua")
    end
  end)

  after_each(function()
    vim.notify = original_notify
  end)

  it("Workspaces command exists", function()
    assert.is.truthy(vim.fn.exists(":Workspaces") == 2)
  end)

  it("shows usage for no args", function()
    vim.cmd("Workspaces")
    assert.is.truthy(#messages > 0)
    assert.match("Usage: :Workspaces <.*>", messages[1].msg)
    assert.are.equal(vim.log.levels.INFO, messages[1].level)
  end)

  it("shows usage for unknown subcommand", function()
    vim.cmd("Workspaces unknowncmd")
    assert.is.truthy(#messages > 0)
    assert.match("Unknown subcommand: unknowncmd", messages[1].msg)
    -- Should also show usage in the message
    assert.match("Usage: :Workspaces <.*>", messages[1].msg)
    assert.are.equal(vim.log.levels.ERROR, messages[1].level)
  end)

  it("includes all subcommands in usage", function()
    vim.cmd("Workspaces")
    local msg = messages[1].msg
    assert.match("add", msg)
    assert.match("remove", msg)
    assert.match("list", msg)
    assert.match("clear", msg)
    assert.match("save", msg)
    assert.match("switch", msg)
    assert.match("delete", msg)
    assert.match("rename", msg)
    assert.match("find", msg)
  end)

  it("executes valid subcommand (list)", function()
    vim.cmd("Workspaces list")
    -- list output should be INFO
    assert.is.truthy(#messages > 0)
    assert.match("No workspace folders", messages[1].msg) -- assuming empty state
    assert.are.equal(vim.log.levels.INFO, messages[1].level)
  end)
end)
