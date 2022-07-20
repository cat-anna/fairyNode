local copas = require "copas"
local uuid = require "uuid"

-------------------------------------------------------------------------------

local gettime = os.gettime
local insert = table.insert
local remove = table.remove
local ipairs = ipairs
local pairs = pairs
local setmetatable = setmetatable

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

local function CallHandler(instance, handler, arg)
    if type(handler) == "string" then
        handler = instance[handler]
        if handler then
            return handler(instance, arg)
        end
    else
       return handler(instance, arg)
    end
end

-------------------------------------------------------------------------------

function EventBus:LogTag()
    return "EventBus"
end

function EventBus:BeforeReload()
end

function EventBus:AfterReload()
    self.loader_module:RegisterWatcher(self:LogTag(), self)
    self.loader_class:RegisterWatcher(self:LogTag(), self)
end

function EventBus:Init()
    self.event_queue = {}
    self.subscriptions = table.weak()

    self.logger = require("lib/logger"):New("event-bus", CONFIG_KEY_EVENT_BUS_LOG_ENABLE)
    self:InvalidateHandlerCache()

    self.process_thread = copas.addthread(function()
        while true do
            copas.sleep(0.1)
            SafeCall(function()
                self:ProcessAllEvents()
            end)
        end
    end)
end

function EventBus:InvalidateHandlerCache()
    self.handler_cache = {}
    if self.logger:Enabled() then
        self.logger:WriteCsv{ "flush=cache" }
    end
end

function EventBus:AllModulesLoaded()
    self:InvalidateHandlerCache()
    self:PushEvent({ event = "module.load_complete", })
    self:PushEvent({ event = "app.start", })
end

function EventBus:ModuleReloaded(module_name, module)
    self:InvalidateHandlerCache()
    self:PushEvent({
        event = "module.reloaded",
        argument = { name = module_name }
    })
end

function EventBus:OnObjectCreated(class_name, object)
    self:InvalidateHandlerCache()
    self.subscriptions[object.uuid] = object
end

function EventBus:PushEvent(event_info)
    if self.config.debug and not event_info.silent then
        print(self, "Push event " .. event_info.event)
    end
    event_info.uuid = uuid()
    event_info.timestamp_queued = gettime()
    insert(self.event_queue, event_info)
end

function EventBus:ProcessAllEvents()
    while #self.event_queue > 0 do
        self:ProcessEvent(remove(self.event_queue, 1))
    end
end

function EventBus:ProcessEvent(event_info)
    local start = gettime()

    if self.config.debug and not event_info.silent then
        print(self, "Processing event " .. event_info.event)
    end

    local run_stats = {
        handlers_called = 0,
        handlers_expired = 0,
    }

    local cache = self.handler_cache[event_info.event]
    if cache then
        for _,v in ipairs(cache) do
            local instance = v.instance
            local handler = v.handler

            if handler and instance then
                CallHandler(instance, handler, setmetatable({}, { __index = event_info }))
                run_stats.handlers_called = run_stats.handlers_called + 1
            else
                run_stats.handlers_expired = run_stats.handlers_expired + 1
            end
        end
    else
        local entry = { }
        self.handler_cache[event_info.event] = entry

        self.loader_module:EnumerateModules(
            function(name, module)
                self:ApplyEvent(name, module, event_info, run_stats, entry)
            end
        )

        for uuid,v in pairs(self.subscriptions) do
            self:ApplyEvent(uuid, v, event_info, run_stats, entry)
        end
    end

    local finish = gettime()
    local processing_time = finish-start
    if processing_time > 0.1 then
        printf(self, "Processing of event %s(%s) took too long (%f)", event_info.event, event_info.uuid, processing_time)
    end

    if self.logger:Enabled() then
        self.logger:WriteCsv{
            "uuid=" .. event_info.uuid,
            "event=" .. event_info.event,
            "queued=" .. tostring(event_info.timestamp_queued),
            "start=" .. tostring(start),
            "finish=" .. tostring(finish),
            "processing=" .. tostring(processing_time),
            "delay=" .. tostring(start-event_info.timestamp_queued),
            "handlers_called=" .. tostring(run_stats.handlers_called),
            "handlers_expired=" .. tostring(run_stats.handlers_expired),
            "cache_hit=" .. tostring(cache ~= nil),
        }
    end

    return run_stats.handlers_called
end

function EventBus:ApplyEvent(name, instance, event_info, run_stats, cache_entry)
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
            table.insert(cache_entry, table.weak {
                instance = instance,
                handler = handler,
            })

            CallHandler(instance, handler, setmetatable({}, { __index = event_info }))
        end

        mt = mt.super
    end
end

-------------------------------------------------------------------------------

return EventBus
