local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local State = {}
State.__index = State
State.__class = "State"
State.__is_state_class = true

-------------------------------------------------------------------------------------

function State:AfterReload() end

-------------------------------------------------------------------------------------

function State:OnTimer()
end

function State:LocallyOwned()
    return false
end

function State:Settable()
    return false
end

-------------------------------------------------------------------------------------

function State:GetDescription()
    return tablex.copy(self.description or {})
end

function State:GetSourceDependencyDescription() return "[updates]" end

function State:SetValue(v) error(self:LogTag() .. "abstract method called") end

function State:GetValue() error(self:LogTag() .. "abstract method called") end

function State:GetName() return self.name end

function State:IsReady() return self.is_ready end

function State:LogTag()
    if not self.log_tag then
        self.log_tag = string.format("%s(%s): ", self.__class, self.global_id)
    end
    return self.log_tag
end

function State:Update()
    return self:IsReady()
end

-------------------------------------------------------------------------------------

function State:AddSourceDependency(dependant_state)
    print(self:LogTag(), "Added dependency " .. dependant_state.global_id ..
              " to " .. self.global_id)

    self.source_dependencies[dependant_state.global_id] = dependant_state
    dependant_state:AddSinkDependency(self)

    self:RetireValue()
end

function State:GetSourceDependencyList()
    return self:GetDependencyList(self.source_dependencies)
end

function State:HasSourceDependencies() return #self.source_dependencies > 0 end

function State:GetDependantValues()
    local dependant_values = {}
    for _, v in pairs(self.source_dependencies) do
        if not v:IsReady() then
            print(self:LogTag(),"Dependency " .. v.global_id .. " is not yet ready")
            return nil
        end
        SafeCall(function()
            table.insert(dependant_values, { value = v:GetValue(), id = v.global_id})
        end)
    end
    return dependant_values
end

-------------------------------------------------------------------------------------

function State:AddSinkDependency(listener)
    print(self:LogTag(), "Added listener " .. listener.global_id)

    self.sink_dependencies[listener.global_id] = listener

    if self:IsReady() then
        SafeCall(function() listener:SourceChanged(self, self:GetValue()) end)
    end
end

function State:CallSinkListeners(result_value)
    -- print(self:LogTag(), "CallSinkListeners")
    for _, v in pairs(self.sink_dependencies) do
        -- print(self:LogTag(), "Calling listener " .. v.global_id)
        SafeCall(function() v:SourceChanged(self, result_value) end)
    end
end

function State:GetSinkDependencyList()
    return self:GetDependencyList(self.sink_dependencies)
end

function State:HasSinkDependencies() return #self.sink_dependencies > 0 end

function State:SourceChanged(source, source_value)
    self:Update()
end

-------------------------------------------------------------------------------------

function State:SetError(...)
    local message = string.format(...)
    print(self, message)
end

function State:GetDependencyList(list)
    local r = {}
    for _, v in pairs(list or {}) do table.insert(r, v.global_id) end
    return r
end


function State:Create(config)
    assert(self.global_id)
    self.name = config.name
    if type(config.description) ~= "table" then
        self.description = {config.description}
    else
        self.description = config.description
    end

    local weak_mt = {__mode = "v"}
    self.sink_dependencies = setmetatable({}, weak_mt)
    self.source_dependencies = setmetatable({}, weak_mt)

    for _, v in ipairs(config.source_dependencies or {}) do
        self:AddSourceDependency(v)
    end
    for _, v in ipairs(config.sink_dependencies or {}) do
        self:AddSinkDependency(v)
    end

    self.is_ready = nil
end

-------------------------------------------------------------------------------------

return {
    Class = State,
    -- BaseClass = nil,

    __deps = {class_reg = "state-class-reg"},

    AfterReload = function(instance) end,
}
