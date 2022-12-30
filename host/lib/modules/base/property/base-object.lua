-------------------------------------------------------------------------------------

local PropertyBaseObject = { }
PropertyBaseObject.__type = "interface"
PropertyBaseObject.__class_name = "PropertyBaseObject"

-------------------------------------------------------------------------------------

function PropertyBaseObject:Init(config)
    PropertyBaseObject.super.Init(self, config)

    self.global_id = config.global_id
    self.id = config.id
    self.name = config.name

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

-------------------------------------------------------------------------------------

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
