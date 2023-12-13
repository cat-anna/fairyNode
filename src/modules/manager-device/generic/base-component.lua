
local loader_class = require "fairy_node/loader-class"

-------------------------------------------------------------------------------------

local BaseComponent = { }
BaseComponent.__base = "modules/manager-device/generic/base-object"
BaseComponent.__type = "interface"
BaseComponent.__name = "BaseComponent"
BaseComponent.__deps = {
    property_manager = "manager-device/manager-property",
}

-------------------------------------------------------------------------------------

function BaseComponent:Init(config)
    BaseComponent.super.Init(self, config)

    self.owner_device = config.owner_device
    self.component_type = config.component_type

    assert(self.owner_device)
    assert(self.component_type)

    self.properties = { }
end

function BaseComponent:StartComponent()
    self.started = true
    for _,v in pairs(self.properties) do
        if not v:IsStarted() then
            v:StartProperty()
        end
    end
end

function BaseComponent:StopComponent()
    self.started = false
    for _,v in pairs(self.properties) do
        if v:IsStarted() then
            v:StopProperty()
        end
    end
end

-------------------------------------------------------------------------------------

function BaseComponent:IsStarted()
    return self.started
end

function BaseComponent:GetType()
    return self.component_type
end

-------------------------------------------------------------------------------------

function BaseComponent:PropertyKeys()
    return table.sorted_keys(self.properties)
end

-- function BaseComponent:ValueGlobalIds()
--     local r = { }
--     for _,p in pairs(self.values) do
--         table.insert(r, p:GetGlobalId())
--     end
--     table.sort(r)
--     return r
-- end

function BaseComponent:GetProperty(key)
    return self.properties[key]
end

-------------------------------------------------------------------------------------

function BaseComponent:DeleteAllProperties()
    for _,v in ipairs(table.keys(self.properties)) do
        self:DeleteProperty(v)
    end
    self.properties = { }
end

function BaseComponent:DeleteProperty(prop_id)
    local prop = self.properties[prop_id]
    if prop:IsStarted() then
        prop:StopProperty()
    end
    self.property_manager:DeleteProperty(prop)
    self.properties[prop_id] = nil
end

function BaseComponent:AddProperty(opt)
    assert(opt.class)

    opt.owner_component = self
    opt.owner_device = self.owner_device

    local prop = self.property_manager:CreateProperty(opt)
    if self:IsStarted() then
        prop:StartProperty()
    end

    local id = prop:GetId()
    assert(self.properties[id] == nil)
    self.properties[id] = prop
    return prop
end

-------------------------------------------------------------------------------------

return BaseComponent