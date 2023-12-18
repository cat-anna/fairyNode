-------------------------------------------------------------------------------------

local RuleStateLocalValueProxy = { }
RuleStateLocalValueProxy.__base = "base/property/local-value"
RuleStateLocalValueProxy.__type = "class"
RuleStateLocalValueProxy.__name = "RuleStateLocalValueProxy"

-------------------------------------------------------------------------------------

function RuleStateLocalValueProxy:Init(config)
    RuleStateLocalValueProxy.super.Init(self, config)
    self.target = table.weak_values {
        state = config.target_state
    }
end

function RuleStateLocalValueProxy:PostInit()
    RuleStateLocalValueProxy.super.PostInit(self)
end

-------------------------------------------------------------------------------------

function RuleStateLocalValueProxy:IsPersistent()
    return false
end

function RuleStateLocalValueProxy:IsReady()
    local state = self.target.state
    if state then
        return state:IsReady()
    end
    return false
end

function RuleStateLocalValueProxy:GetName()
    local state = self.target.state
    if state then
        return state:GetName()
    end
    return self:GetId()
end

function RuleStateLocalValueProxy:GetValue()
    local state = self.target.state
    if state and state:IsReady() then
        local r = state:GetValue()
        if r then
            return r.value, r.timestamp
        end
    end
end

function RuleStateLocalValueProxy:GetDatatype()
    local state = self.target.state
    if state then
        return state:GetDatatype()
    end
end

function RuleStateLocalValueProxy:GetUnit()
    local state = self.target.state
    if state then
        return state:GetUnit()
    end
    return
end

function RuleStateLocalValueProxy:GetDatabaseId()
    assert(not self:IsPersistent())
    -- return string.format("property.value.%s", self:GetGlobalId())
    return nil
end

-------------------------------------------------------------------------------------

return RuleStateLocalValueProxy
