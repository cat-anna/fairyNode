
local function topic2regexp(topic)
    return topic:gsub("+", "%%w-"):gsub("#", "%%.-")
end

local Module = {}
Module.__index = Module

function Module:OnOtaStart()
    tmr.create():alarm(10 * 1000, tmr.ALARM_SINGLE, function(t)
        self:Close()
        t:unregister()
    end)
end

function Module:OnWifiConnected()
    if self.post_services then
        self:Connect()
    end
end

-- function Module:OnWifiDisconnected()
    -- if self.post_services then
    --     self:Connect()
    -- end
-- end

function Module:OnPostServices()
    self.post_services = true

    if wifi.sta.getip() then
        self:Connect()
    end
end

Module.EventHandlers = {
    -- ["app.init.completed"] = self.PostInit,
    ["ota.start"] = Module.OnOtaStart,
    -- ["wifi.disconnected"] = Module.OnWifiDisconnected,
    ["wifi.connected"] = Module.OnWifiConnected,
    ["app.init.post-services"] = Module.OnPostServices,
}

function Module:Publish(topic, payload, retain, qos)
    payload = tostring(payload)

    if debugMode then
        print("MQTT: " .. topic .. " <- " .. (payload or "<NIL>"))
    end

    if not self.is_connected then
        print("MQTT: Publish: Not connected")
        return false
    end
    local r
    pcall(function()
        r = self.mqttClient:publish(topic, payload, qos or 0, retain and 1 or 0)
    end)
    if not r then
        print("MQTT: Publish failed")
    end
    return r
end

function Module:Subscribe(topics, handler)
    if not self.is_connected then
        print("MQTT: Subscribe: Not connected")
        return
    end

    if type(topics) == "string" then
        topics = { topics }
    end

    local subs = {}
    for _,v in ipairs(topics) do
        local regex = topic2regexp(v)
        subs[v] = 0
        self.subscriptions[v] = 0

        print("MQTT: Adding subscription to", v, regex)

        if self.handlers[regex] then
            print("MQTT: " .. regex .. " is already registered, replacing")
            -- self.handlers[regex] = { }
        end
        self.handlers[regex] = handler

        -- table.insert(self.handlers[regex], handler)
    end

    return self.mqttClient:subscribe(subs, function(client) print("MQTT: Subscription successful") end)
end

function Module:Unsubscribe(topics)
    if not self.is_connected then
        print("MQTT: Subscribe: Not connected")
        return
    end

    if type(topics) == "string" then
        topics = { topics }
    end

    local subs = {}
    for _,v in ipairs(topics) do
        local regex = topic2regexp(v)
        subs[v] = 0
        self.subscriptions[v] = nil

        -- print("MQTT: Unsubscribe ", v)

        self.handlers[regex] = nil
    end

    return self.mqttClient:unsubscribe(subs, function(client) print("MQTT: Unsubscription successful") end)
end

function Module:ProcessMessage(client, topic, payload)
    -- local base = "homie/" .. wifi.sta.gethostname()
    if debugMode then
        print("MQTT: " .. (topic or "<NIL>") .. " -> " .. (payload or "<NIL>"))
    end

    for regex, handler in pairs(self.handlers) do
        -- print("MQTT: Testing:", regex, topic)
        if topic:match(regex) then
            -- print("MQTT: Matched:", regex)
            pcall(handler.OnMqttMessage, handler, topic, payload)
            return
        end
    end

    print("MQTT: Cannot find handler for ", topic)
end

function Module:Disconnected(client)
    print("MQTT: Offline")
    if self.is_connected then
        self.is_connected = nil
        if Event then Event("mqtt.disconnected") end
        self:Reconnect()
    end
end

function Module:Connected(client)
    print("MQTT: Connected")
    self.is_connected = true

    for _,_ in pairs(self.subscriptions) do
        self.mqttClient:subscribe(self.subscriptions, function(client)
            print("MQTT: Resubscription successful")
        end)
        break
    end

    if Event then Event("mqtt.connected", self) end
end

function Module:Reconnect(client)
    if not self.is_connected then
        tmr.create():alarm(10 * 1000, tmr.ALARM_AUTO, function(t)
            if self.is_connected then
                t:unregister()
                return
            end
            self:Connect()
        end)
    end
end

function Module:HandleError(client, error)
    print("MQTT: error, code:", error)
    node.task.post(function ()
        self:Close()
        self:Reconnect()
    end)
end

function Module:Close()
    if self.mqttClient then
        print("MQTT: Closing connection")
        pcall(function()
            self.mqttClient:close()
        end)
        self.mqttClient = nil
        self.is_connected = nil
    end
end

function Module:Connect()
    if self.is_connected then
        return
    end
    print "MQTT: Connecting..."

    local cfg = require("sys-config").JSON("mqtt.cfg")
    if not cfg or not wifi.sta.gethostname() then
        print "MQTT: No configuration!"
        return
    end

    self:Close()
    collectgarbage()

    self.mqttClient = mqtt.Client(wifi.sta.gethostname(), 30, cfg.user, cfg.password)
    self.mqttClient:on("offline",  function(...) self:Disconnected(...) end)
    self.mqttClient:on("message", function(...) self:ProcessMessage(...) end)

    --todo:
    self.mqttClient:lwt("homie/" .. wifi.sta.gethostname() .. "/$state", "lost", 0, 1)

    self.mqttClient:connect(cfg.host, cfg.port or 1883,
        function(...) self:Connected(...) end,
        function(...) self:HandleError(...) end
    )
end

return {
    Init = function()
        local service = setmetatable({
            handlers = { },
            subscriptions = { },
        }, Module)
        return service
    end,
}
