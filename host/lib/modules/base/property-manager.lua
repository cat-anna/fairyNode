local tablex = require "pl.tablex"
local scheduler = require "lib/scheduler"
local loader_class = require "lib/loader-class"
local loader_module = require "lib/loader-module"
-- local stringx = require "pl.stringx"
-- local uuid = require "uuid"

-------------------------------------------------------------------------------

local pairs = pairs
local ipairs = ipairs

-------------------------------------------------------------------------------

local PROPERTY_TYPE_LOCAL = "local"
local PROPERTY_TYPE_REMOTE = "remote"

local PROPERTY_MODE_SENSOR = "sensor"
local PROPERTY_MODE_PASSIVE = "passive"

local CONFIG_KEY_SENSOR_FAST_INTERVAL =   "module.property.sensor.interval.fast"
local CONFIG_KEY_SENSOR_SLOW_INTERVAL =   "module.property.sensor.interval.slow"
-- local CONFIG_KEY_PROPERTY_SKIP_AGE =   "module.property.history.skip.age"

-------------------------------------------------------------------------------

local PropertyManager = {}
PropertyManager.__stats = true
PropertyManager.__deps = {
    -- sensor_handler = "base/sensors",
    -- server_storage = "base/server-storage",
    -- mongo_connection = "mongo/mongo-connection",
}
PropertyManager.__config = {
    -- [CONFIG_KEY_SENSOR_FAST_INTERVAL] =   { type = "integer", default = 60 },
    -- [CONFIG_KEY_PROPERTY_SKIP_AGE] =   { type = "integer", default = 60*60 },
}

-------------------------------------------------------------------------------

function PropertyManager:Tag()
    return "PropertyManager"
end

function PropertyManager:AfterReload()
    -- self.sensor_handler:AddSensorSink(self)
end

function PropertyManager:BeforeReload()
end

function PropertyManager:Init()
    self.properties_by_id = { }

    self.local_sensors = { }
    self.local_properties = { }

--[[
    self.collection = {
        PropertyManager = self.mongo_connection:GetCollection("property_list"),
        history = self.mongo_connection:GetCollection("property_history"),
    }

    self.local_objects = {
        sensors = table.weak_values(),
        -- groups = { },
        PropertyManager = { },
        property_list = { },
    }

    self.local_objects.property_list = self.collection.PropertyManager:FetchAll()
    for _,item in ipairs(self.local_objects.property_list ) do
        -- if not self.local_objects.groups[item.global_id] then
        --     self.local_objects.groups[item.global_id] = table.weak_values()
        -- end
        self.local_objects.PropertyManager[item.global_id] = item
        item.uuid = uuid()
    end

--]]

    -- self.remote_objects = {
    --     sensors = { },
    -- }

    -- self.PropertyManager = table.weak()
    -- self.sensor_sink = table.weak()
end

function PropertyManager:PostInit()
    loader_module:EnumerateModules(
        function(name, module)
            if module.InitProperties then
                module:InitProperties(self)
            end
        end)
end

function PropertyManager:StartModule()
    local intervals = {
        Fast = 1,  -- self.config[CONFIG_KEY_SENSOR_FAST_INTERVAL],
        Slow = 10, --self.config[CONFIG_KEY_SENSOR_SLOW_INTERVAL],
    }

    self.tasks = { }
    for k,v in pairs(intervals) do
        local func_name = string.format("DoSensorReadout%s", k)
        self.tasks[k] = scheduler:CreateTask(
            self,
            string.format("Sensor update %s", k:lower()),
            v,
            function (owner, task) --
                owner[func_name](owner, task)
            end
        )
    end

    -- for k,v in pairs(self.PropertyManager) do
    --     v:Readout()
    -- end

    self.started = true

    self:DoSensorReadout()
end

-------------------------------------------------------------------------------

function PropertyManager:GetProperty(global_id)
    return self.properties_by_id[global_id]
end

function PropertyManager:GetLocalProperties()
    return table.sorted_keys(self.local_properties)
end

-------------------------------------------------------------------------------

-- function PropertyManager:SensorAdded(sensor)
    --[[
    print(self, "Adding sensor")
    local local_objects = self.local_objects
    local_objects.sensors[sensor.uuid] = sensor

    for node_name,node in pairs(sensor.node) do
        local global_id, group_id, full_path = self:GetGlobalSensorNodeId(sensor, node)

        local property = local_objects.PropertyManager[global_id]
        if not property then
            property = self:CreateProperty {
                global_id = global_id,
                group_id = group_id,
                -- full_path = full_path,
                name = node.name,
                type = "sensor",
                -- uuid = uuid(),
            }
        end

        -- assert(self.local_objects.groups[global_id])
        -- local group = self.local_objects.groups[global_id]
        -- group[global_id] = property

        -- property.target = table.weak_values{
        --     node = node,
        --     sensor = sensor,
        -- }

        -- sensor:ObserveNode(property, node)

        printf(self, "Added property %s", property.global_id)
    end

    --]]
-- end

-------------------------------------------------------------------------------

-- function PropertyManager:AddSink(target)
--     self.sensor_sink[target.uuid] = target
--     for _,v in pairs(self.PropertyManager) do
--         target:SensorAdded(v)
--     end
-- end

