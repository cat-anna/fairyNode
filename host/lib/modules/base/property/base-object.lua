-------------------------------------------------------------------------------------

local PropertyBaseObject = { }
PropertyBaseObject.__type = "interface"
PropertyBaseObject.__name = "PropertyBaseObject"

-------------------------------------------------------------------------------------

function PropertyBaseObject:Init(config)
    PropertyBaseObject.super.Init(self, config)

    self.global_id = config.global_id
    self.id = config.id
    self.name = config.name
    self.ready = config.ready

    self.property_manager = config.property_manager
    self.owner = config.owner
    self.owner_property = config.owner_property
end

-- function PropertyBaseObject:PostInit()
--     PropertyBaseObject.super.PostInit(self)
-- end

function PropertyBaseObject:Tag()
    return self.global_id or PropertyBaseObject.super.Tag(self)
end

function PropertyBaseObject:Finalize()
    if self.property_manager then
        self.property_manager:ReleaseObject(self)
    end
end

-------------------------------------------------------------------------------------

function PropertyBaseObject:IsPersistent()
    return true
end

function PropertyBaseObject:IsReady()
    return self.ready
end

function PropertyBaseObject:GetId()
    return self.id
end

function PropertyBaseObject:GetGlobalId()
    return self.global_id
end

function PropertyBaseObject:GetName()
    return self.name
end

-------------------------------------------------------------------------------------

return PropertyBaseObject
