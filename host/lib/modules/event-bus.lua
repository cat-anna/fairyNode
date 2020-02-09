local copas = require "copas"

local EventBus = {}
EventBus.__index = EventBus
EventBus.Deps = {
    module_enumerator = "module-enumerator"
}

function EventBus:LogTag()
    return "EventBus"
end

function EventBus:BeforeReload()
end

function EventBus:AfterReload()
    -- function print(...)
    --     self:Print(...)
    -- end
end

function EventBus:Init()
end

function EventBus:PushEvent(event_info)
    copas.addthread(function()
        self:ProcessEvent(event_info)
    end)
end

function EventBus:ProcessEvent(event_info)
    -- print(self:LogTag() .. ": Processing event " .. event_info.event)
    self.module_enumerator:Enumerate(
        function(name, module)
            SafeCall(self.ApplyEvent, self, name, module, event_info)
        end
    )
end

function EventBus:ApplyEvent(module_name, module_instance, event_info)
    local event_table = module_instance.EventTable
    if not event_table then
        return 
    end

    local handler = event_table[event_info.event]
    if not handler then
        return 
    end

    -- print(self:LogTag() .. ": Apply event " .. event_info.event .. " to " .. module_name) 

    handler(module_instance, setmetatable({}, { __index = event_info }))
end

return EventBus
