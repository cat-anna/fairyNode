
local tablex = require "pl.tablex"
local scheduler = require "fairy_node/scheduler"
local loader_class = require "fairy_node/loader-class"
local loader_module = require "fairy_node/loader-module"
-- local stringx = require "pl.stringx"
-- local uuid = require "uuid"

-------------------------------------------------------------------------------

local pairs = pairs
local ipairs = ipairs

-------------------------------------------------------------------------------

-- local PROPERTY_TYPE_LOCAL = "local"
-- local PROPERTY_TYPE_REMOTE = "remote"

-- local PROPERTY_MODE_SENSOR = "sensor"
-- local PROPERTY_MODE_PASSIVE = "passive"

-------------------------------------------------------------------------------

local PropertyManager = {}
PropertyManager.__type = "module"
PropertyManager.__tag = "PropertyManager"
PropertyManager.__deps = { }
PropertyManager.__config = { }

-------------------------------------------------------------------------------

function PropertyManager:Init(prop_proto)
    PropertyManager.super.Init(self, prop_proto)
    self.properties_by_id = table.weak_values()
end

-------------------------------------------------------------------------------

function PropertyManager:GetProperty(global_id)
    return self.properties_by_id[global_id]
end

function PropertyManager:PropertyKeys()
    return table.sorted_keys(self.properties_by_id)
end

-------------------------------------------------------------------------------

function PropertyManager:CreateProperty(prop_proto)
    assert(prop_proto.id)
    assert(prop_proto.class)

    prop_proto.global_id = string.format("%s.%s", prop_proto.owner_component:GetGlobalId(), prop_proto.id)
    local prop = loader_class:CreateObject(prop_proto.class, prop_proto)

    local gid = prop:GetGlobalId()
    assert(self.properties_by_id[gid] == nil)
    self.properties_by_id[gid] = prop

    return prop
end

function PropertyManager:DeleteProperty(prop)
    print(self, "TODO")
    self.properties_by_id[prop:GetGlobalId()] = nil
end

-------------------------------------------------------------------------------

-- function PropertyManager:AttachListener(target)
--     self.listeners[target.uuid] = target
-- end

-- function PropertyManager:DetachListener(target)
--     self.listeners[target.uuid] = nil
-- end

-------------------------------------------------------------------------------

-- function PropertyManager:GetLocalSensor(id)
--     return self.local_sensors[id]
-- end

-- function PropertyManager:GetValue(global_id)
--     return self.values_by_id[global_id]
-- end

-- function PropertyManager:GetLocalProperties()
--     return table.sorted_keys(self.local_properties)
-- end

-- function PropertyManager:GetAllProperties()
--     return table.sorted_keys(self.properties_by_id)
-- end

-------------------------------------------------------------------------------

-- function PropertyManager:RegisterSensor(prop_proto)
--     prop_proto.readout_mode = PROPERTY_MODE_SENSOR
--     return self:RegisterLocalProperty(prop_proto)
-- end

-- function PropertyManager:RegisterLocalProperty(prop_proto)
--     prop_proto.property_type = PROPERTY_TYPE_LOCAL
--     return self:RegisterProperty(prop_proto)
-- end

-- function PropertyManager:RegisterRemoteProperty(prop_proto)
--     prop_proto.property_type = PROPERTY_TYPE_REMOTE
--     prop_proto.class = "modules/manager-device/remote-property"
--     return self:RegisterProperty(prop_proto)
-- end

-- local function CreatePropertyObject(prop_proto)
--     if prop_proto.proxy and prop_proto.class == nil then
--         prop_proto.class = "modules/manager-device/sensor-proxy"
--     end

--     local base_class = "modules/manager-device/local-property"
--     prop_proto.class = prop_proto.class or base_class

--     local t = type(prop_proto.class)
--     if t == "string" then
--         return loader_class:CreateObject(prop_proto.class, prop_proto)
--     elseif t == "table" then
--         return loader_class:CreateSubObject(prop_proto.class, base_class, prop_proto)
--     end

