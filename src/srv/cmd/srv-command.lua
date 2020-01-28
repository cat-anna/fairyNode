

local function GetTopic()
    return "homie/" .. (wifi.sta.gethostname() or string.format("%06x", node.chipid())) .. "/$cmd"
end

local Module = { }
Module.__index = Module

local function HandleCommand(cmdLine, outputFunctor)
    local args = {}
    for k in (cmdLine .. ","):gmatch("([^,]*),") do  
        table.insert(args, k)
    end

    local cmdName = table.remove(args, 1)
    local s, m = pcall(require, "cmd-" .. cmdName)
    if not s then
        print("CMD: Unknown command or script load failed: ", cmdLine)
        return
    end

    pcall(m.Execute, args, outputFunctor, cmdLine)
end

function Module:MqttCommand(topic, payload)
    local output = function(line)
        if self.mqtt then
            self.mqtt:Publish(GetTopic() .. "/output", line)
        end
    end
    HandleCommand(payload, output)
end

function Module:OnMqttConnected(event, mqtt)
    self.mqtt = mqtt
    mqtt:Subscribe(GetTopic(), function(...) self:MqttCommand(...) end)
end

function Module:OnMqttDisconnected()
    self.mqtt = nil
end

Module.EventHandlers = {
    ["mqtt.connected"] = Module.OnMqttConnected,
    ["mqtt.disconnected"] = Module.OnMqttDisconnected,
}

return {
    Init = function()
        function Command(cmdline, out)
            node.task.post(function()
                HandleCommand(cmdline, out or print)
            end)
        end
        return setmetatable({}, Module)
    end,
}
