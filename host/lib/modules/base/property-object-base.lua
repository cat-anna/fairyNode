-------------------------------------------------------------------------------------

local ValueMt = {}
ValueMt.__index = ValueMt

function ValueMt:GetValue()
    return self.value, self.timestamp
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
        -- value.observers = existing.observers or table.weak()

--         node.sensor = node.sensor or table.weak{ instance = self }

        value.id = id
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

function PropertyObject:UpdateAll(all)
    local timestamp = os.timestamp()
    for k,v in pairs(all) do
        self:Update(k, v, timestamp)
    end
end

function PropertyObject:Update(id, value, timestamp)
    timestamp = timestamp or os.timestamp()

    local v = self.values[id]
    -- print(self, id, v.value, value, timestamp)
    if v.value ~= value then
        v.value = value
        v.timestamp = timestamp
        -- self:CallObserverList(self.observers, v)
        -- self:CallObserverList(v.observers, v)
    end
end

-------------------------------------------------------------------------------------

function PropertyObject:AddObserver(target)
    -- self.observers[target.uuid] = target
    -- for _,v in pairs(self.values) do
    --     self:CallObserver(target, v)
    -- end
end

-- function PropertyObject:ObserveValue(target, node)
--     self.values[node.id].observers[target.uuid] = target
--     self:CallObserver(target, node)
-- end

-------------------------------------------------------------------------------------

function PropertyObject:CallObserverList(list, value)
    -- for _,v in pairs(list or { }) do
    --     self:CallPropertyObserver(v, value)
    -- end
end

function PropertyObject:CallPropertyObserver(target, value)
    -- SafeCall(function ()  --
    --     target:OnPropertyChanged(self, value)
    -- end)
end

-------------------------------------------------------------------------------------

return PropertyObject
