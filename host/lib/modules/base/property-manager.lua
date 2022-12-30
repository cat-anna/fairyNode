
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
    mongo_connection = "mongo/mongo-connection",
}
PropertyManager.__config = {
    [CONFIG_KEY_SENSOR_FAST_INTERVAL] =   { type = "integer", default = 60 },
    [CONFIG_KEY_SENSOR_SLOW_INTERVAL] =   { type = "integer", default = 10 * 60 },

    -- [CONFIG_KEY_PROPERTY_SKIP_AGE] =   { type = "integer", default = 60*60 },
}

-------------------------------------------------------------------------------

function PropertyManager:Tag()
    return "PropertyManager"
end

function PropertyManager:AfterReload()
end

function PropertyManager:BeforeReload()
end

function PropertyManager:Init()
    self.properties_by_id = { }
    self.values_by_id = { }

    self.local_sensors = { }
    self.local_properties = { }

    self.database = self:GetManagerDatabase()
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
        Fast = self.config[CONFIG_KEY_SENSOR_FAST_INTERVAL],
        Slow = self.config[CONFIG_KEY_SENSOR_SLOW_INTERVAL],
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

    self.started = true
    self:DoSensorReadout()
end

-------------------------------------------------------------------------------

function PropertyManager:GetProperty(global_id)
    return self.properties_by_id[global_id]
end

function PropertyManager:GetValue(global_id)
    return self.values_by_id[global_id]
end

function PropertyManager:GetLocalProperties()
    return table.sorted_keys(self.local_properties)
end

function PropertyManager:GetAllProperties()
    return table.sorted_keys(self.properties_by_id)
end

-------------------------------------------------------------------------------

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
    opt.class = "base/property/remote-property"
    return self:RegisterProperty(opt)
end

local function CreatePropertyObject(opt)
    if opt.proxy and opt.class == nil then
        opt.class = "base/property/sensor-proxy"
    end

    local base_class = "base/property/local-property"
    opt.class = opt.class or base_class

    local t = type(opt.class)
    if t == "string" then
        return loader_class:CreateObject(opt.class, opt)
    elseif t == "table" then
        return loader_class:CreateSubObject(opt.class, base_class, opt)
    end

    assert(false) -- TODO
end

function PropertyManager:RegisterProperty(opt)
    opt.property_type = opt.property_type or PROPERTY_TYPE_LOCAL
    opt.readout_mode = opt.readout_mode or PROPERTY_MODE_PASSIVE

    local property_type = opt.property_type
    if property_type == PROPERTY_TYPE_REMOTE and opt.remote_name then
        property_type = opt.remote_name
    end

    opt.source_name = property_type
    opt.global_id = string.format("%s.%s", property_type, opt.id)

    print(self, "Registering property", opt.global_id)

    opt.property_manager = self

    local object = CreatePropertyObject(opt)
    local gid = object:GetGlobalId()

    self.properties_by_id[gid] = object

    if object:IsSensor() then
        self.local_sensors[gid] = object
    end

    if object:IsLocal() then
        self.local_properties[gid] = object
    end

    for k,v in pairs(object:GetValues()) do
        self.values_by_id[v:GetGlobalId()] = v
    end

    if self.database then
        self:WriteManagerDatabaseEntry({
            global_id = object:GetGlobalId(),

            name = object:GetName(),
            id = object:GetId(),

            type = "property",
            property = "",
            property_type = object.property_type,
            readout_mode = object.readout_mode,

            history_key = "",
        })
    end

    return object
end

-------------------------------------------------------------------------------

function PropertyManager:GetManagerDatabase()
    local db_id = "property.manager"
    return self.mongo_connection:GetCollection(db_id)
end

function PropertyManager:WriteManagerDatabaseEntry(data)
    if self.database then
        local db_key = { global_id = data.global_id }
        return self.database:InsertOrReplace(db_key, data)
    end
end

function PropertyManager:GetValueDatabase(value)
    local db_id = value:GetDatabaseId()

    if self.database then
        self:WriteManagerDatabaseEntry({
            global_id = value:GetGlobalId(),

            name = value:GetName(),
            id = value:GetId(),
            unit = value:GetUnit(),
            datatype = value:GetDatatype(),

            type = "value",
            property = value.owner_property:GetGlobalId(),
            property_type = "",
            readout_mode = "",

            history_key = db_id,
        })
    end

    return self.mongo_connection:GetCollection(db_id, "timestamp")
end

-------------------------------------------------------------------------------

function PropertyManager:DoSensorReadout()
    for _,v in pairs(self.local_sensors) do
        scheduler.Push(function() v:Readout() end)
    end
end

function PropertyManager:DoSensorReadoutSlow()
    for _,v in pairs(self.local_sensors) do
        scheduler.Push(function() v:ReadoutSlow() end)
        -- v:ReadoutSlow()
    end
end

function PropertyManager:DoSensorReadoutFast()
    for _,v in pairs(self.local_sensors) do
        scheduler.Push(function() v:ReadoutFast() end)
        -- v:ReadoutFast()
    end
end

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
            local val, timestamp = v:GetValue()
            table.insert(r, {
                "value",
                v.global_id,
                p.readout_mode,
                p.property_type,
                val,
                v:GetUnit(),
                timestamp,
                v:GetDatatype(),
            })
        end
    end

    return { header = header, data = r }
end

-------------------------------------------------------------------------------

return PropertyManager
