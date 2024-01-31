local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local BaseDevice = { }
BaseDevice.__base = "manager-device/generic/base-object"
BaseDevice.__type = "interface"
BaseDevice.__name = "BaseDevice"
BaseDevice.__deps = {
    device_manager = "manager-device",
    component_manager = "manager-device/manager-component",
}

-------------------------------------------------------------------------------------

BaseDevice.DeviceStateEnum = {
    unknown = "unknown",
    init = "init",
    ready = "ready",
    ota = "ota",
}

-------------------------------------------------------------------------------------

function BaseDevice:Init(config)
    BaseDevice.super.Init(self, config)

    self.group = config.group
    assert(self.group)
    self.state = self.DeviceStateEnum.unknown
    if config.state then
        self:EnterState(config.state)
    end

    self.components = { }
    self.start_time = os.timestamp()
end

function BaseDevice:StartDevice()
    self.started = true
    self:SetReady(false)
    for _,v in pairs(self.components) do
        if not v:IsStarted() then
            v:StartComponent()
        end
    end
end

function BaseDevice:StopDevice()
    self.started = false
    self:StopAllTasks()
    for _,v in pairs(self.properties) do
        if v:IsStarted() then
            v:StopComponent()
        end
    end
end

function BaseDevice:Restart()
    warning(self, "Restart operation is not supported")
end

-------------------------------------------------------------------------------------

function BaseDevice:GetUptime()
    return os.timestamp() - self.start_time
end

function BaseDevice:GetErrorCount()
    NotImplemented()
    return 0
end

function BaseDevice:GetActiveErrors()
    NotImplemented()
    return { }
end

function BaseDevice:IsReady()
    if not self.ready then
        return false
    end
    for k,v in pairs(self.components) do
        if not v:IsReady() then
            return false
        end
    end
    return true
end

-------------------------------------------------------------------------------------

function BaseDevice:SetError(id, message)
    return self:GetErrorManager():SetDeviceError(self, id, message)
end

function BaseDevice:ClearError(id)
    return self:GetErrorManager():ClearDeviceError(self, id)
end

-------------------------------------------------------------------------------------

function BaseDevice:GetState()
    return self.state
end

function BaseDevice:EnterState(new_state)
    if self.state == new_state then
        return
    end
    local prev_state = self.state
    self.state = new_state
    printf(self, "State changed %s->%s", prev_state, new_state)

    self:EmitEvent({
        action = "state-change",
        old_state = prev_state,
        new_state = new_state,
    })
end

-------------------------------------------------------------------------------------

function BaseDevice:IsLocal()
    AbstractMethod()
end

function BaseDevice:GetConnectionProtocol()
    AbstractMethod()
end

function BaseDevice:GetHardwareId()
    return nil
end

function BaseDevice:GetGroup()
    return self.group
end

function BaseDevice:IsFairyNodeDevice()
    return false
end

-------------------------------------------------------------------------------------

function BaseDevice:GetComponents()
    return self.components
end

function BaseDevice:ComponentKeys()
    return table.sorted_keys(self.components)
end

function BaseDevice:ComponentGlobalIds()
    local r = { }
    for _,p in pairs(self.components) do
        table.insert(r, p:GetGlobalId())
    end
    table.sort(r)
    return r
end

function BaseDevice:GetComponent(key)
    return self.components[key]
end

-------------------------------------------------------------------------------------

function BaseDevice:EmitEvent(arg)
    assert(arg.action)
    arg.device = self
    local event = string.format("device.%s", arg.action)
    self.device_manager:EmitEvent(event, arg)
end

-------------------------------------------------------------------------------------

function BaseDevice:GetProperty(component, property)
    local c = self:GetComponent(component)
    if c then
        return c:GetProperty(property)
    end
end

function BaseDevice:GetPropertyValue(component, property)
    local p = self:GetProperty(component, property)
    if p then
        return p:GetValue()
    end
end

-------------------------------------------------------------------------------------

function BaseDevice:GetSummary()
    local components = { }
    for k,v in pairs(self.components) do
        components[k] = v:GetSummary()
    end

    return {
        name = self:GetName(),
        id = self:GetId(),
        global_id = self:GetGlobalId(),
        components = tablex.values(components)
    }
end

function BaseDevice:DeleteAllComponents()
    for _,v in ipairs(table.keys(self.components)) do
        self:DeleteComponent(v)
    end
    self.components = { }
end

function BaseDevice:DeleteComponent(comp_id)
    local comp = self.components[comp_id]
    if comp:IsStarted() then
        comp:StopComponent()
    end
    self.component_manager:DeleteCompnent(comp)
    self.components[comp_id] = nil
end

function BaseDevice:AddComponent(opt)
    assert(opt.class)

    opt.owner_device = self

    local obj = self.component_manager:CreateComponent(opt)
    local id = obj:GetId()

    assert(self.components[id] == nil)
    self.components[id] = obj

    if self:IsStarted() then
        obj:StartComponent()
    end

    return obj
end

-------------------------------------------------------------------------------------

return BaseDevice
