local loader_module = require "fairy_node/loader-module"

-------------------------------------------------------------------------------------

local BaseProperty = { }
BaseProperty.__base = "modules/manager-device/generic/base-object"
BaseProperty.__type = "interface"
BaseProperty.__name = "BaseProperty"

-------------------------------------------------------------------------------------

function BaseProperty:Init(config)
    BaseProperty.super.Init(self, config)
    self.property_type = config.property_type
    self.owner_component = config.owner_component
    self.property_manager = config.property_manager

    assert(self.owner_component)
    assert(self.property_manager)
end

function BaseProperty:StartProperty()
    self.started = true
    self:OpenDatabase()
end

function BaseProperty:StopProperty()
    self.started = false
    self:CloseDatabase()
    self:StopAllTasks()
end

-------------------------------------------------------------------------------------

function BaseProperty:GetSummary()
    local v,t = self:GetValue()
    return {
        datatype = self:GetDatatype(),
        global_id = self:GetGlobalId(),
        id = self:GetId(),
        name = self:GetName(),
        unit = self:GetUnit(),
        settable = self:IsSettable(),
        value = v,
        timestamp = t,
    }
end

-------------------------------------------------------------------------------------

function BaseProperty:GetOwnerDeviceName()
    return self.owner_component:GetOwnerDeviceName()
end

function BaseProperty:GetOwnerComponentName()
    return self.owner_component:GetName()
end

function BaseProperty:GetType()
    return self.property_type
end

function BaseProperty:IsVolatile()
    return self.volatile or false
end

function BaseProperty:IsSettable()
    return self.settable or false
end

function BaseProperty:GetValue()
    return self.value, self.timestamp
end

function BaseProperty:SetValue(value, timestamp)
    timestamp = timestamp or os.timestamp()
    local changed = self.value == value
    self.value = value
    self.timestamp = timestamp

    self:CallSubscribers("SetValue", { changed = changed })

    return changed
end

function BaseProperty:GetDatatype()
    return self.datatype
end

function BaseProperty:GetUnit()
    return self.unit
end

function BaseProperty:GetDatabaseId()
    return string.format("property.%s", self:GetGlobalId())
end

function BaseProperty:GetLegacyDatabaseId()
    return {
        string.format("property.value.%s", self:GetGlobalId()),
    }
end

-------------------------------------------------------------------------------------

function BaseProperty:UpdateDatabase()
    if self.database then
        local v,t = self:GetValue()
        if t ~= nil then
            self.database:Insert({value=v, timestamp=t})
        end
    end
end

function BaseProperty:OpenDatabase()
    if self:WantsPersistence() and (not self.database) then
        self.database = self.property_manager:OpenPropertyDatabase(self)
        self:Subscribe(self, self.UpdateDatabase)
    end
end

function BaseProperty:CloseDatabase()
    self.database = nil
    self:Unsubscribe(self)
end

function BaseProperty:Query(timestamp_from, timestamp_to)
    if not self.database then
        return
    end

    if not timestamp_from then
        timestamp_from = os.timestamp() - 60 * 60 -- last hour
    end

    local q = self.database:FetchRange("timestamp", timestamp_from, timestamp_to)
    if not q then
        return
    end

    local r = {}
    for _,v in ipairs(q) do
        table.insert(r, { value = v.value, timestamp = v.timestamp })
    end
    return {
        from = timestamp_from,
        to = timestamp_to,
        list = r,
    }
end

-------------------------------------------------------------------------------------

return BaseProperty
