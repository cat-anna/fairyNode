
local M = { }

M.name = "Server sensors"
-- M.description = ""
M.depends = {
    "manager-device",
}
M.config = { }

M.parameters = {
}

M.submodules = {
    ["health-monitor"] = { mandatory = true, },
}

-- M.exported_config = {
--     ["module.rest-server.endpoint.list"] = {
--     }
-- }

return M
