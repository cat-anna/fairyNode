local statemachine = require('fairy_node/tools/statemachine')
local homie_state = require("modules/homie-common/homie-state")
local scheduler = require "fairy_node/scheduler"
local loader_class = require "fairy_node/loader-class"

-------------------------------------------------------------------------------

local fsm = statemachine.Create({
    initial = "New",
    events = {
        { name = 'Start',               from = 'New',               to = "WaitForMqtt" },

        { name = "Reset",               from = "*",                 to = "WaitForInit" },
        { name = "WaitForInitDone",     from = "WaitForInit",       to = "InitProtocol", },

        { name = 'MqttDisconnected',    from = '*',                 to = "WaitForMqtt" },
        { name = 'MqttConnected',       from = 'WaitForMqtt',       to = "InitProtocol" },

        { name = "SendCompleted",       from = "InitProtocol",      to =  "InitInfo", },
        { name = "SendCompleted",       from = "InitInfo",          to =  "WaitForProxies", },
        { name = "SendCompleted",       from = "WaitForProxies",      to =  "ProtocolReady", },
        { name = "SendCompleted",       from = "ProtocolReady",      to =  "Ready", },
    }
})

fsm.__tag = "HomieClientState"

-------------------------------------------------------------------------------

function fsm:QueueEvent(event)
    if self.verbose then
        print(self, "Queueing event", event)
    end
    scheduler.CallLater(function () self[event](self) end)
end

local ProcessingStatus = {
    Done = 1,
    Continue = 2,
}

function fsm:StartProcessingTask(interval)
    interval = interval or 1

    if not self.has_processing_task then
        self.has_processing_task = true
        scheduler.CallLater(function ()
            local status = ProcessingStatus.Continue
            while status == ProcessingStatus.Continue do
                scheduler.Sleep(interval)

                if self:CanProcess() then
                    status = self:Process()
                else
                    print(self, "ERROR! Current state does not have process method:", self.current)
                end
            end
            self.has_processing_task = nil
        end)
    end
end

-------------------------------------------------------------------------------

function fsm:OnStateChange(event, from, to)
    if self.verbose then
        print(self, "State change:", from, "->", to, "event:" .. event)
    end
end

-------------------------------------------------------------------------------

function fsm:OnStart()
    print(self, "Starting")
    self.mqtt_connected = false
    self.verbose = true
end

function fsm:OnBeforeReset(name, from, to)
    local valid = from ~= 'New' and to ~= from
    self.last_reset_time = os.timestamp()

    if not valid then
        return false
    end

    print(self, "Resetting protocol state")
    return true
end

-------------------------------------------------------------------------------

function fsm:OnEnterWaitForInit()
    print(self, "Waiting before init")
    self:StartProcessingTask()
end

function fsm:ProcessWaitForInit()
    if self.verbose then
        print(self, "Waiting before init")
    end
    local timeout = (os.timestamp() - self.last_reset_time) > 10
    if not timeout then
        return ProcessingStatus.Continue
    end

    self:QueueEvent("WaitForInitDone")
    return ProcessingStatus.Done
end

-------------------------------------------------------------------------------

function fsm:OnBeforeMqttDisconnected(name, from, to)
    return from ~= 'New'
end

function fsm:OnMqttConnected(name, from, to)
    print(self, "Mqtt connected")
    self.mqtt_connected = true
end

function fsm:OnMqttDisconnected(name, from, to)
    print(self, "Mqtt disconnected")
    self.mqtt_connected = false
end

-------------------------------------------------------------------------------

function fsm:OnEnterInitProtocol()
    print(self, "Initializing protocol")
    self.homie_client:SendProtocolState(homie_state.init)
end

-------------------------------------------------------------------------------

function fsm:OnEnterInitInfo()
    print(self, "Sending basic device info")
    self.homie_client:SendInfoMessages()
end

-------------------------------------------------------------------------------

function fsm:OnEnterWaitForProxies()
    print(self, "Waiting for proxies")
    self:StartProcessingTask()
end

function fsm:ProcessWaitForProxies()
    if self.verbose then
        print(self, "Waiting for proxies")
    end
    local has_proxies = self.homie_client:ResetProxies()

    if not has_proxies then
        return ProcessingStatus.Continue
    end

    self.homie_client:SendNodeMessages()

    return ProcessingStatus.Done
end

-------------------------------------------------------------------------------

function fsm:OnEnterProtocolReady()
    print(self, "Protocol entered ready state")
    self.homie_client:SendProtocolState(homie_state.ready)
end

-------------------------------------------------------------------------------

function fsm:OnEnterReady()
    print(self, "Entered ready state")
end

-------------------------------------------------------------------------------

return fsm
