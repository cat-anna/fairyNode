
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

    homie_prefix = "module.homie-host.prefix",
}

M.parameters = {
    [M.config.homie_prefix] = {  mode = "merge", type = "string-table", default = { "homie" } },
}

M.submodules = {
}

-- M.exported_config = {
-- ["module.rest-server.endpoint.list"] = {
-- }
-- }

return M
