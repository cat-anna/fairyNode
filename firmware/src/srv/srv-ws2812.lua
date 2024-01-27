local Module = {}
Module.__index = Module

local function TranslateArgument(v)
    if v == "" then
        return nil
    end
    local n = tonumber(v)
    if n ~= nil then
        return n
    end
    return v
end

function Module:Reset()
    print("WS2812: Retting state")

    local conf = self.conf
    if conf.enabled then
        ws2812_effects.set_speed(conf.speed)
        ws2812_effects.set_brightness(conf.brightness)
        local r,g,b = conf.color:match("(%d+),(%d+),(%d+)")
        ws2812_effects.set_color(r,g,b)
        ws2812_effects.set_mode(conf.mode, TranslateArgument(conf.mode_argument))
        ws2812_effects.start()
    else
        ws2812_effects.stop()
        ws2812.write(string.rep(string.char(0, 0, 0), self.count))
    end
end

function Module:ImportValue(topic, payload, node_name, prop_name)
    if not  self.node then
        return
    end
    if self.conf[prop_name] ~= nil then
        if prop_name == "enabled" then
            self.conf.enabled = payload == "true"
            self.node:PublishValue(prop_name, payload)
            self:Reset()
            return
        elseif prop_name == "speed" or prop_name == "brightness" then
            self.conf[prop_name] = tonumber(payload)
        else
            self.conf[prop_name] = payload
        end
        self.node:PublishValue(prop_name, payload)
        if self.conf.enabled then
            self:Reset()
        end
    end
end

function Module:ControllerInit(event, ctl)
    self.node = ctl:AddNode(self, "ws2812", {
        name = "RGB LED",
        retained = true,
        settable = true,
        properties = {
            enabled = {
                datatype = "boolean",
                name = "Enabled",
                value = self.conf.enabled,
            },

            speed = {
                datatype = "integer",
                name = "Speed",
                value = self.conf.speed,
                format = "0:255",
            },
            brightness = {
                datatype = "integer",
                name = "Brightness",
                value = self.conf.brightness,
                format = "0:255",
            },

            color = {
                datatype = "rgb",
                name = "Color",
                value = self.conf.color,
                unit = "rgb",
            },
            mode = {
                datatype = "enum",
                name = "Mode",
                value = self.conf.mode,
                format = [==[["static","blink","gradient","gradient_rgb","random_color","rainbow","rainbow_cycle","flicker","fire","fire_soft","fire_intense","halloween","circus_combustus","larson_scanner","cycle","color_wipe","random_dot"]]==],
            },
            mode_argument = {
                datatype = "string",
                name = "Mode argument",
                value = self.conf.mode_argument,
            }
        }
    })
end

function Module:OnOtaStart()
    ws2812_effects.set_speed(100)
    ws2812_effects.set_brightness(10)
    ws2812_effects.set_color(0,255,0)
    ws2812_effects.set_mode("halloween")
    ws2812_effects.start()
end

function Module:SetEnabled(event, value)
    self:ImportValue(nil, value.state and "true" or "false", nil, "enabled")
end

Module.EventHandlers = {
    ["ota.start"] = Module.OnOtaStart,
    ["controller.init"] = Module.ControllerInit,
    ["ws2812.set_enabled"] = Module.SetEnabled
}

return {
    Init = function()
        if not hw or not hw.ws2812 or not ws2812 or not ws2812_effects then
            return
        end

        local hw_conf = hw.ws2812
        hw.ws2812 = nil

        local conf = {
            enabled = hw_conf.enabled or false,
            speed = hw_conf.speed or 100,
            brightness = hw_conf.brightness or 50,
            color = hw_conf.color or "0,0,0",
            mode = hw_conf.mode or "static",
            mode_argument = hw_conf.mode_argument or ""
        }

        ws2812.init(ws2812.MODE_SINGLE)
        ws2812_effects.init(ws2812.newBuffer(hw_conf.count, 3))

        local t = setmetatable({count = hw_conf.count, conf = conf}, Module)
        t:Reset()
        return t
    end
}
