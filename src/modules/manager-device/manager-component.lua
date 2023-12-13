
local loader_class = require "fairy_node/loader-class"

-------------------------------------------------------------------------------

local pairs = pairs
local ipairs = ipairs

-------------------------------------------------------------------------------

local ComponentManager = {}
ComponentManager.__tag = "ComponentManager"
ComponentManager.__type = "module"
ComponentManager.__deps = { }
ComponentManager.__config = { }

-------------------------------------------------------------------------------

function ComponentManager:Init(opt)
    ComponentManager.super.Init(self, opt)

    self.components_by_id = table.weak_values()
end

function ComponentManager:PostInit()
    -- self.mongo_connection = loader_module:GetModule("mongo/mongo-connection")
    self.database = self:GetManagerDatabase()

    -- loader_module:EnumerateModules(
    --     function(name, module)
    --         if module.InitProperties then
    --             module:InitProperties(self)
    --         end
    --     end)
end

function ComponentManager:StartModule()
end

-------------------------------------------------------------------------------

function ComponentManager:GetComponent(global_id)
    return self.components_by_id[global_id]
end

function ComponentManager:ComponentKeys()
    return table.sorted_keys(self.components_by_id)
end

-------------------------------------------------------------------------------

function ComponentManager:CreateComponent(comp_proto)
    assert(comp_proto.id)
    assert(comp_proto.class)

    comp_proto.global_id = string.format("%s.%s", comp_proto.owner_device:GetGlobalId(), comp_proto.id)

    local component = loader_class:CreateObject(comp_proto.class, comp_proto)

    local gid = component:GetGlobalId()
    assert(self.components_by_id[gid] == nil)
    self.components_by_id[gid] = component

    return component
end

function ComponentManager:DeleteCompnent(component)
    print(self, "TODO")
    self.components_by_id[component:GetGlobalId()] = nil
end

-------------------------------------------------------------------------------

function ComponentManager:WriteManagerDatabaseEntry(data)
    -- if self.database then
    --     local db_key = { global_id = data.global_id }
    --     return self.database:InsertOrReplace(db_key, data)
    -- end
end

function ComponentManager:GetManagerDatabase()
    if self.mongo_connection then
        local db_id = "property.manager"
        return self.mongo_connection:GetCollection(db_id)
    end
end

-------------------------------------------------------------------------------

function ComponentManager:GetDebugTable()
    local header = {
        "global_id",
        "type",
        "started",
        "properties",
    }

    local r = { }
    local function check(v)
        if v == nil then
            return ""
        end
        return tostring(v)
    end

    for _,id in ipairs(self:ComponentKeys()) do
    --     -- print(self, id)
        local p = self.components_by_id[id]
        table.insert(r, {
            p:GetGlobalId(),
            p:GetType(),
            check(p:IsStarted()),
            table.concat(p:PropertyKeys(), ",")
        })
    end

    return {
        title = "Component manager",
        header = header,
        data = r
    }
end

-------------------------------------------------------------------------------

return ComponentManager
