
local StateHomie = {}
StateHomie.__index = StateHomie
StateHomie.__base = "rule/state-base"
StateHomie.__class_name = "StateHomie"
StateHomie.__type = "class"
StateHomie.__deps =  {
    homie_host = "homie/homie-host",
}

function StateHomie:Init(config)
    self.super.Init(self, config)
    self.property_instance = config.property_instance
    self.property_path = config.property_path
    self:Update()
end

function StateHomie:GetValue()
    if self.property_instance then
        return  self.property_instance:GetValue()
    end
end

function StateHomie:SetValue(v)
    self.expected_value = v
    self.expected_value_valid = true
    if self.property_instance then
        return self.property_instance:SetValue(v)
    end
end

function StateHomie:GetName()
    if self.property_instance then
        return self.property_instance.name
    else
        return self.global_id
    end
end

function StateHomie:Update()
    if not self.property_instance then
        if self.homie_host then
            self.property_instance = self.homie_host:FindProperty(self.property_path)
        else
            print("#### NO HOMIE HOST ###")
        end
    end

    if not self.subscribed and self.property_instance then
        self.property_instance:Subscribe(self.global_id, self)
    end

    return self.super.Update(self)
end

function StateHomie:PropertyStateChanged(property, value)
    self.subscribed = value ~= nil
    if not self.subscribed then
        return
    end
    -- print(self:GetLogTag(), "PropertyStateChanged")
    self:CallSinkListeners(value)
    if self.expected_value_valid and not self:HasSinkDependencies() then
        self:SetValue(self.expected_value)
    end
end

function StateHomie:SourceChanged(source, source_value)
    self:SetValue(source_value)
end

function StateHomie:IsReady()
    return self.subscribed and (self:GetValue() ~= nil)
end

return StateHomie
