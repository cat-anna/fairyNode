

local function GetBaseTopic()
    return "homie/" .. (wifi.sta.gethostname() or string.format("%06x", node.chipid()))
end

local Module = { }
Module.__index = Module

local function HandleCommand(cmdLine, outputFunctor)
    if not cmdLine then
        return
    end
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
            self.mqtt:Publish(GetBaseTopic()  .. "/$cmd/output", line)
        end
    end
    HandleCommand(payload, output)
end

function Module:MqttEvent(topic, payload)
    local event_name =  nil
    local valid_arg = nil
    local arg = nil

    local coma_pos = payload:find(",")
    if coma_pos == nil then
        event_name = payload
    else
        event_name = payload:sub(1, coma_pos-1)
        arg_string = payload:sub(coma_pos+1)
        valid,arg = pcall(sjson.decode, arg_string)
        if not valid then
            return
        end
    end

    if Event then
        Event(event_name, arg)
    end
end

function Module:OnMqttConnected(event, mqtt)
    self.mqtt = mqtt
    local base = GetBaseTopic()
    mqtt:Subscribe({
        base .. "/$cmd",
        base .. "/$event"
    },self)
end

function Module:OnMqttMessage(topic, payload)
    local what = topic:match("homie/.-/(.+)")
    if what == "$cmd" then
        self:MqttCommand(topic, payload)
    elseif what == "$event" then
        self:MqttEvent(topic, payload)
    end
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
