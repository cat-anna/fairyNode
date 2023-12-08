local Configuration = {}
Configuration.set = {}
local set = Configuration.set

-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------

set.ntp = { --
    host = "host.lan",
}
set.wifi = { --
    ssid = "ssid",
    pwd = "password"
}
set.rest = { --
    host = "host.lan",
    port = 8000,
}
set.sensor = { --
    interval = 5 * 60
}
set.mqtt = { --
    host = "host.lan",
    user = "user",
    password = "password"
}

-------------------------------------------------------------------------------------

-- Configuration.overlay = {
--     debug = {
--         rest = { --
--             host = "devhost.lan",
--             port = 8000
--         }
--     }
-- }

-------------------------------------------------------------------------------------

Configuration.default_set = { --
    "wifi", "rest", "mqtt", "sensor", "ntp"
}

local M = {}

function M:Register(reg)
    -- reg:AttachConfiguration(Configuration)

    -- reg:UniqueDevice{device_id = "..", project = "..", name=".."}

    -- reg:AddDevice{project="..", chips={
    --     [".."] = "..",
    -- }}

    -- -- Configuration:Device { }
end

-------------------------------------------------------------------------------------

return M
