
-------------------------------------------------------------------------------------

local BaseValue = { }
BaseValue.__base = "base/property/base-object"
BaseValue.__type = "interface"
BaseValue.__name = "BaseValue"

-------------------------------------------------------------------------------------

function BaseValue:Init(config)
    BaseValue.super.Init(self, config)
end

function BaseValue:PostInit()
    BaseValue.super.PostInit(self)
    self.database = self.property_manager:GetValueDatabase(self)
    if self.database then
        self:Subscribe(self, self.UpdateDatabase)
    end
end

-------------------------------------------------------------------------------------

function BaseValue:GetValue()
    AbstractMethod()
end

function BaseValue:GetDatatype()
    AbstractMethod()
end

function BaseValue:GetUnit()
    AbstractMethod()
end

function BaseValue:GetDatabaseId()
    return string.format("property.value.%s", self:GetGlobalId())
end

function BaseValue:GetOwnerDeviceName()
    if self.owner and self.owner.GetOwnerDeviceName then
        return self.owner:GetOwnerDeviceName()
    end
end

-------------------------------------------------------------------------------------

function BaseValue:UpdateDatabase()
    if self.database then
        local v,t = self:GetValue()
        if t ~= nil then
            self.database:Insert({value=v, timestamp=t})
        end
    end
end

function BaseValue:Query(timestamp_from, timestamp_to)
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

return BaseValue
