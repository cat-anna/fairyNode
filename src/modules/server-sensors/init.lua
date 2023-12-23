
local M = { }

M.name = "Server sensors"
-- M.description = ""
M.depends = { }
M.config = {
    latitude = "location.latitude",
    longitude = "location.longitude",
}

M.parameters = { }

M.submodules = {
    ["health-monitor"] = { mandatory = true, },
    -- ["sensor-daylight"] = { mandatory = true, },
}

M.exported_config = {
    ["module.manager-device.local.sensors"] = {
        "server-sensors/sensor-daylight",
    }
}

return M
