-------------------------------------------------------------------------------------

local ValueMt = {}
ValueMt.__index = ValueMt

function ValueMt:GetValue()
    return self.value, self.timestamp
end

function ValueMt:AddObserver(target)
    self.observers[target.uuid] = target
end

-- function SensorNodeMt:Sensor()
--     return self.sensor.instance
-- end

-------------------------------------------------------------------------------------

local PropertyObject = { }
PropertyObject.__type = "class"
PropertyObject.__class_name = "PropertyObject"

-------------------------------------------------------------------------------------

function PropertyObject:Init(config)
    if config.uuid then
        self.uuid = config.uuid
    end

    self.owner = config.owner
    self.manager = config.manager

    self.global_id = config.global_id
    self.property_type = config.property_type
    self.readout_mode = config.readout_mode

    self.id = config.id
    self.name = config.name

    self.observers = table.weak()

    -- self.change_history = { }

    self:Reset(config.values or { })

    self.ready = true
end

function PropertyObject:BeforeReload()
end

function PropertyObject:AfterReload()
end

function PropertyObject:Tag()
    return self.global_id or "PropertyObject"
end

-------------------------------------------------------------------------------------

function PropertyObject:ValueKeys()
    return table.sorted_keys(self.values)
end

function PropertyObject:GetValue(key)
    return self.values[key]
end

-------------------------------------------------------------------------------------

function PropertyObject:IsSensor()
    return self.readout_mode == "sensor"
end

function PropertyObject:IsProperty()
    return self.readout_mode == "passive"
end

function PropertyObject:IsLocal()
    return self.property_type == "local"
end

function PropertyObject:IsRemote()
    return self.property_type == "remote"
end

function PropertyObject:IsReady()
    return self.ready
end

-------------------------------------------------------------------------------------

function PropertyObject:Readout()
    self:ReadoutSlow()
    self:ReadoutFast()
end

function PropertyObject:ReadoutSlow()
    -- print(self, "PropertyObject:ReadoutSlow")
    -- nothing
end

function PropertyObject:ReadoutFast()
    -- print(self, "PropertyObject:ReadoutFast")
    -- nothing
end

-------------------------------------------------------------------------------------

function PropertyObject:Reset(new_values)

    local prev_values = self.values or { }
    self.values = { }

    for id,new_value in pairs(new_values or {}) do
        local existing = prev_values[id] or { }

        local value = { }
        value.observers = existing.observers or table.weak()

--         node.sensor = node.sensor or table.weak{ instance = self }

        value.id = id
        value.name = new_value.name

        value.datatype = new_value.datatype
        value.unit = new_value.unit

        value.value = new_value.value
        value.timestamp = new_value.timestamp

        value.local_id = string.format("%s.%s", self.id, id)
        value.global_id = string.format("%s.%s", self.global_id, id)

        self.values[id] = setmetatable(value, ValueMt)
    end
end

-------------------------------------------------------------------------------------

function PropertyObject:UpdateValue(id, updated_value, timestamp)
    timestamp = timestamp or os.timestamp()

    local value_object = self.values[id]
    -- print(self, id, v.value, value, timestamp)
    if value_object.value ~= updated_value then
        value_object.value = updated_value
        value_object.timestamp = timestamp
        for _,v in pairs(value_object.observers or { }) do
            self:CallValueObserver(v, value_object)
        end
        return value_object
    end
end

function PropertyObject:UpdateAll(all)
    local timestamp = os.timestamp()
    local any = false
    for k,v in pairs(all) do
        local r = self:UpdateValue(k, v, timestamp)
        any = any or r
    end

    if any then
        for _,v in pairs(self.observers or { }) do
            self:CallPropertyObserver(v)
        end
    end
end

function PropertyObject:Update(id, value, timestamp)
    if self:UpdateValue(id, value, timestamp) then
        for _,v in pairs(self.observers or { }) do
            self:CallPropertyObserver(v)
        end
    end
end

-------------------------------------------------------------------------------------

function PropertyObject:AddObserver(target)
    self.observers[target.uuid] = target
    for _,v in pairs(self.values) do
        self:CallPropertyObserver(target, v)
    end
end

function PropertyObject:ObserveValue(target, value)
    self.values[value.id].observers[target.uuid] = target
    self:CallValueObserver(target, value)
end

-------------------------------------------------------------------------------------

function PropertyObject:CallPropertyObserver(target)
    SafeCall(function ()  --
        target:OnPropertyChanged(self)
    end)
end

function PropertyObject:CallValueObserver(target, value)
    SafeCall(function ()  --
        target:OnPropertyValueChanged(self, value)
    end)
end

-------------------------------------------------------------------------------------

return PropertyObject
