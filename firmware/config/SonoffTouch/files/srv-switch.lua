
local Module = {}
Module.__index = Module

function Module:Reset()
    print("SWITCH: Setting state:", self.relay)

    local led = require("sys-led")
    led.Set("relay", self.relay)
    led.Set("blue", not self.relay)
end

function Module:ImportValue(topic, payload, node_name, prop_name)
    if prop_name == "relay" then
        self:SetValue(prop_name, payload == "true")
    end
end

function Module:ControllerInit(event, ctl)
    self.node = ctl:AddNode(self, "switch", {
        name = "Switch",
        properties = {
            relay = {
                datatype = "boolean",
                name = "Relay",
                value = false,
                settable = true,
                retained = true,
            },
        },
    })
end

function Module:HandleButton(id, arg)
    if arg.value == 1 then
        self:SetValue("relay", not self.relay)
    end
end

function Module:SetValue(name, value)
    print("SWITCH: Set value", name, value)
    self.node:PublishValue(name, value, true)

    if self[name] ~= value then
        self[name] = value
        self.node:StoreValue(name, value, true)
    end

    self:Reset()
end

Module.EventHandlers = {
    ["gpio.button"] = Module.HandleButton,
    ["controller.init"] = Module.ControllerInit,
}

return {
    Init = function()
        local obj = setmetatable({
            relay = false,
        }, Module)
        obj:Reset()
        return obj
    end,
}
