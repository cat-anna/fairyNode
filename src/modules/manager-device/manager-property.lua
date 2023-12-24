
local loader_class = require "fairy_node/loader-class"
local loader_module = require "fairy_node/loader-module"

-------------------------------------------------------------------------------

local pairs = pairs
local ipairs = ipairs

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

function PropertyManager:PostInit()
    PropertyManager.super.PostInit(self)

    self.mongo_client = loader_module:GetModule("mongo-client")
    -- self.database = self:GetManagerDatabase()
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
    assert(prop_proto.class)

    prop_proto.property_manager = self

    local prop = loader_class:CreateObject(prop_proto.class, prop_proto)
    prop.global_id = string.format("%s.%s", prop_proto.owner_component:GetGlobalId(), prop:GetId())

    local gid = prop:GetGlobalId()
    assert(self.properties_by_id[gid] == nil)
    self.properties_by_id[gid] = prop

    return prop
end

function PropertyManager:DeleteProperty(prop)
    print(self, "TODO")
    self.properties_by_id[prop:GetGlobalId()] = nil
end

function PropertyManager:ArePropertiesReady()
    local all_started = true
    local all_ready = true

    for k,v in pairs(self.properties_by_id) do
        all_started = all_started and not v:IsStarted()
        all_ready = all_ready and not v:IsReady()
    end

    return all_started, all_ready
end

-------------------------------------------------------------------------------

function PropertyManager:OpenPropertyDatabase(property)
    local db_id = property:GetDatabaseId()
    if self.verbose then
        print(self, "Opening collection", db_id)
    end

    local db = self.mongo_client:OpenCollection(db_id)
    if db then
        return db
    end

    print(self, "Collection", db_id, "does not exists, trying to update")
    for _,key in ipairs(property:GetLegacyDatabaseId()) do
        if self.mongo_client:HasCollection(key) then
            self.mongo_client:RenameCollection(key, db_id, true)
            db = self.mongo_client:OpenCollection(db_id)
            if db then
                print(self, "Successfuly renamed collection", key, "to", db_id)
                return db
            end
        end
    end

    print(self, "Creating collection", db_id)
    return self.mongo_client:CreateCollection(db_id, "timestamp")
end

-------------------------------------------------------------------------------

-- function PropertyManager:GetValueDatabase(value)
--     local persistent = value:IsPersistent()

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
-- end

-------------------------------------------------------------------------------

function PropertyManager:GetDebugTable()
    local header = {
        "global_id",
        "name",
        "type",
        "started",
        "ready",
        "persistence",
        "settable",

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
            p:GetGlobalId(),
            p:GetName(),
            check(p:GetType()),
            check(p:IsStarted()),
            check(p:IsReady()),
            check(p:WantsPersistence()),
            check(p:IsSettable()),

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
