local scheduler = require "lib/scheduler"

-------------------------------------------------------------------------------------

local Object = { }
Object.__index = Object
Object.__name = "Object"
Object.__type = "interface"

-------------------------------------------------------------------------------------

function Object:Init(config)
end

function Object:PostInit()
end

function Object:Tag()
    return string.format("%s(%s)", self.__name, self.uuid)
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

function Object:AddTask(name, interval, func)
    self.tasks = self.tasks or { }

    if self.tasks[name] then
        self.tasks[name]:Stop()
        self.tasks[name] = nil
    end

    local task = scheduler:CreateTask(self, name, interval, function (owner, task) func(owner, task) end)
    self.tasks[name] = task

    return task
end

-------------------------------------------------------------------------------------

return Object
