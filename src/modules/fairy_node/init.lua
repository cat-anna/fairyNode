
local M = { }

M.name = "FairyNode core"
-- M.description = ""
M.mandatory = true
M.depends = { }
M.config = { }

local config = require("modules/fairy_node/config")
M.config = config.config
M.parameters = config.parameters

M.submodules = {
    ["event-bus"] = { mandatory = true, },
    ["error-manager"] = { mandatory = true, },

    ["storage"] = { mandatory = false, }
}

return M
