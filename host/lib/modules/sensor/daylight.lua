local sun_pos = require "lib/sun_pos"

-------------------------------------------------------------------------------

local CONFIG_KEY_LATITUDE = "server.location.latitude"
local CONFIG_KEY_LONGITUDE = "server.location.longitude"

-------------------------------------------------------------------------------

local DaylightSensor = {}
DaylightSensor.__base = "base/property-object-base"
DaylightSensor.__config = {
    [CONFIG_KEY_LATITUDE] = { type = "float", default = 0 },
    [CONFIG_KEY_LONGITUDE] = { type = "float", default = 0 },
}

function DaylightSensor:Tag()
    return "DaylightSensor"
end

function DaylightSensor:ReadoutSlow()
    local config = self.config
    local moon = sun_pos.GetMoonPosition(config[CONFIG_KEY_LATITUDE], config[CONFIG_KEY_LONGITUDE])
    local moon_phase = sun_pos.GetMoonPhase()
    self:UpdateAll{
        moon_phase = moon_phase.phase,
        moon_phase_fraction = moon_phase.fraction,
        moon_phase_angle = moon_phase.angle,
        moon_altitude = moon.altitude,
        moon_azimuth = moon.azimuth,
    }
end

function DaylightSensor:ReadoutFast()
    local config = self.config
    local sun = sun_pos.GetSunPosition(config[CONFIG_KEY_LATITUDE], config[CONFIG_KEY_LONGITUDE])
    self:UpdateAll{
        sun_azimuth = sun.azimuth,
        sun_altitude = sun.altitude,
    }
end

-------------------------------------------------------------------------------

local Daylight = {}

function Daylight:Tag()
    return "Daylight"
end

function Daylight:InitProperties(manager)
    manager:RegisterSensor{
        owner = self,

        class = DaylightSensor,

        name = "Daylight",
        id = "daylight",
        values = {
            -- fast
            sun_azimuth = { datatype = "float", name = "Sun azimuth", },
            sun_altitude = { datatype = "float", name = "Sun altitude", },
            -- slow
            moon_phase = { datatype = "float", name = "Moon phase", },
            moon_phase_fraction = { datatype = "float", name = "Moon phase fraction", },
            moon_phase_angle = { datatype = "float", name = "Moon phase angle", },
            moon_altitude = { datatype = "float", name = "Moon altitude", },
            moon_azimuth = { datatype = "float", name = "Moon azimuth", },
        }
    }
end

-------------------------------------------------------------------------------

return Daylight
