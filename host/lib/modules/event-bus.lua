local copas = require "copas"
local modules = require("lib/modules")

local EventBus = {}
EventBus.__index = EventBus
EventBus.__deps = {
    module_enumerator = "module-enumerator"
}

function EventBus:LogTag()
    return "EventBus"
end

function EventBus:BeforeReload()
end

function EventBus:AfterReload()
    self.event_queue = {}
    self.process_thread = nil
    modules:RegisterReloadWatcher(self:LogTag(), function(...) self:OnModuleReloaded(...) end)

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
end

function EventBus:OnModuleReloaded(module_name)
    self:PushEvent({
        event = "module.reloaded",
        argument = { name = module_name }
    })
end

function EventBus:PushEvent(event_info)
    table.insert(self.event_queue, event_info)
end

function EventBus:ProcessAllEvents()
    while #self.event_queue > 0 do
        self:ProcessEvent(table.remove(self.event_queue, 1))
    end
end

function EventBus:ProcessEvent(event_info)
    -- if configuration.debug then
    --     print(self:LogTag() .. ": Processing event " .. event_info.event)
    -- end
    local run_stats = {
        handlers_called = 0
    }
    self.module_enumerator:Enumerate(
        function(name, module)
            SafeCall(self.ApplyEvent, self, name, module, event_info, run_stats)
        end
    )
    return run_stats.handlers_called
end

function EventBus:ApplyEvent(module_name, module_instance, event_info, run_stats)
    if not module_instance then
        return
    end
    local event_table = module_instance.EventTable
    if not event_table then
        return
    end

    local handler = event_table[event_info.event]
    if not handler then
        return
    end

    -- print(self:LogTag() .. ": Apply event " .. event_info.event .. " to " .. module_name)
    run_stats.handlers_called = run_stats.handlers_called + 1

    handler(module_instance, setmetatable({}, { __index = event_info }))
end

return EventBus
