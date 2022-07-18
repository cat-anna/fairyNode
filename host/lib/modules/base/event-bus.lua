local copas = require "copas"

-------------------------------------------------------------------------------

local CONFIG_KEY_EVENT_BUS_LOG_ENABLE = "module.event-bus.log.enable"

-------------------------------------------------------------------------------

local EventBus = {}
EventBus.__index = EventBus
EventBus.__deps = {
    loader_module = "base/loader-module",
    loader_class = "base/loader-class",
}
EventBus.__config = {
    -- [CONFIG_KEY_EVENT_BUS_LOG_ENABLE] = { type = "boolean", default = false },
}

-------------------------------------------------------------------------------

function EventBus:LogTag()
    return "EventBus"
end

function EventBus:BeforeReload()
end

function EventBus:AfterReload()
    self.event_queue = {}
    self.process_thread = nil

    self.loader_module:RegisterWatcher(self:LogTag(), self)
    self.loader_class:RegisterWatcher(self:LogTag(), self)

    if not self.process_thread then
        self.process_thread = copas.addthread(function()
            while true do
                copas.sleep(0.1)
                SafeCall(function() self:ProcessAllEvents() end)
            end
        end)
    end
end

function EventBus:Init()
    self.notify_once = { }
    self.subscriptions = setmetatable({ }, { __mode="vk" })
    self.logger = require("lib/logger"):New("event-bus", CONFIG_KEY_EVENT_BUS_LOG_ENABLE)
end

function EventBus:AllModulesLoaded()
    self:PushEvent({ event = "module.load_complete", })

    if not self.notify_once.app_start then
        self:PushEvent({ event = "app.start", })
        self.notify_once.app_start = true
    end
end

function EventBus:ModuleReloaded(module_name)
    self:PushEvent({
        event = "module.reloaded",
        argument = { name = module_name }
    })
end

function EventBus:AllModulesInitialized()
    self:PushEvent({
        event = "module.initialized",
        argument = {  }
    })
end

function EventBus:OnObjectCreated(class_name, object)
    self.subscriptions[object.uuid] = object
end

function EventBus:PushEvent(event_info)
    if self.config.debug and not event_info.silent then
        print(self,"Push event " .. event_info.event)
    end
    event_info.timestamp_queued = os.gettime()
    table.insert(self.event_queue, event_info)
end

function EventBus:ProcessAllEvents()
    while #self.event_queue > 0 do
        self:ProcessEvent(table.remove(self.event_queue, 1))
    end
end

function EventBus:ProcessEvent(event_info)
    local start = os.gettime()
    event_info.timestamp_queued = event_info.timestamp_queued or start

    if self.config.debug and not event_info.silent then
        print(self,"Processing event " .. event_info.event)
    end
    local run_stats = {
        handlers_called = 0
    }
    self.loader_module:EnumerateModules(
        function(name, module)
            self:ApplyEvent(name, module, event_info, run_stats)
        end
    )

    for uuid,v in pairs(self.subscriptions) do
        self:ApplyEvent(uuid, v, event_info, run_stats)
    end

    if self.logger:Enabled() then
        local finish = os.gettime()
        self.logger:WriteCsv{
            os.string_timestamp(),
            "event=" .. event_info.event,
            "queued=" .. tostring(event_info.timestamp_queued),
            "start=" .. tostring(start),
            "finish=" .. tostring(finish),
            "processing=" .. tostring(finish-start),
            "delay=" .. tostring(start-event_info.timestamp_queued),
            "handlers_called=" .. tostring(run_stats.handlers_called),
        }
    end

    return run_stats.handlers_called
end

function EventBus:ApplyEvent(name, instance, event_info, run_stats)
    local mt = instance
    local prev_table = nil
    while mt do
        local event_table = mt.EventTable
        if event_table and prev_table ~= event_table then
            prev_table = event_table
            local handler = event_table[event_info.event]
            if not handler then
                return
            end

            -- print(self, "Apply event " .. event_info.event .. " to " .. name)
            run_stats.handlers_called = run_stats.handlers_called + 1
            handler(instance, setmetatable({}, { __index = event_info }))
        end

        mt = mt.super
    end
end

-------------------------------------------------------------------------------

return EventBus
