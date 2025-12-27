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

    it("strips block comments", function()
      local input = [[{
  /* this is a
     block comment */
  "key": "value"
}]]
      local result = jsonc.strip_comments(input)
      assert.is_nil(result:find("/*", 1, true))
      assert.is_nil(result:find("*/", 1, true))
      assert.is_not_nil(result:find('"key"'))
    end)
  end)

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
end)
