local scheduler = require "fairy_node/scheduler"
local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local Object = { }
Object.__index = Object
Object.__name = "Object"
Object.__type = "interface"

-------------------------------------------------------------------------------------

function Object:GetAllObjectDependencies()
    local r = { }
    -- local bases = { }

    local mt = getmetatable(self)
    while mt do
        -- table.insert(bases, rawget(mt, "__name") or rawget(mt, "__tag"))
        local deps = mt.__deps or { }
        for k,v in pairs(deps) do
            if r[k] and r[k] ~= v then
                printf(self, "Found dependency conflict: %s=%s and %s=%s", k, r[k], k, v)
            end
            r[k] = v
        end
        mt = getmetatable(mt)
    end

    -- print(self, "BASE:", table.concat(bases, ","))
    -- print(self, "DEPS:", table.concat(tablex.values(r), ","))

    return r
end

-------------------------------------------------------------------------------------

function Object:Init(config)
    self.config = config.config
end

function Object:Finalize()
end

function Object:Tag()
    local tag = self.__tag
    if not tag then
        tag = string.format("%s(%s)", self.__name, self.uuid)
        self.__tag = tag
    end
    return tag
end

-------------------------------------------------------------------------------------

function Object:DumpConfig()
    print(self, "Starting config dump")
    for k,v in pairs(self.config) do
        print(self, k, "=", v)
    end
    print(self, "Completed config dump")
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
