local statemachine = require('fairy_node/tools/statemachine')
local homie_state = require("modules/homie-common/homie-state")
local scheduler = require "fairy_node/scheduler"
local loader_class = require "fairy_node/loader-class"

-------------------------------------------------------------------------------

local fsm = statemachine.Create({
    initial = "New",

    events = {
        { name = 'MqttDisconnected',    from = '*',                 to = "WaitForMqtt" },
        { name = 'MqttConnected',       from = 'WaitForMqtt',       to = homie_state.init },
        { name = 'Start',               from = 'New',               to = "WaitForMqtt" },
        { name = "InitCompleted",       from = homie_state.init,    to = homie_state.ready },
        { name = "Reset",               from = homie_state.ready,   to = "WaitForInit" },
        { name = "InitDelayCompleted",  from = "WaitForInit",       to = homie_state.init}
    }
})

fsm.__tag = "HomieClientState"

-------------------------------------------------------------------------------

function fsm:OnStateChange(event, from, to)
    print(self, "State change:", from, "->", to)
    -- if homie_state[self.current] then
    --     self.homie_client:Publish("$state", self.current)
    -- end
end

-------------------------------------------------------------------------------

function fsm:OnBeforeMqttDisconnected(name, from, to)
    return from ~= 'New'
end

-- function fsm:OnBeforeMqttConnected(name, from, to) end

function fsm:OnMqttConnected(name, from, to)
    -- self.state_machine:MqttDisconnected()
    print(self, "Mqtt connected")
    self.mqtt_connected = true
end

function fsm:OnMqttDisconnected(name, from, to)
    print(self, "Mqtt disconnected")
    self.mqtt_connected = false
end

-------------------------------------------------------------------------------

-- function fsm:OnStart()
    -- print(self, "Mqtt disconnected")
    -- self.mqtt_connected = false
-- end

-------------------------------------------------------------------------------

function fsm:OnEnterWaitForInit()
    print(self, "Delaying entering init")
    self.homie_client:Publish("$state", homie_state.init)
    scheduler.Delay(10, function () self:InitDelayCompleted() end)
end

function fsm:OnEnterInit()
    print(self, "Initializing nodes")
    self.homie_client:Publish("$state", homie_state.init)
    self.homie_client:ResetProxies()
    self.homie_client:SendInitMessages()
end

function fsm:OnEnterReady()
    print(self, "Client entered ready state")
    self.homie_client:Publish("$state", homie_state.ready)
end

-------------------------------------------------------------------------------

return fsm
