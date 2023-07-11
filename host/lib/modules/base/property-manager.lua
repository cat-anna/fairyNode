
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

-------------------------------------------------------------------------------

local PropertyManager = {}
PropertyManager.__stats = true
PropertyManager.__deps = {
    mongo_connection = "mongo/mongo-connection",
}
PropertyManager.__config = {
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
    self.listeners = table.weak_values()

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
end

-------------------------------------------------------------------------------

function PropertyManager:AttachListener(target)
    self.listeners[target.uuid] = target
end

function PropertyManager:DetachListener(target)
    self.listeners[target.uuid] = nil
end

-------------------------------------------------------------------------------

function PropertyManager:GetProperty(global_id)
    return self.properties_by_id[global_id]
end

function PropertyManager:GetLocalSensor(id)
    return self.local_sensors[id]
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
        self.local_sensors[opt.id] = object
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

    for _,v in pairs(self.listeners) do
        v:PropertyCreated(object)
    end

    return object
end

function PropertyManager:ReleaseProperty(object)
    warning(self, "not implemented")

    local global_id = object:GetGlobalId()

    self.values_by_id[global_id] = nil
    self.properties_by_id[global_id] = nil

    self.local_sensors[global_id] = nil
    self.local_properties[global_id] = nil

    for _,v in pairs(self.listeners) do
        v:PropertyReleased(object)
    end
end

function PropertyManager:ReleaseObject(object)
    warning(self, "not implemented")
    self:ReleaseProperty(object)
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
    local persistent = value:IsPersistent()
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
            persistent = persistent,

            history_key = db_id,
        })
    end

    if persistent then
        return self.mongo_connection:GetCollection(db_id, "timestamp")
    end
end

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
        "persistent",
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
                tostring(val):sub(1,64),
                v:GetUnit(),
                timestamp,
                v:GetDatatype(),
                v:IsPersistent(),
            })
        end
    end

    return { header = header, data = r }
end

-------------------------------------------------------------------------------

return PropertyManager
