
local function GetWifiSignalQuality()
    local rssi = wifi.sta.getrssi() or (-100)
    local v = (rssi + 100) * 2
    if v > 100 then
        return 100
    end
    if v < 0 then
        return 0
    end
    return v
end

local Sensor = {}
Sensor.__index = Sensor

function Sensor:ControllerInit(event, ctl)
    self.node = ctl:AddNode("sysinfo", {
        name = "Device state info",
        properties = {
            heap = { name = "Free heap", datatype = "integer", unit = "B" },
            uptime = { name = "Uptime", datatype = "integer", value = 0 },
            wifi = { name = "Wifi signal quality", datatype = "float" },
            bootreason = { name = "Boot reason", datatype = "string", value = sjson.encode({node.bootreason()}) },
            bootcounter = rtcmem and { name = "Boot counter", datatype="integer", value=rtcmem.read32(120) } or nil,
            errors = { name = "Active errors", datatype = "string" },
            free_space = { name = "Free flash space", datatype = "integer" },
            event = { name = "Event", datatype = "string", value = "" },
            vdd = self.use_vdd and { name = "Supply voltage", datatype = "float" , unit = "mV" } or nil,
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

    if self.use_vdd then
        self.node:SetValue("vdd", tostring(adc.readvdd33(0)))
    end
end

function Sensor:UpdateErrors(event, arg)
    if not self.node then
        return
    end
    self.node:SetValue("errors", sjson.encode(arg.errors))
end

function Sensor:OnEvent(event, arg)
    if not self.node then
        return
    end
    if arg ~= nil and type(arg) ~= "table" then
        event = string.format("%s,%s", event, tostring(arg))
    end
    self.node:SetValue("event", event)
end

Sensor.EventHandlers = {
    ["controller.init"] = Sensor.ControllerInit,
    ["sensor.readout"] = Sensor.Readout,
    ["app.error"] = Sensor.UpdateErrors,
}

return {
    Init = function()
        local use_vdd = nil
        if hw and hw.adc and adc then
            use_vdd = hw.adc == "vdd"
            if use_vdd and adc.force_init_mode(adc.INIT_VDD33) then
              print("SYSINFO: Restarting to force adc vdd mode")
              node.restart()
              return -- don't bother continuing, the restart is scheduled
            end
        end
        return setmetatable({ use_vdd = use_vdd }, Sensor)
    end,
}
