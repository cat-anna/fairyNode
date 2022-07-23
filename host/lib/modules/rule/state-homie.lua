
-------------------------------------------------------------------------------------

local StateHomie = {}
StateHomie.__index = StateHomie
StateHomie.__base = "rule/state-base"
StateHomie.__class_name = "StateHomie"
StateHomie.__type = "class"
StateHomie.__deps =  {
    homie_host = "homie/homie-host",
}

-------------------------------------------------------------------------------------

function StateHomie:Init(config)
    self.super.Init(self, config)
    self.device = table.weak {
        instance = config.device,
        property = config.property_instance,
    }
    self.property_path = config.property_path

    self:Update()
end

function StateHomie:GetName()
    if self.device.property then
        return self.device.property.name
    end
    return self.global_id
end

function StateHomie:Settable()
    return self.settable
end

function StateHomie:GetValue()
    if not self.device.property then
        self:Update()
    end
    if self.device.property then
        local v, t = self.device.property:GetValue()
        return {
            value = v,
            timestamp = t,
            id = self.global_id,
        }
    end
end

function StateHomie:SetValue(v)
    if not self:Settable() then
        self:SetError(self, "Homie node '%s' is not settable", self.property_path)
        return
    end

    self.expected_value = {
        value = v,
        timestamp = os.timestamp(),
    }

    if self.device.property then
        self.device.property:SetValue(v)
    end
end

function StateHomie:Update()
    if not self.device.property then
        self.device.property = self.homie_host:FindProperty(self.property_path)
        if not self.device.property then
            self:SetError("Failed to find homie node '%s'", self.property_path)
        end
        self.subscribed = nil
    end

    if (not self.subscribed) and self.device.property then
        self.device.property:Subscribe(self)
    end
end

function StateHomie:PropertyStateChanged(property, value, timestamp)
    self.subscribed = value ~= nil
    if not self.subscribed then
        return
    end

    self.settable = property:IsSettable()

    if self.expected_value then
        self.device.property:SetValue(self.expected_value.value)
    end
end

function StateHomie:SourceChanged(source, source_value)
    self:SetValue(source_value)
    return self.super.SetValue(self, source, source_value)
end

function StateHomie:IsReady()
    return self.subscribed and (self:GetValue() ~= nil)
end

-------------------------------------------------------------------------------------

return StateHomie
