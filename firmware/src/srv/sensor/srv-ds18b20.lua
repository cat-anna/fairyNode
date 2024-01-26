
local function FormatAddress(addr)
    return ('%02X%02X%02X%02X%02X%02X%02X%02X'):format(addr:byte(1,8))
end

local function ReadConfig()
    return require("sys-config").JSON("ds18b20.cfg")
end


local Sensor = {}
Sensor.__index = Sensor

function Sensor:ReadCallback(temp_list, sensors)
    local dscfg = ReadConfig() or {}

    local unknown = { }
    local values = {}
    for addr, temp in pairs(temp_list or {}) do
        local addr_str = FormatAddress(addr)
        print(string.format("SENSOR: ds18b20 %s = %s C", addr_str, temp))
        local name = dscfg[addr_str]
        dscfg[addr_str] = nil
        if not name then
            if SetError then
                SetError("ds18b20." .. addr_str, "Device has no name")
            end
            print("DS18B20:", addr_str, ": Device has no name")
            unknown[addr_str] = temp
            name = addr_str
        else
            self.node:PublishValue(name, tostring(temp))
        end
        values[name] = temp
        if Event then
            Event("ds18b20." .. name, {value = temp})
        end
    end

    sensors.ds18b20 = values
    -- self.node:PublishValue("_unknown", sjson.encode(unknown))
    -- self.node:PublishValue("_missing", sjson.encode(dscfg))

    for id,name in pairs(dscfg) do
        print("DS18B20: " .. id .. "=" .. name .. ": Device not found")
        if SetError then
            SetError("ds18b20." .. id, name .. ": Device not found")
        end
    end
end

function Sensor:ContrllerInit(event, ctl)
    local props = {
        -- _unknown = { name = "Unkown sensors", datatype = "json" },
        -- _missing = { name = "Missing sensors", datatype = "json" },
    }
    for k,v in pairs(ReadConfig() or {}) do
        props[v] = { name = v, datatype = "float", unit="C", id=k }
    end

    self.node = ctl:AddNode("ds18b20", {
        name = "Temperature sensors",
        properties = props
    })
end

function Sensor:Readout(event, sensors)
    if not self.node then
        return
    end

    -- local routime = coroutine.running()
    local function readout(temp)
       self:ReadCallback(temp, sensors)
    end

    local ds18b20 = require "ds18b20"
    ds18b20:read_temp(readout, hw.ow, ds18b20.C)
    -- local temp_list = coroutine.yield()
end

function Sensor:UpdateErrors(event, arg)
    -- if not self.node then
    --     return
    -- end
    -- self.node:PublishValue("errors", sjson.encode(arg.errors))
end

Sensor.EventHandlers = {
    ["controller.init"] = Sensor.ContrllerInit,
    ["sensor.readout"] = Sensor.Readout,
    ["app.error"] = Sensor.UpdateErrors,
}

return {
    Init = function()
        if ReadConfig() then
            return setmetatable({ }, Sensor)
        end
    end,
}
