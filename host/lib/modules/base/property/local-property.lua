
local LocalProperty = { }
LocalProperty.__base = "base/property/base-property"
LocalProperty.__type = "class"
LocalProperty.__name = "LocalProperty"

-------------------------------------------------------------------------------------

function LocalProperty:Init(config)
    LocalProperty.super.Init(self, config)
    self:InitProperties(config.values)
end

function LocalProperty:PostInit()
    LocalProperty.super.PostInit(self)
    self.ready = true
end

-------------------------------------------------------------------------------------

function LocalProperty:InitProperties(new_values)
    for id,new_value in pairs(new_values or {}) do
        local opt = {
            name = new_value.name,

            datatype = new_value.datatype,
            unit = new_value.unit,
            value = new_value.value,
            timestamp = new_value.timestamp,

            id = id,
            global_id = string.format("%s.%s", self.global_id, id),

            class = "base/property/local-value",
        }

        self:AddValue(opt)
    end
end

-------------------------------------------------------------------------------------

function LocalProperty:UpdateValue(id, updated_value, timestamp)
    local value_object = self.values[id]
    assert(value_object)
    return value_object:Update(updated_value, timestamp)
end

function LocalProperty:UpdateValues(all)
    local timestamp = os.timestamp()
    local any = false
    for k,v in pairs(all) do
        local r = self:UpdateValue(k, v, timestamp)
        any = any or r
    end

    if any then
        self:CallSubscribers()
    end
end

-------------------------------------------------------------------------------------

return LocalProperty
