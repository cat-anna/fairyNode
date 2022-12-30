

-------------------------------------------------------------------------------------

local LocalValue = { }
LocalValue.__base = "base/property/base-value"
LocalValue.__type = "class"
LocalValue.__class_name = "LocalValue"

-------------------------------------------------------------------------------------

function LocalValue:Init(config)
    LocalValue.super.Init(self, config)

    self.datatype = config.datatype
    self.unit = config.unit
    self.value = config.value
    self.timestamp = config.timestamp
end

-- function LocalValue:PostInit()
--     LocalValue.super.PostInit(self)
-- end

-------------------------------------------------------------------------------------

function LocalValue:GetValue()
    return self.value, self.timestamp
end

function LocalValue:GetDatatype()
    return self.datatype or "string"
end

function LocalValue:GetUnit()
    return self.unit
end

-------------------------------------------------------------------------------------

function LocalValue:Update(updated_value, timestamp)
    if self.value == updated_value then
        return false
    end

    self.value = updated_value
    self.timestamp = timestamp or os.timestamp()

    self:CallSubscribers()

    return true
end

-------------------------------------------------------------------------------------

return LocalValue
