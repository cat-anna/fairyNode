
local function GetWifiSignalQuality()
    local v = (wifi.sta.getrssi() + 100) * 2
    if v > 100 then
        return 100
    end 
    if v < 0 then
        return 0
    end
    return v
end

-- local VddSensorEnabled = false

-- local function IsVddSensorEnabled()
--     if adc then 
--         -- TODO
--         return not adc.force_init_mode(adc.INIT_VDD33)
--     else
--         return false
--     end 
-- end

-- local function GetVddPropConfig()
--     if not IsVddSensorEnabled() then
--         return nil
--     end

--     return { name = "Supply voltage", datatype = "float" , unit = "V"}
-- end

local Sensor = {}
Sensor.__index = Sensor

function Sensor:ContrllerInit(event, ctl)
    self.node = ctl:AddNode("sysinfo", {
        name = "Device state info",
        properties = {
            heap = { name = "Free heap", datatype = "integer", unit = "#" },
            uptime = { name = "Uptime", datatype = "integer", value = 0 },
            wifi = { name = "Wifi signal quality", datatype = "float" },
            bootreason = { name = "Boot reason", datatype = "string", value = sjson.encode({node.bootreason()}) },
            errors = { name = "Active errors", datatype = "string" },
            free_space = { name = "Free flash space", datatype = "integer" },
            last_event = { name = "Last event", datatype = "string", value = "" },
            -- vdd = GetVddPropConfig(),
        }
    })
end

function Sensor:Readout(event, sensors)
    if not self.node then
        return
    end
    local flash_remaining = file.fsinfo()
    
    self.node:SetValue("free_space", tostring(flash_remaining))
    self.node:SetValue("heap", tostring(node.heap()))
    self.node:SetValue("uptime", tostring(tmr.time()))
    self.node:SetValue("wifi", tostring(GetWifiSignalQuality()))

    -- if IsVddSensorEnabled() then
    --     local v = string.format("%.3f", adc.readvdd33(0) / 1000)
    --     HomiePublishNodeProperty("supplyvoltage", "voltage", v)
    -- end
end

function Sensor:UpdateErrors(event, arg)
    if not self.node then
        return
    end
    self.node:SetValue("errors", sjson.encode(arg.errors))
end

function Sensor:OnEvent(event)
    if not self.node then
        return
    end    
    self.node:SetValue("last_event", event)
end

Sensor.EventHandlers = {
    ["controller.init"] = Sensor.ContrllerInit,
    ["sensor.readout"] = Sensor.Readout,
    ["app.error"] = Sensor.UpdateErrors,
}

return {
    Init = function()
        return setmetatable({}, Sensor)
    end,
}
