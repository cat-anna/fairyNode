local copas = require "copas"
local uuid = require "uuid"
local scheduler = require "lib/scheduler"
local logger = require "lib/logger"

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

function EventBus:Tag()
    return "EventBus"
end

function EventBus:BeforeReload()
end

function EventBus:AfterReload()
    self.loader_module:RegisterWatcher(self:Tag(), self)
    self.loader_class:RegisterWatcher(self:Tag(), self)
end

function EventBus:Init()
    self.event_queue = {}
    self.subscriptions = table.weak()

    if self.config.debug then
        self.stats = { }
    end

    self.process_task = scheduler:CreateTask(
        self,
        "event processing",
        1,
        function (s, task) s:ProcessAllEvents() end
    )

    self.logger = logger:New("event-bus", CONFIG_KEY_EVENT_BUS_LOG_ENABLE)
    self:InvalidateHandlerCache()
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
end

function EventBus:ModuleReloaded(module_name, module)
    self:InvalidateHandlerCache()
    self:PushEvent({
        event = "module.reloaded",
        name = module_name,
    })
end

function EventBus:OnObjectCreated(class_name, object)
    self:InvalidateHandlerCache()
    self.subscriptions[object.uuid] = object
end

function EventBus:PushEvent(event_info)
    if self.config.verbose then
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

    if self.config.verbose then
        print(self, "Processing event " .. event_info.event)
    end

    local run_stats = {
        active_handlers = 0,
    }

    local cache = self.handler_cache[event_info.event]
    if cache then
        for _,v in ipairs(cache) do
            local instance = v.instance
            local handler = v.handler

            if handler and instance then
                CallHandler(instance, handler, setmetatable({}, { __index = event_info }))
                run_stats.active_handlers = run_stats.active_handlers + 1
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

    if self.stats then
        local s = self.stats[event_info.event]
        if not s then
            s = {
                occurrences = 0,
                total_run_time = 0,
                max_run_time = 0,
                active_handlers = 0,
            }
            self.stats[event_info.event] = s
        end

        s.occurrences = s.occurrences + 1
        s.total_run_time = s.total_run_time + processing_time
        s.max_run_time = math.max(s.max_run_time, processing_time)
        s.active_handlers = run_stats.active_handlers
        s.last_run_timestamp = os.gettime()
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
            "active_handlers=" .. tostring(run_stats.active_handlers),
            "cache_hit=" .. tostring(cache ~= nil),
        }
    end

    return run_stats.active_handlers
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

            run_stats.active_handlers = run_stats.active_handlers + 1
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

function EventBus:EnableStatistics(enable)
    if enable then
        self.stats = self.stats or {}
    else
        self.stats = nil
    end
end

function EventBus:GetDebugTable()
    if not self.stats then
        return
    end

    local header = {
        "occurrences",
        "total_run_time",
        "max_run_time",
        "active_handlers",
        "last_run_timestamp",
    }

    local r = { }

    for k,v in pairs(self.stats) do
        local line = { k }
        for _,n in ipairs(header) do
            table.insert(line, v[n])
        end
        table.insert(r, line)
    end

    table.insert(header, 1, "event_id")
    table.sort(r, function(a,b) return a[4] > b[4] end)

    return {
        title = "Event bus",
        header = header,
        data = r
    }
end

-------------------------------------------------------------------------------

EventBus.EventTable = {
}

return EventBus
