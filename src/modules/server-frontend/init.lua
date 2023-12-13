
local M = { }

M.name = "Server frontend"
-- M.description = ""
M.depends = {
    "server-rest",
    "manager-device",
}
M.config = { }

M.parameters = {
}

M.submodules = {
    ["service-status"] = { mandatory = false, },
}

M.exported_config = {
    ["module.rest-server.endpoint.list"] = {
        "server-frontend/endpoint-dashboard",
        "server-frontend/endpoint-status",
    }
}

return M
