

-------------------------------------------------------------------------------------

local LocalValue = { }
LocalValue.__base = "base/property/base-value"
LocalValue.__type = "class"
LocalValue.__name = "LocalValue"

-------------------------------------------------------------------------------------

function LocalValue:Init(config)
    LocalValue.super.Init(self, config)

    self.datatype = config.datatype
    self.unit = config.unit
    self.value = config.value
    self.timestamp = config.timestamp or 0
end

-- function LocalValue:PostInit()
--     LocalValue.super.PostInit(self)
-- end

-------------------------------------------------------------------------------------

function LocalValue:GetValue()
    return self.value, self.timestamp
end

function LocalValue:GetDatatype()
    if not self.datatype then
        print(self, "Datatype is not set!")
    end
    return self.datatype or "string"
end

function LocalValue:GetUnit()
    return self.unit
end

-------------------------------------------------------------------------------------

function LocalValue:Update(updated_value, timestamp)
    timestamp = timestamp or os.timestamp()
    if (self.value == updated_value) and (timestamp - self.timestamp < 60 * 60) then
        return false
    end

    self.value = updated_value
    self.timestamp = timestamp

    self:CallSubscribers()

    return true
end

-------------------------------------------------------------------------------------

return LocalValue
