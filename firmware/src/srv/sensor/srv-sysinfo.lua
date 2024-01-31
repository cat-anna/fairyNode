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
    self.node = ctl:AddNode(self, "sysinfo", {
        name = "Device state info",
        -- retain = false,
        properties = {
            heap = {
                name = "Free heap",
                datatype = "integer",
                unit = "B",
            },
            uptime = {
                name = "Uptime",
                datatype = "integer",
                value = 0
            },
            wifi = {
                name = "Wifi signal quality",
                datatype = "float",
            },
            bootreason = {
                name = "Boot reason",
                datatype = "string",
                value = sjson.encode({ node.bootreason() })
            },
            bootcounter = rtcmem and {
                name = "Boot counter",
                datatype = "integer",
                value = rtcmem.read32(120)
            } or nil,
            errors = {
                name = "Active errors",
                datatype = "string",
                value = "{}",
            },
            free_space = {
                name = "Free flash space",
                datatype = "integer"
            },
            event = {
                name = "Event",
                datatype = "string",
                value = ""
            },
            vdd = self.vdd and {
                name = "Supply voltage",
                datatype = "float",
                unit = "mV"
            } or nil,
        }
    })
end

function Sensor:Readout(event, sensors)
    if not self.node then
        return
    end
    local flash_remaining = file.fsinfo()

    self.node:PublishValue("free_space", tostring(flash_remaining))
    self.node:PublishValue("heap", tostring(node.heap()))
    self.node:PublishValue("uptime", tostring(tmr.time()))
    self.node:PublishValue("wifi", tostring(GetWifiSignalQuality()))

    if self.vdd then
        self.node:PublishValue("vdd", tostring(adc.readvdd33(0)))
    end
end

function Sensor:UpdateErrors(event, arg)
    if self.node then
        self.node:PublishValue("errors", sjson.encode(arg.errors))
    end
end

function Sensor:OnEvent(event, arg)
    if not self.node then
        return
    end
    if arg ~= nil and type(arg) ~= "table" then
        event = string.format("%s,%s", event, tostring(arg))
    end
    self.node:PublishValue("event", event)
end

Sensor.EventHandlers = {
    ["controller.init"] = Sensor.ControllerInit,
    ["sensor.readout"] = Sensor.Readout,
    ["app.error"] = Sensor.UpdateErrors,
}

return {
    Init = function()
        local vdd = nil
        if hw and adc then
            vdd = (hw.adc == "vdd" or hw.adc == nil)
            if vdd and adc.force_init_mode(adc.INIT_VDD33) then
                print("SYSINFO: Restarting to force adc vdd mode")
                node.restart()
                return -- don't bother continuing, the restart is scheduled
            end
            hw.adc = nil
        end
        return setmetatable({ vdd = vdd }, Sensor)
    end,
}
