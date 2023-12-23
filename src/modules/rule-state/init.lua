
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
    ["service-rule"] = { mandatory = false, }
}

M.exported_config = {
    ["module.rest-server.endpoint.list"] = {
        "rule-state/endpoint-rule",
    }
}

return M
