-------------------------------------------------------------------------------------

local BaseObject = { }
BaseObject.__type = "interface"
BaseObject.__name = "BaseObject"

-------------------------------------------------------------------------------------

function BaseObject:Init(config)
    BaseObject.super.Init(self, config)

    self.name = config.name or "?"
    self.ready = config.ready

    self.id = config.id
    self.global_id = config.global_id

    assert(self.id)
    assert(self.global_id)
end

function BaseObject:Tag()
    return self:GetGlobalId() or BaseObject.super.Tag(self)
end

-------------------------------------------------------------------------------------

function BaseObject:SetReady(r)
    self.ready = r
end

function BaseObject:IsReady()
    return self.ready
end

function BaseObject:GetId()
    return self.id
end

function BaseObject:GetGlobalId()
    return self.global_id
end

function BaseObject:GetName()
    return self.name
end

-------------------------------------------------------------------------------------

return BaseObject
