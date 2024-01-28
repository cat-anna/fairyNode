local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local BaseComponent = { }
BaseComponent.__base = "manager-device/generic/base-object"
BaseComponent.__type = "interface"
BaseComponent.__name = "BaseComponent"
BaseComponent.__deps = {
    component_manager = "manager-device/manager-component",
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
    self:StopAllTasks()
    for _,v in pairs(self.properties) do
        if v:IsStarted() then
            v:StopProperty()
        end
    end
end

-------------------------------------------------------------------------------------

function BaseComponent:GetType()
    return self.component_type
end

function BaseComponent:GetOwnerDeviceName()
    return self.owner_device:GetName()
end

function BaseComponent:GetOwnerDevice()
    return self.owner_device
end

function BaseComponent:GetOwnerDeviceId()
    return self.owner_device:GetId()
end

function BaseComponent:IsReady()
    if not self.ready then
        return false
    end
    for k,v in pairs(self.properties) do
        if not v:IsReady() then
            return false
        end
    end
    return true
end

-------------------------------------------------------------------------------------

function BaseComponent:GetProperties()
    return self.properties
end

function BaseComponent:PropertyKeys()
    return table.sorted_keys(self.properties)
end

function BaseComponent:GetProperty(key)
    return self.properties[key]
end

function BaseComponent:HasProperties()
    return #table.keys(self.properties) > 0
end

-------------------------------------------------------------------------------------

function BaseComponent:EmitEvent(arg)
    assert(arg.action)
    arg.device = self:GetOwnerDevice()
    arg.component = self
    local event = string.format("component.%s", arg.action)
    self.component_manager:EmitEvent(event, arg)
end

-------------------------------------------------------------------------------------

function BaseComponent:GetSummary()
    local properties = { }
    for k,v in pairs(self.properties) do
        properties[k] = v:GetSummary()
    end
    return {
        name = self:GetName(),
        id = self:GetId(),
        global_id = self:GetGlobalId(),
        properties = tablex.values(properties)
    }
end

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
