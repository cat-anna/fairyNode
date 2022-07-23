local sun_pos = require "lib/sun_pos"

-------------------------------------------------------------------------------

local DaylightSensor = {}
DaylightSensor.__index = DaylightSensor

function DaylightSensor:SensorReadoutSlow(sensor)
    local moon = sun_pos.GetMoonPosition(self.latitude, self.longitude)
    local moon_phase = sun_pos.GetMoonPhase()
    sensor:UpdateAll{
        moon_phase = moon_phase.phase,
        moon_phase_fraction = moon_phase.fraction,
        moon_phase_angle = moon_phase.angle,
        moon_altitude = moon.altitude,
        moon_azimuth = moon.azimuth,
    }
end

function DaylightSensor:SensorReadoutFast(sensor)
    local sun = sun_pos.GetSunPosition(self.latitude, self.longitude)
    sensor:UpdateAll{
        sun_azimuth = sun.azimuth,
        sun_altitude = sun.altitude,
    }
end

-------------------------------------------------------------------------------

local CONFIG_KEY_LATITUDE = "server.location.latitude"
local CONFIG_KEY_LONGITUDE = "server.location.longitude"

-------------------------------------------------------------------------------

local Daylight = {}
Daylight.__index = Daylight
Daylight.__deps = {
    sensor_handler = "base/sensors",
}
Daylight.__config = {
    [CONFIG_KEY_LATITUDE] = { type = "float", default = 0 },
    [CONFIG_KEY_LONGITUDE] = { type = "float", default = 0 },
}

-------------------------------------------------------------------------------

function Daylight:LogTag()
    return "Daylight"
end

-------------------------------------------------------------------------------

function Daylight:BeforeReload() end

function Daylight:AfterReload()
    self:InitSensors(self.sensor_handler)
end

function Daylight:Init() end

-------------------------------------------------------------------------------

function Daylight:InitSensors(sensors)
    sensors:RegisterSensor{
        owner = self,
        handler = setmetatable({
            longitude = self.config[CONFIG_KEY_LONGITUDE],
            latitude = self.config[CONFIG_KEY_LATITUDE],
        }, DaylightSensor),
        name = "Daylight",
        id = "daylight",
        nodes = {
            -- fast
            sun_azimuth = { name = "Sun azimuth", datatype = "float" },
            sun_altitude = { name = "Sun altitude", datatype = "float" },

            -- slow
            moon_phase = { name = "Moon phase", datatype = "float" },
            moon_phase_fraction = { name = "Moon phase fraction", datatype = "float" },
            moon_phase_angle = { name = "Moon phase angle", datatype = "float" },
            moon_altitude = { name = "Moon altitude", datatype = "float" },
            moon_azimuth = { name = "Moon azimuth", datatype = "float" },
        }
    }
end

-------------------------------------------------------------------------------

return Daylight
