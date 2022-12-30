
local loader_class = require "lib/loader-class"

-------------------------------------------------------------------------------------

local BaseProperty = { }
BaseProperty.__base = "base/property/base-object"
BaseProperty.__type = "interface"
BaseProperty.__class_name = "BaseProperty"

-------------------------------------------------------------------------------------

function BaseProperty:Init(config)
    BaseProperty.super.Init(self, config)

    self.values = { }
    self.property_type = config.property_type
    self.readout_mode = config.readout_mode
    self.remote_name = config.remote_name
    self.source_name = config.source_name
end

-- function BaseProperty:PostInit()
--     BaseProperty.super.PostInit(self)
-- end

-------------------------------------------------------------------------------------

function BaseProperty:IsSensor()
    return self.readout_mode == "sensor"
end

function BaseProperty:IsProperty()
    return self.readout_mode == "passive"
end

function BaseProperty:IsLocal()
    return self.property_type == "local"
end

function BaseProperty:IsRemote()
    return self.property_type == "remote"
end

-------------------------------------------------------------------------------------

function BaseProperty:ValueKeys()
    return table.sorted_keys(self.values)
end

function BaseProperty:ValueGlobalIds()
    local r = { }
    for _,p in pairs(self.values) do
        table.insert(r, p:GetGlobalId())
    end
    table.sort(r)
    return r
end

function BaseProperty:GetValue(key)
    return self.values[key]
end

function BaseProperty:GetValues()
    return self.values
end

function BaseProperty:GetSourceName()
    return self.source_name
end

-------------------------------------------------------------------------------------

function BaseProperty:AddValue(opt)
    assert(opt.class)

    opt.owner_property = self
    opt.property_manager = self.property_manager

    local value_obj = loader_class:CreateObject(opt.class, opt)
    local id = value_obj:GetId()

    assert(self.values[id] == nil)
    self.values[id] = value_obj

    return value_obj
end

-------------------------------------------------------------------------------------

return BaseProperty
