-- local uuid = require "uuid"
local mongo = require "mongo"
local pretty = require "pl.pretty"

-------------------------------------------------------------------------------------

local MongoCollection = { }
MongoCollection.__type = "class"
MongoCollection.__name = "MongoCollection"
MongoCollection.__deps = { }

-------------------------------------------------------------------------------------

function MongoCollection:Tag()
    return string.format("MongoCollection(%s)", self.name)
end

function MongoCollection:Init(config)
    self.collection_handle = config.collection_handle
    self.name = config.name
end

function MongoCollection:PostInit()
end

-------------------------------------------------------------------------------------

-- function MongoCollection:Update(collection, data)
--     local id = self:CollectionId(collection)
--     self.server_storage:WriteObjectToStorage(id, data)
-- end

function MongoCollection:Insert(data)
    local success, err_msg = self.collection_handle:insertOne(data)
    if not success then
        print(self, "Insert: ", success, err_msg)
    end
end

function MongoCollection:InsertOrReplace(condition, data)
    local query = mongo.BSON(condition)

    local update_success, update_err_msg

-- assert(collection:update({_id = 123}, {a = 'abc'}, {upsert = true})) -- inSERT
-- assert(collection:update({_id = 123}, {a = 'def'}, {upsert = true})) -- UPdate

    local found, found_err_msg = self.collection_handle:findOne(query)
    if found then
        update_success, update_err_msg = self.collection_handle:replaceOne(query, data)
    else
        print(self, "InsertOrReplace: found:", found_err_msg)
        update_success, update_err_msg = self.collection_handle:insertOne(data)
    end

    if not update_success then
        print(self, "InsertOrReplace: update:", update_err_msg)
    end
end

function MongoCollection:Replace(condition, data)
    local query = mongo.BSON(condition)
    local success, err_msg = self.collection_handle:replaceOne(query, data)
    if success then
        return success
    end
    print(self, "Replace: ", success, err_msg)
end


function MongoCollection:FetchAll(query)
    local cursor = self.collection_handle:find(query or {})

    local r = { }

    for item in cursor:iterator() do
        table.insert(r, item)
    end

    -- print(self, "FetchAll:", pretty.write(r, ""))

    return r
end

function MongoCollection:FetchRange(key, from, to)
    local string_query
    if to == nil then
        string_query = string.format([[{ "%s": { "$gt": %f } }]], key, from)
    else
        string_query = string.format([[{ "%s": { "$gt": %f, "$lt": %f } }]], key, from, to)
    end
    local query = mongo.BSON(string_query)
    return self:FetchAll(query)
end

-------------------------------------------------------------------------------------

return MongoCollection
