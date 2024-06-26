local scheduler = require "fairy_node/scheduler"
local tablex = require "pl.tablex"
local config_handler = require "fairy_node/config-handler"
local loader_module = require "fairy_node/loader-module"
local uuid = require "uuid"

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
    self.uuid = uuid()
    self.config = config.config or { }
    loader_module:UpdateObjectDeps(self)

    if self.config.debug == nil then
        self.config.debug = config_handler:QueryConfigItem("debug")
    end
    if self.config.verbose == nil then
        self.config.verbose = config_handler:QueryConfigItem("verbose")
    end

    self.debug = self.config.debug
    self.verbose = self.config.verbose
end

function Object:Shutdown()
    self:StopAllTasks()
    self.error_manager = nil
    self.event_bus = nil
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

function Object:Unsubscribe(target)
    assert(target)
    if self.subscriptions then
        self.subscriptions[target.uuid] = nil
    end
end

function Object:CallSubscribers(event, arg)
    if not self.subscriptions then
        return
    end

    for _,entry in pairs(self.subscriptions) do
        local target = entry.target
        local func = entry.func
        if target and func then
            -- print(self, "Calling subscription to " .. target:Tag())
            scheduler.Push(function() func(target, self, event, arg) end)
        end
    end
end

function Object:ClearSubscribers()
    self.subscriptions = nil
end

-------------------------------------------------------------------------------------

function Object:StopAllTasks()
    if self.tasks then
        for _,key in ipairs(tablex.keys(self.tasks)) do
            self.tasks[key]:Stop()
            self.tasks[key] = nil
        end
        self.tasks = nil
    end
end

function Object:StopTask(name)
    if self.tasks and self.tasks[name] then
        self.tasks[name]:Stop()
        self.tasks[name] = nil
    end
end

function Object:AddTask(name, interval, func)

    if type(interval) == "function" then
        func = interval
        interval = 0
    end

    self.tasks = self.tasks or { }

    if self.tasks[name] then
        self.tasks[name]:Stop()
        self.tasks[name] = nil
    end

    local task = scheduler:CreateTask(self, name, interval, function (owner, task) func(owner, task) end)
    self.tasks[name] = task

    return task
end

function Object:RemoveCompletedTasks()
    if self.tasks then
        for _,key in ipairs(tablex.keys(self.tasks)) do
            local task = self.tasks[key]
            if task:IsCompleted() then
                self.tasks[key] = nil
                printf(self, "Removing completed task '%s'", task.name)
                task:Stop()
            end
        end
    end
end

function Object:GetTaskCount()
    local count = 0
    for _,_ in pairs(self.tasks or {}) do
        count = count + 1
    end
    return count
end

-------------------------------------------------------------------------------------

function Object:GetErrorManager()
    if not self.error_manager then
        self.error_manager = loader_module:GetModule("fairy_node/error-manager")
    end
    return self.error_manager
end

function Object:SetError(id, message)
    local em = self:GetErrorManager()
    if not em then
        assert(false, id .. ": " .. message)
        return
    end
    return em:SetError(self, id, message)
end

function Object:ClearError(id)
    local em = self:GetErrorManager()
    if not em then
        return
    end
    return em:ClearError(self, id)
end

function Object:ClearAllErrors()
    local em = self:GetErrorManager()
    if not em then
        return
    end
    return em:ClearAllErrors(self)
end

function Object:TestError(test, id, message)
    if test then
        return self:SetError(id, message)
    end
end

-------------------------------------------------------------------------------------

function Object:GetEventBus()
    if not self.event_bus then
        self.event_bus = loader_module:LoadModule("fairy_node/event-bus")
    end
    return self.event_bus
end

-------------------------------------------------------------------------------------

return Object
