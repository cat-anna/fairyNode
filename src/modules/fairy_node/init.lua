
local M = { }

M.name = "FairyNode core"
-- M.description = ""
M.mandatory = true
M.depends = { }
M.config = { }

local config = require("modules/fairy_node/config")
M.parameters = config.parameters

M.submodules = {
    ["event-bus"] = {
        mandatory = true,
    }
}

return M
