local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local State = {}
State.__index = State
State.__type = "interface"
State.__class_name = "StateBase"
State.__is_state_class = true

-------------------------------------------------------------------------------------

function State:Init(config)
    self.global_id = config.global_id
    self.class_id = config.class_id
    self.name = config.name
    self.group = config.group

    if type(config.description) ~= "table" then
        self.description = {config.description}
    else
        self.description = config.description
    end

    self.sink_dependencies = {}
    self.source_dependencies = {}
    self.observers = table.weak()
    self:RetireValue()

    for k, v in pairs(config.source_dependencies or {}) do
        self:AddSourceDependency(v, type(k) == "string" and k or nil)
    end
    for _, v in ipairs(config.sink_dependencies or {}) do
        self:AddSinkDependency(v)
    end
    for _, v in ipairs(config.observers or {}) do
        self:AddObserver(v)
    end
end

function State:BeforeReload()
end

function State:AfterReload()
end

--------------------------------------------------------------------------

function State:OnTimer()
    -- self:Update()
end

function State:LocallyOwned()
    return false
end

function State:IsSettable()
    return false
end

function State:Status()
    return self:IsReady(), self:GetValue()
end

function State:GetGroup()
    return self.group
end

-------------------------------------------------------------------------------------

function State:GetDescription()
    return tablex.copy(self.description or {})
end

function State:GetName()
    return self.name
end

function State:IsReady()
    return self.current_value ~= nil
end

function State:Tag()
    return string.format("%s(%s)", self.__class, self.global_id)
end

function State:Update()
    local dv = self:GetSourceValues()
    if not dv then
        self:RetireValue()
        return
    end
    return self:SetCurrentValue(self:CalculateValue(dv))
end

function State:SetValue(v)
    error(self:Tag() .. "abstract method called")
end

function State:GetValue()
    if not self.current_value then
        self:Update()
    end
    return self.current_value
end

function State:SetCurrentValue(cv)
    if cv == nil then
        self:RetireValue()
        return
    end
    if self.current_value and self.current_value.value == cv.value then
        return self.current_value
    end

    print(self, "Value changed to " .. tostring(cv.value))
    self.current_value = cv

    self:CallSinkListeners(cv)
    self:CallObservers(cv)

    return cv
end

function State:RetireValue()
    self.current_value = nil
end

function State:CalculateValue(dependant_values)
    error(self:Tag() .. "abstract method called")
end

function State:WrapCurrentValue(value, timestamp)
    return {
        id = self.global_id,
        value = value,
        timestamp = timestamp or os.timestamp(),
    }
end

-------------------------------------------------------------------------------------

function State:AddSourceDependency(dependant_state, source_id)
    print(self, "Added dependency " .. dependant_state.global_id ..
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

function State:GetSourceValues()
    local dependant_values = {}
    for id, dep in pairs(self.source_dependencies) do
        if (not dep.target) or (not dep.target:IsReady()) then
            print(self, "Dependency " .. id .. " is not yet ready")
            return
        end
        local value = dep.target:GetValue()
        if value == nil then
            print(self, "Dependency " .. id .. " has no value")
            return
        end
        value = tablex.copy(value)
        value.source_id = dep.source_id
        table.insert(dependant_values, value)
    end
    return dependant_values
end

-------------------------------------------------------------------------------------

function State:AddSinkDependency(listener, virtual)
    print(self, "Added listener " .. listener.global_id)

    self.sink_dependencies[listener.global_id] = table.weak_values {
        target = listener,
        virtual = virtual
    }

    if self:IsReady() and not virtual then
        SafeCall(function() listener:SourceChanged(self, self:GetValue()) end)
    end
end

function State:CallSinkListeners(current_value)
    for id, dep in pairs(self.sink_dependencies) do
        if not dep.target then
            print(self, "Dependency " .. id .. " is expired")
        elseif dep.virtual then
            print(self, "Dependency " .. id .. " is virtual")
        else
            dep.target:SourceChanged(self, current_value)
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
    self:Update()
end

-------------------------------------------------------------------------------------

function State:AddObserver(target)
    self.observers[target.uuid] = target
end

function State:CallObservers(current_value)
    for _,v in pairs(self.observers) do
        v:StateRuleValueChanged(self, current_value)
    end
end

-------------------------------------------------------------------------------------

function State:SetError(...)
    --TODO
    printf(self, ...)
end

function State:GetDependencyList(list)
    local r = {}
    for id, v in pairs(list or {}) do
        table.insert(r, {
            id = id,
            virtual = v.virtual,
            expired = v.target == nil,
            group = v.target and v.target:GetGroup()
        })
    end
    return r
end

-------------------------------------------------------------------------------------

return State
