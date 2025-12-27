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
