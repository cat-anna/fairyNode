local sun_pos = require "lib/tools/sun-position"

-------------------------------------------------------------------------------

local CONFIG_KEY_LATITUDE = "location.latitude"
local CONFIG_KEY_LONGITUDE = "location.longitude"

-------------------------------------------------------------------------------

local DaylightSensor = {}
DaylightSensor.__base = "base/property/local-sensor"
DaylightSensor.__name = "DaylightSensor"
DaylightSensor.__type = "class"
DaylightSensor.__config = {
    [CONFIG_KEY_LATITUDE] = { type = "float", required = true },
    [CONFIG_KEY_LONGITUDE] = { type = "float", required = true },
}

-------------------------------------------------------------------------------

function DaylightSensor:ReadoutSlow()
    local config = self.config
    local moon = sun_pos.GetMoonPosition(config[CONFIG_KEY_LATITUDE], config[CONFIG_KEY_LONGITUDE])
    local moon_phase = sun_pos.GetMoonPhase()
    self:UpdateValues{
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
    self:UpdateValues{
        sun_azimuth = sun.azimuth,
        sun_altitude = sun.altitude,
    }
end

-------------------------------------------------------------------------------

function DaylightSensor.ProbeSensor(sensor_manager)
    local sensor = {
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

    return sensor
end

-------------------------------------------------------------------------------

return DaylightSensor
