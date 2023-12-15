
local M = { }

M.name = "Device manager"
-- M.description = ""
M.depends = { }
M.config = {
    hostname = "hostname",
}

M.parameters = {}

M.submodules = {
    ["manager-component"] = { mandatory = true, },
    ["manager-property"] = { mandatory = true, },

    ["service-device"] = { mandatory = false, },
    ["service-property"] = { mandatory = false, },
}

M.exported_config = {
    ["module.rest-server.endpoint.list"] = {
        "manager-device/endpoint-device",
        "manager-device/endpoint-property",
    }
}

return M
