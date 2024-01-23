
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

    homie_prefix  = "module.homie-client.prefix",
}

M.parameters = {
    [M.config.homie_prefix] = { type = "string", default = "homie", },
}

M.submodules = {
}

-- M.exported_config = {
    -- ["module.rest-server.endpoint.list"] = {
    -- }
-- }

return M
