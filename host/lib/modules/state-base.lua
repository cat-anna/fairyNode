local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local State = {}
State.__index = State
State.__class = "State"
State.__is_state_class = true

-------------------------------------------------------------------------------------

function State:AfterReload() end

--------------------------------------------------------------------------

function State:OnTimer() end

function State:LocallyOwned() return false end

function State:Settable() return false end

function State:Status()
    return self:IsReady(), self:GetValue()
end

-------------------------------------------------------------------------------------

function State:GetDescription() return tablex.copy(self.description or {}) end

function State:GetSourceDependencyDescription()
    return nil -- "[updates]"
end

function State:SetValue(v) error(self:LogTag() .. "abstract method called") end

function State:GetValue() error(self:LogTag() .. "abstract method called") end

function State:GetName() return self.name end

function State:IsReady() return false end

function State:LogTag()
    if not self.log_tag then
        self.log_tag = string.format("%s(%s): ", self.__class, self.global_id)
    end
    return self.log_tag
end

function State:Update() return self:IsReady() end

function State:RetireValue() end

-------------------------------------------------------------------------------------

function State:AddSourceDependency(dependant_state, source_id)
    print(self:LogTag(), "Added dependency " .. dependant_state.global_id ..
              " to " .. self.global_id)

    self.source_dependencies[dependant_state.global_id] = table.weak_values {
        target = dependant_state,
        source_id = source_id,
    }
    dependant_state:AddSinkDependency(self, nil)

    self:RetireValue()
end

function State:GetSourceDependencyList()
    return self:GetDependencyList(self.source_dependencies)
end

function State:HasSourceDependencies()
    for _, v in pairs(self.source_dependencies) do return true end
    return false
end

function State:GetDependantValues()
    local dependant_values = {}
    for id, dep in pairs(self.source_dependencies) do
        if (not dep.target) or (not dep.target:IsReady()) then
            print(self:LogTag(), "Dependency " .. id .. " is not yet ready")
            return nil
        end
        local value
        SafeCall(function()
            value = dep.target:GetValue()
        end)
        if value == nil then
            print(self:LogTag(), "Dependency " .. id .. " has no value")
            return nil
        end
        table.insert(dependant_values,
                        {value=value, id = id, source_id = dep.source_id})
    end
    return dependant_values
end

-------------------------------------------------------------------------------------

function State:AddSinkDependency(listener, virtual)
    print(self:LogTag(), "Added listener " .. listener.global_id)

    self.sink_dependencies[listener.global_id] = table.weak_values {
        target = listener,
        virtual = virtual
    }

    if self:IsReady() and not virtual then
        SafeCall(function() listener:SourceChanged(self, self:GetValue()) end)
    end
end

function State:CallSinkListeners(result_value)
    for id, dep in pairs(self.sink_dependencies) do
        -- print(self:LogTag(), "Calling listener " .. v.global_id)
        if not dep.target then
            print(self:LogTag(), "Dependency " .. id .. " is expired")
        elseif dep.virtual then
            print(self:LogTag(), "Dependency " .. id .. " is virtual")
        else
            SafeCall(function()
                dep.target:SourceChanged(self, result_value)
            end)
        end
    end
end

function State:GetSinkDependencyList()
    return self:GetDependencyList(self.sink_dependencies)
end

function State:HasSinkDependencies()
    for _, v in pairs(self.sink_dependencies) do return true end
    return false
end

function State:SourceChanged(source, source_value)
    if self:IsReady() then
        self:Update()
    end
 end

-------------------------------------------------------------------------------------

function State:SetError(...)
    local message = string.format(...)
    print(self, message)
end

function State:GetDependencyList(list)
    local r = {}
    for id, v in pairs(list or {}) do
        table.insert(r, {id = id, virtual = v.virtual, expired = v.target == nil})
    end
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

    self.sink_dependencies = {}
    self.source_dependencies = {}

    for k, v in pairs(config.source_dependencies or {}) do
        self:AddSourceDependency(v, type(k) == "string" and k or nil)
    end
    for _, v in ipairs(config.sink_dependencies or {}) do
        self:AddSinkDependency(v)
    end
end

-------------------------------------------------------------------------------------

return {
    Class = State,
    -- BaseClass = nil,

    __deps = {
        class_reg = "state-class-reg",
    },

    Init = function(instance)
    end
}
