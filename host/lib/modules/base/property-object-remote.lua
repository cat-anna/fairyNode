
local ValueMt = {}
ValueMt.__index = ValueMt

function ValueMt:AddObserver(target)
    self.observers[target.uuid] = target
end

function ValueMt:GetDatatype()
    return self.owner:GetDatatype()
end

function ValueMt:GetUnit()
    return self.owner:GetUnit()
end

function ValueMt:GetName()
    return self.owner:GetName()
end

function ValueMt:GetId()
    return self.owner:GetId()
end

function ValueMt:GetValue()
    return self.owner:GetValue()
end

-------------------------------------------------------------------------------------

local PropertyObjectRemote = { }
PropertyObjectRemote.__base = "base/property-object-base"
PropertyObjectRemote.__type = "class"
PropertyObjectRemote.__class_name = "PropertyObjectRemote"

-------------------------------------------------------------------------------------

function PropertyObjectRemote:Init(config)
    PropertyObjectRemote.super.Init(self, config)
end

function PropertyObjectRemote:PostInit()
    PropertyObjectRemote.super.PostInit(self)
end

-------------------------------------------------------------------------------------

function PropertyObjectRemote:Reset(new_values)

    local prev_values = self.values or { }
    self.values = { }

    for id,new_value in pairs(new_values or {}) do
        local existing = prev_values[id] or { }

        local value = { }
        value.observers = existing.observers or table.weak()
        value.owner = new_value

        value.local_id = string.format("%s.%s", self.id, id)
        value.global_id = string.format("%s.%s", self.global_id, id)

        self.values[id] = setmetatable(value, ValueMt)
    end
end

-------------------------------------------------------------------------------------

return PropertyObjectRemote