function PropertyManager:RegisterSensor(opt)
    opt.readout_mode = PROPERTY_MODE_SENSOR
    return self:RegisterLocalProperty(opt)
end


function PropertyManager:RegisterLocalProperty(opt)
    opt.property_type = PROPERTY_TYPE_LOCAL
    return self:RegisterProperty(opt)
end

function PropertyManager:RegisterRemoteProperty(opt)
    opt.property_type = PROPERTY_TYPE_REMOTE
    return self:RegisterProperty(opt)
end

local function CreatePropertyObject(opt)
    local base_class = "base/property-object-base"
    if not opt.class then
        opt.class = base_class
    end

    local t = type(opt.class)
    if t == "string" then
        return loader_class:CreateObject(opt.class, opt)
    elseif t == "table" then
        return loader_class:CreateSubObject(opt.class, base_class, opt)
    end

    assert(false) -- TODO
end

function PropertyManager:RegisterProperty(opt)
    opt.property_type =  opt.property_type or PROPERTY_TYPE_LOCAL
    opt.readout_mode = opt.readout_mode or PROPERTY_MODE_PASSIVE

    opt.global_id = string.format("%s.%s.%s",
            opt.readout_mode,
            opt.property_type,
            opt.id)

    opt.manager = self

    local object = CreatePropertyObject(opt)

    self.properties_by_id[object.global_id] = object

    if object:IsSensor() then
        self.local_sensors[object.global_id] = object
    end

    if object:IsLocal() then
        self.local_properties[object.global_id] = object
    end

    return object

--[[
    self.local_objects.PropertyManager[opt.global_id] = opt

    table.insert(self.local_objects.property_list, opt)
    local MT = { }
    function MT:SensorNodeChanged(sensor, node)
        local v, t = node:GetValue()
        if v ~= nil and t ~= nil then
            self:PushValue({ value = v, timestamp = t })
        end
    end

    function MT:PushValue(vt)
        vt.property = self.global_id
        self.controller:PushPropertyValue(self, vt)
    end

    self.collection.PropertyManager:Insert(opt)
--]]
end

-------------------------------------------------------------------------------

-- function PropertyManager:RegisterProperty(def)
    -- local owner = def.owner
    -- assert(owner)

    -- def.id = def.id or owner.__name
    -- def.nodes = def.nodes or { }

    -- owner.registered_PropertyManager = owner.registered_PropertyManager or { }

    -- local s = self.PropertyManager[def.id]
    -- if not s then
    --     s = self.loader_class:CreateObject("base/sensor-object", def)
    --     s.sensor_host = self
    --     self.PropertyManager[def.id] = s
    -- else
    --     s:Reset(def)
    -- end

    -- owner.registered_PropertyManager[s.id] = s

    -- for _,v in pairs(self.sensor_sink) do
    --     v:SensorAdded(s)
    -- end

    -- if self.module_started then
    --     s:Readout()
    -- end

    -- return s
-- end

-------------------------------------------------------------------------------

function PropertyManager:DoSensorReadout()
    for k,v in pairs(self.local_sensors) do
        v:Readout()
    end
end

function PropertyManager:DoSensorReadoutSlow()
    for k,v in pairs(self.local_sensors) do
        v:ReadoutSlow()
    end
end

function PropertyManager:DoSensorReadoutFast()
    for k,v in pairs(self.local_sensors) do
        v:ReadoutFast()
    end
end

-------------------------------------------------------------------------------

-- function PropertyManager:PushPropertyValue(property, entry)
--[[
    if property.last_history_entry then
        local lhe = property.last_history_entry
        local age = os.timestamp() - lhe.timestamp
        if (age < self.config[CONFIG_KEY_PROPERTY_SKIP_AGE]) and
           (lhe.value == entry.value or lhe.timestamp == entry.timestamp) then
            return
        end
    end

    property.last_history_entry = entry
    self.collection.history:Insert(entry)
--]]
-- end

-------------------------------------------------------------------------------

-- function PropertyManager:GetPathBuilder(result_callback)
--     return require("lib/path_builder").PathBuilderWrapper({
--         name = "Sensor",
--         host = self,
--         path_getters = {
--             function (t, obj) return obj.PropertyManager[t] end,
--             function (t, obj) return obj.node[t] end,
--         },
--         result_callback = result_callback,
--     })
-- end

-------------------------------------------------------------------------------

function PropertyManager:GetStatistics()
    local header = {
        "what",
        "global_id",
        "mode",
        "type",
        "value",
        "unit",
        "timestamp",
        "datatype",
    }

    local r = { }

    for _,id in ipairs(table.sorted_keys(self.properties_by_id)) do
        -- print(self, id)
        local p = self.properties_by_id[id]
        table.insert(r, {
            "property",
            p.global_id,
            p.readout_mode,
            p.property_type,

        })

        for _,key in ipairs(table.sorted_keys(p.values)) do
            local v = p.values[key]
            -- print(self, v.global_id)
            table.insert(r, {
                "value",
                v.global_id,
                p.readout_mode,
                p.property_type,
                v.value,
                v.unit,
                v.timestamp,
                v.datatype,
            })
        end
    end

    return { header = header, data = r }
end

-------------------------------------------------------------------------------

return PropertyManager
