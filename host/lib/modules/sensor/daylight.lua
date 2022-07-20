-- local copas = require "copas"
-- local lfs = require "lfs"
-- local file = require "pl.file"
-- local json = require "json"
local sun_pos = require "lib/sun_pos"

-------------------------------------------------------------------------------

local CONFIG_KEY_LATITUDE = "server.location.latitude"
local CONFIG_KEY_LONGITUDE = "server.location.longitude"

-------------------------------------------------------------------------------

local Daylight = {}
Daylight.__index = Daylight
Daylight.__deps = {
    event_bus = "base/event-bus",
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

function Daylight:BeforeReload()
end

function Daylight:AfterReload()
    self:InitSensors(self.sensor_handler)
end

function Daylight:Init()
end

function Daylight:InitSensors(sensors)
    self.daylight_sensor = sensors:RegisterSensor{
        owner = self,
        name = "Daylight",
        id = "daylight",
        nodes = {
            sun_azimuth = { name = "Sun azimuth", datatype = "float" },
            sun_altitude = { name = "Sun altitude", datatype = "float" },

            moon_phase = { name = "Moon phase", datatype = "float" },
            moon_phase_fraction = { name = "Moon phase fraction", datatype = "float" },
            moon_phase_angle = { name = "Moon phase angle", datatype = "float" },
            moon_altitude = { name = "Moon altitude", datatype = "float" },
            moon_azimuth = { name = "Moon azimuth", datatype = "float" },
        }
    }

    self:MoonReadout()
    self:SunReadout()
end

-------------------------------------------------------------------------------

function Daylight:MoonReadout()
    if self.daylight_sensor then
        local longitude = self.config[CONFIG_KEY_LONGITUDE]
        local latitude = self.config[CONFIG_KEY_LATITUDE]
        local moon = sun_pos.GetMoonPosition(latitude, longitude)
        local moon_phase = sun_pos.GetMoonPhase()
        self.daylight_sensor:SetAll{
            moon_phase = moon_phase.phase,
            moon_phase_fraction = moon_phase.fraction,
            moon_phase_angle = moon_phase.angle,
            moon_altitude = moon.altitude,
            moon_azimuth = moon.azimuth,
        }
    end
end

function Daylight:SunReadout()
    if self.daylight_sensor then
        local longitude = self.config[CONFIG_KEY_LONGITUDE]
        local latitude = self.config[CONFIG_KEY_LATITUDE]
        local sun = sun_pos.GetSunPosition(latitude, longitude)
        self.daylight_sensor:SetAll{
            sun_azimuth = sun.azimuth,
            sun_altitude = sun.altitude,
        }
    end
end

-------------------------------------------------------------------------------

Daylight.EventTable = {
    ["timer.sensor.readout.fast"] = Daylight.SunReadout,
    ["timer.sensor.readout.normal"] = Daylight.MoonReadout,
}

return Daylight
