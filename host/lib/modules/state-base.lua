local State = {}
State.__index = State
State.__class = "State"
State.__is_state_class = true

function State:AfterReload()
end

-- function State:OnReuse()
-- end

function State:GetDescription()
    if self.description == nil then
        return nil
    end
    if type(self.description) ~= "table" then
        return { self.description }
    end
    return self.description
end

function State:SetValue(v)
    error(self:GetLogTag() .. "abstract method called")
end

function State:GetValue()
    error(self:GetLogTag() .. "abstract method called")
end

function State:GetName()
    return self.name
end

function State:GetLogTag()
    if not self.log_tag then
        self.log_tag = string.format("%s(%s): ", self.__class, self.global_id)
    end
    return self.log_tag
end

function State:IsReady()
    return self.is_ready
end

function State:Update()
    print(self:GetLogTag(), "Update")
    return self:IsReady()
end

-------------------------------------------------------------------------------------

function State:AddSourceDependency(dependant_state)
    print(self:GetLogTag(), "Added dependency " .. dependant_state.global_id  .. " to " .. self.global_id)

    self.source_dependencies[dependant_state.global_id] = dependant_state
    dependant_state:AddSinkDependency(self)

    self:RetireValue()
end

function State:GetSourceDependencyList()
    return self:GetDependencyList(self.source_dependencies)
end

function State:HasSourceDependencies()
    return #self.source_dependencies > 0
end

-------------------------------------------------------------------------------------

function State:AddSinkDependency(listener)
    print(self:GetLogTag(), "Added listener " .. listener.global_id)

    self.sink_dependencies[listener.global_id] = listener

    if self:IsReady() then
        SafeCall(function () listener:SourceChanged(self, self:GetValue()) end)
    end
end

function State:CallSinkListeners(result_value)
    print(self:GetLogTag(), "CallSinkListeners")
    for _,v in pairs(self.sink_dependencies) do
        print(self:GetLogTag(), "Calling listener " .. v.global_id)
        SafeCall(function () v:SourceChanged(self, result_value) end)
    end
end

function State:GetSinkDependencyList()
    return self:GetDependencyList(self.sink_dependencies)
end

function State:HasSinkDependencies()
    return #self.sink_dependencies > 0
end

function State:SourceChanged(source, source_value)
    print(self:GetLogTag(), "SourceChanged")
    self:Update()
end

-------------------------------------------------------------------------------------

function State:GetDependencyList(list)
    local r = {}
    for _,v in pairs(list or {}) do
        table.insert(r, v.global_id)
    end
    return r
end

function State:Create(config)
    assert(self.global_id)
    self.name = config.name
    self.description = config.description

    local weak_mt = { __mode = "v" }

    self.sink_dependencies = setmetatable({}, weak_mt)
    self.source_dependencies = setmetatable({}, weak_mt)

    for _,v in ipairs(config.source_dependencies or {}) do
        self:AddSourceDependency(v)
    end
    for _,v in ipairs(config.sink_dependencies or {}) do
        self:AddSinkDependency(v)
    end

    self.is_ready = nil
end

return {
    Class = State,
    -- BaseClass = nil,

    Deps = {
        class_reg = "state-class-reg"
    },
    AfterReload = function(instance)
        instance.class_reg:RegisterStateClass(instance)
    end,
}
