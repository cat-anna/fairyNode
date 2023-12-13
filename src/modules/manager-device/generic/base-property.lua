
-------------------------------------------------------------------------------------

local BaseProperty = { }
BaseProperty.__base = "modules/manager-device/generic/base-object"
BaseProperty.__type = "interface"
BaseProperty.__name = "BaseProperty"

-------------------------------------------------------------------------------------

function BaseProperty:Init(config)
    BaseProperty.super.Init(self, config)
    self.property_type = config.property_type or 'value'
    self.owner_component = config.owner_component
    assert(self.owner_component)
end

function BaseProperty:StartProperty()
    self.started = true
end

function BaseProperty:StopProperty()
    self.started = false
end

-------------------------------------------------------------------------------------

function BaseProperty:IsStarted()
    return self.started
end

function BaseProperty:GetType()
    return self.property_type
end

function BaseProperty:GetValue()
end

function BaseProperty:GetDatatype()
end

function BaseProperty:GetUnit()
end

function BaseProperty:GetDatabaseId()
    return string.format("property.value.%s", self:GetGlobalId())
end

-- function BaseProperty:GetOwnerDeviceName()
--     if self.owner and self.owner.GetOwnerDeviceName then
--         return self.owner:GetOwnerDeviceName()
--     end
-- end

-------------------------------------------------------------------------------------

-- function BaseProperty:UpdateDatabase()
--     if self.database then
--         local v,t = self:GetValue()
--         if t ~= nil then
--             self.database:Insert({value=v, timestamp=t})
--         end
--     end
-- end

-- function BaseProperty:Query(timestamp_from, timestamp_to)
--     if not self.database then
--         return
--     end

--     if not timestamp_from then
--         timestamp_from = os.timestamp() - 60 * 60 -- last hour
--     end

--     local q = self.database:FetchRange("timestamp", timestamp_from, timestamp_to)
--     if not q then
--         return
--     end

--     local r = {}
--     for _,v in ipairs(q) do
--         table.insert(r, { value = v.value, timestamp = v.timestamp })
--     end
--     return {
--         from = timestamp_from,
--         to = timestamp_to,
--         list = r,
--     }
-- end

-------------------------------------------------------------------------------------

return BaseProperty
