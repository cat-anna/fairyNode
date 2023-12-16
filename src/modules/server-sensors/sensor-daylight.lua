local sun_pos = require "fairy_node/tools/sun-position"

-------------------------------------------------------------------------------

local DaylightSensor = {}
DaylightSensor.__base = "modules/manager-device/local/local-sensor"
DaylightSensor.__tag = "DaylightSensor"
DaylightSensor.__type = "class"
DaylightSensor.__config = {
    latitude = "location.latitude",
    longitude = "location.longitude",
}

-------------------------------------------------------------------------------

function DaylightSensor:Readout(skip_slow)
    local update = { }
    local config = self.config

    local sun = sun_pos.GetSunPosition(config.latitude, config.longitude)
    update.sun_azimuth = sun.azimuth
    update.sun_altitude = sun.altitude

    if not skip_slow then
        local moon = sun_pos.GetMoonPosition(config.latitude, config.longitude)
        local moon_phase = sun_pos.GetMoonPhase()
        update.moon_phase = moon_phase.phase
        update.moon_phase_fraction = moon_phase.fraction
        update.moon_phase_angle = moon_phase.angle
        update.moon_altitude = moon.altitude
        update.moon_azimuth = moon.azimuth
    end

    self:UpdateValues(update)
end

-------------------------------------------------------------------------------

function DaylightSensor:ProbeSensor()
    local config = self.config or { }
    if (not config.latitude) or (not config.longitude) then
        warning(self, "No server location defined")
        return
    end

    return {
        name = "Daylight",
        id = "daylight",
        volatile = true,
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

return DaylightSensor
