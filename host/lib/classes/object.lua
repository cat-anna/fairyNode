local scheduler = require "lib/scheduler"

-------------------------------------------------------------------------------------

local Object = { }
Object.__index = Object
Object.__class_name = "Object"
Object.__type = "interface"

-------------------------------------------------------------------------------------

function Object:Init(config)
end

function Object:PostInit()
end

function Object:Tag()
    return string.format("%s(%s)", self.__class_name, self.uuid)
end

-------------------------------------------------------------------------------------

function Object:Subscribe(target, func)
    assert(target and func)

    -- print(self, "Adding subscription to " .. target:Tag())

    if not self.subscriptions then
        self.subscriptions = table.weak_keys()
    end

    if self.subscriptions[target.uuid] then
        print(self, "Failed to add subscription, target is already subscribed")
        return
    end

    local entry = table.weak_values()
    self.subscriptions[target.uuid] = entry
    entry.target = target
    entry.func = func

    -- scheduler.Push(function() func(target, self) end)

    return true
end

function Object:CallSubscribers(argument)
    if not self.subscriptions then
        return
    end

    for _,entry in pairs(self.subscriptions) do
        local target = entry.target
        local func = entry.func
        if target and func then
            -- print(self, "Calling subscription to " .. target:Tag())
            scheduler.Push(function() func(target, self, argument) end)
        end
    end
end

function Object:ClearSubscribers()
    self.subscriptions = nil
end

-------------------------------------------------------------------------------------

return Object