--     assert(false) -- TODO
-- end

-- function PropertyManager:RegisterProperty(prop_proto)
--     prop_proto.property_type = prop_proto.property_type or PROPERTY_TYPE_LOCAL
--     prop_proto.readout_mode = prop_proto.readout_mode or PROPERTY_MODE_PASSIVE

--     local property_type = prop_proto.property_type
--     if property_type == PROPERTY_TYPE_REMOTE and prop_proto.remote_name then
--         property_type = prop_proto.remote_name
--     end

--     -- prop_proto.source_name = property_type
--     prop_proto.global_id = string.format("%s.%s", property_type, prop_proto.id)

--     print(self, "Registering property", prop_proto.global_id)

--     prop_proto.property_manager = self

--     local object = CreatePropertyObject(prop_proto)
--     local gid = object:GetGlobalId()

--     self.properties_by_id[gid] = object

--     if object:IsSensor() then
--         self.local_sensors[prop_proto.id] = object
--     end

--     if object:IsLocal() then
--         self.local_properties[gid] = object
--     end

--     for k,v in pairs(object:GetValues()) do
--         self.values_by_id[v:GetGlobalId()] = v
--     end

--     if self.database then
--         self:WriteManagerDatabaseEntry({
--             global_id = object:GetGlobalId(),

--             name = object:GetName(),
--             id = object:GetId(),

--             type = "property",
--             property = "",
--             property_type = object.property_type,
--             readout_mode = object.readout_mode,

--             history_key = "",
--         })
--     end

--     for _,v in pairs(self.listeners) do
--         v:PropertyCreated(object)
--     end

--     return object
-- end

-- function PropertyManager:ReleaseProperty(object)
--     warning(self, "not implemented")

--     local global_id = object:GetGlobalId()

--     self.values_by_id[global_id] = nil
--     self.properties_by_id[global_id] = nil

--     self.local_sensors[global_id] = nil
--     self.local_properties[global_id] = nil

--     for _,v in pairs(self.listeners) do
--         v:PropertyReleased(object)
--     end
-- end

-- function PropertyManager:ReleaseObject(object)
--     warning(self, "not implemented")
--     self:ReleaseProperty(object)
-- end

-------------------------------------------------------------------------------

-- function PropertyManager:GetValueDatabase(value)
--     local persistent = value:IsPersistent()
--     local db_id = value:GetDatabaseId()

--     if self.database then
--         self:WriteManagerDatabaseEntry({
--             global_id = value:GetGlobalId(),

--             name = value:GetName(),
--             id = value:GetId(),
--             unit = value:GetUnit(),
--             datatype = value:GetDatatype(),

--             type = "value",
--             property = value.owner_property:GetGlobalId(),
--             property_type = "",
--             readout_mode = "",
--             persistent = persistent,

--             history_key = db_id,
--         })
--     end

--     if persistent and self.mongo_connection then
--         return self.mongo_connection:GetCollection(db_id, "timestamp")
--     end
-- end

-------------------------------------------------------------------------------

function PropertyManager:GetDebugTable()
    local header = {
        "id",
        "global_id",
        "type",
        "started",

        "value",
        "unit",
        "timestamp",
        "datatype",

        -- "persistent",
    }

    local r = { }
    local function check(v)
        if v == nil then
            return ""
        end
        return tostring(v)
    end

    for _,id in ipairs(self:PropertyKeys()) do
        local p = self.properties_by_id[id]
        local v,t = p:GetValue()
        table.insert(r, {
            p:GetId(),
            p:GetGlobalId(),
            check(p:GetType()),
            check(p:IsStarted()),

            check(v),
            check(p:GetUnit()),
            check(t),
            check(p:GetDatatype()),
        })
    end

    return {
        title = "Property manager",
        header = header,
        data = r
    }
end

-------------------------------------------------------------------------------

return PropertyManager
