
-------------------------------------------------------------------------------------

local BaseDevice = { }
BaseDevice.__base = "modules/manager-device/generic/base-object"
BaseDevice.__type = "interface"
BaseDevice.__name = "BaseDevice"
BaseDevice.__deps = {
    component_manager = "manager-device/manager-component",
}

-------------------------------------------------------------------------------------

function BaseDevice:Init(config)
    BaseDevice.super.Init(self, config)

    self.group = config.group
    assert(self.group)

    self.components = { }
    self.start_time = os.timestamp()
end

function BaseDevice:StartDevice()
    self.started = true
    for _,v in pairs(self.components) do
        if not v:IsStarted() then
            v:StartComponent()
        end
    end
end

function BaseDevice:StopDevice()
    self.started = false
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

-------------------------------------------------------------------------------------

function BaseDevice:IsStarted()
    return self.started
end

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

-------------------------------------------------------------------------------------

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

function BaseDevice:GetComponents()
    return self.components
end

-------------------------------------------------------------------------------------

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