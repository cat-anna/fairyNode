
local M = { }

M.name = "Homie host"
-- M.description = ""
M.depends = {
    "manager-device",
    "mqtt-client",
    "homie-client",
    "homie-common",
}
M.config = {
    hostname = "hostname",
}

M.parameters = {
}

M.submodules = {
-- ["server"] = { mandatory = true, },
}

-- M.exported_config = {
-- ["module.rest-server.endpoint.list"] = {
-- }
-- }

return M
