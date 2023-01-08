-------------------------------------------------------------------------------------

local RemoteValue = { }
RemoteValue.__base = "base/property/base-value"
RemoteValue.__type = "class"
RemoteValue.__class_name = "RemoteValue"

-------------------------------------------------------------------------------------

function RemoteValue:Init(config)
    RemoteValue.super.Init(self, config)
    self.owner:Subscribe(self, self.PropertyChanged)
    self.owner.property_handle = self
end

function RemoteValue:PostInit()
    RemoteValue.super.PostInit(self)
    self:PropertyChanged(self.owner)
end

-------------------------------------------------------------------------------------

function RemoteValue:PropertyChanged(remote_prop)
    self:CallSubscribers()
end

-------------------------------------------------------------------------------------

function RemoteValue:IsPersistent()
    return self.owner:IsPersistent()
end

function RemoteValue:GetDatatype()
    return self.owner:GetDatatype()
end

function RemoteValue:GetUnit()
    return self.owner:GetUnit()
end

function RemoteValue:GetName()
    return self.owner:GetName()
end

function RemoteValue:GetId()
    return self.owner:GetId()
end

function RemoteValue:GetValue()
    return self.owner:GetValue()
end

-------------------------------------------------------------------------------------

return RemoteValue
