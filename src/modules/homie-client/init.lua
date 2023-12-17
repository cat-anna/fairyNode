
local M = { }

M.name = "Homie client"
-- M.description = ""
M.depends = {
    "manager-device",
    "mqtt-client",
    "homie-common",
}
M.config = {
    hostname = "hostname",
}

M.parameters = {}
M.submodules = {
}

-- M.exported_config = {
    -- ["module.rest-server.endpoint.list"] = {
    -- }
-- }

return M
