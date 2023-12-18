
local M = { }

M.name = "State rules"
-- M.description = ""
M.depends = { }
M.config = {
}

M.parameters = {
}

M.submodules = {
    -- ["server"] = { mandatory = true, },
}

M.exported_config = {
    ["module.rest-server.endpoint.list"] = {
--         "server-rest/endpoint-rule",
    }
}

return M
