local file = require "pl.file"
local lfs = require "lfs"

-------------------------------------------------------------------------------

local Thermal = {}
Thermal.__base = "base/property/local-property"
Thermal.__deps = { }
Thermal.__config = { }
Thermal.__type = "class"

-------------------------------------------------------------------------------

function Thermal:Tag()
    return "SysThermal"
end

-------------------------------------------------------------------------------

function Thermal:InitThermalNode(client)
    self.thermal_props = {}

    if lfs.attributes("/sys/class/thermal") then
        self.thermal_node = client:AddNode("thermal", {
            ready = true,
            name = "Temperatures",
            properties = self.thermal_props
        })
    else
        self.thermal_node = nil
        print("SYSINFO: /sys/class/thermal does not exist")
    end
end

function Thermal:ReadSensors()
    if self.thermal_node then
        for id, e in pairs(self.thermal_props) do
            self.thermal_node:SetValue(id, string.format("%.1f", tonumber(file.read(e._read_path)) / 1000))
        end
    end
end

-------------------------------------------------------------------------------

local function FindThermalSensors()
    local thermal_props = {}
-- sensors -j  ??
    if lfs.attributes("/sys/class/thermal") then
        for entry in lfs.dir("/sys/class/thermal") do
            if entry:match("thermal_zone%d+") then
                local base_path = "/sys/class/thermal/" .. entry
                local e = {
                    name = file.read(base_path .. "/type"),
                    unit = "C",
                    datatype = "float",
                    read_path = base_path .. "/temp",
                    scale = (1 / 1000),
                }
                table.insert(thermal_props, e)
            end
        end
    end
    return thermal_props
end

function Thermal:ProbeSensor(manager)

    local sensors = FindThermalSensors()
    if #sensors == 0 then
        return
    end

        -- self.thermal_node = client:AddNode("thermal", {
        --     ready = true,
        --     name = "Temperatures",
        --     properties = self.thermal_props
        -- })

    -- manager:RegisterSensor{
    --     owner = self,

    --     class = DaylightSensor,

    --     name = "Daylight",
    --     id = "daylight",
    --     values = {
    --         -- fast
    --         sun_azimuth = { datatype = "float", name = "Sun azimuth", },
    --         sun_altitude = { datatype = "float", name = "Sun altitude", },
    --         -- slow
    --         moon_phase = { datatype = "float", name = "Moon phase", },
    --         moon_phase_fraction = { datatype = "float", name = "Moon phase fraction", },
    --         moon_phase_angle = { datatype = "float", name = "Moon phase angle", },
    --         moon_altitude = { datatype = "float", name = "Moon altitude", },
    --         moon_azimuth = { datatype = "float", name = "Moon azimuth", },
    --     }
    -- }
end

-------------------------------------------------------------------------------

return Thermal
