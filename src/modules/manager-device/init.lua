
local M = { }

M.name = "Device manager"
-- M.description = ""
M.depends = { }
M.config = {
    hostname = "hostname",
}

local SENSOR_LIST_CONFIG = "module.manager-device.local.sensors"

M.parameters = {
    [SENSOR_LIST_CONFIG]  = { mode = "merge", type = "string-table", default = { } },
}

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
