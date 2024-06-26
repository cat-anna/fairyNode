-- local uuid = require "uuid"
local mongo = require "mongo"
local loader_class = require "fairy_node/loader-class"

-------------------------------------------------------------------------------

local MongoClient = { }
MongoClient.__tag = "MongoClient"
MongoClient.__type = "module"
MongoClient.__deps = { }
MongoClient.__config = { }

-------------------------------------------------------------------------------------

function MongoClient:Init(opt)
    MongoClient.super.Init(self, opt)
    self.opened_collections = table.weak_values()
    self:Connect()
end

function MongoClient:PostInit()
    MongoClient.super.PostInit(self)
end

function MongoClient:StartModule()
    MongoClient.super.StartModule(self)
end

-------------------------------------------------------------------------------------

function MongoClient:Connect()
    if self.connected then
        return
    end

    local uri = self.config.connection
    if self.verbose then
        printf(self, "Connecting to '%s'", uri)
    end

    self.database_name = self.config.database
    assert(self.database_name)

    self.mongo_client = mongo.Client(uri)
    self.mongo_database = self.mongo_client:getDatabase(self.database_name)
    self.connected = true

    self.collection = {
        open_log = self:CreateCollection(self:GetFullMongoCollectionName("open_log"), "collection")
    }

    self:UpdateOpenTimestamp(self.collection.open_log:GetName())
end

-------------------------------------------------------------------------------------

function MongoClient:UpdateOpenTimestamp(name)
    if self.collection then
        self.collection.open_log:InsertOrUpdate({ collection = name }, {
            timestamp_open = os.timestamp(),
        })
    end
end

-------------------------------------------------------------------------------------

function MongoClient:MakeHandle(name, collection, flags)
    local obj = loader_class:CreateObject("mongo-client/mongo-collection", {
        database = self.mongo_database,
        collection_handle = collection,
        name = name,
        flags = flags or { },
    })

    self.opened_collections[name] = obj
    self:UpdateOpenTimestamp(name)

    return obj
end

-------------------------------------------------------------------------------------

function MongoClient:RenameCollection(old_name, new_name, drop_target)
    local collection = self.mongo_database:getCollection(old_name)
    collection:rename(self.database_name, new_name, drop_target)
end

function MongoClient:HasCollection(name)
    return  self.mongo_database:hasCollection(name)
end

function MongoClient:CreateCollection(name, index_name, flags)
    local new_collection = not self.mongo_database:hasCollection(name)
    if not new_collection then
        return self:OpenCollection(name, false, nil, flags)
    end

    if self.verbose then
        printf(self, "Creating collection '%s'", name)
    end

    local collection = self.mongo_database:getCollection(name)
    if index_name then
        local query = string.format([[
{
    "createIndexes": "%s",
    "indexes": [
        {
            "key": {
                "%s": 1
            },
            "name": "%s",
            "unique": true
        }
    ]
}
]], name, index_name, index_name)
            local queryBSON = mongo.BSON(query)
            print(self, "RESULT", self.mongo_client:command(self.database_name, queryBSON))
    end

    return self:MakeHandle(name, collection, flags)
end

function MongoClient:OpenCollection(name, can_create, index_name, flags)
    if self.opened_collections[name] then
        return self.opened_collections[name]
    end

    if not self.mongo_database:hasCollection(name) then
        if can_create then
            return self:CreateCollection(name, index_name)
        end
        return
    end

    if self.verbose then
        printf(self, "Opening collection '%s'", name)
    end

    local collection = self.mongo_database:getCollection(name)
    return self:MakeHandle(name, collection, flags)
end

-------------------------------------------------------------------------------------

return MongoClient
