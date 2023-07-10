-- local uuid = require "uuid"
local mongo = require "mongo"
local loader_class = require "lib/loader-class"

-------------------------------------------------------------------------------

local CONFIG_KEY_MONGO_DATABASE =   "module.mongodb.database"
local CONFIG_KEY_MONGO_CONNECTION =   "module.mongodb.connection"

-------------------------------------------------------------------------------------

local MongoConnection = { }
MongoConnection.__index = MongoConnection
MongoConnection.__name = "MongoConnection"
MongoConnection.__deps = {
    -- server_storage = "base/server-storage",
}
MongoConnection.__config = {
    [CONFIG_KEY_MONGO_CONNECTION] =   { type = "string", required = true },
    [CONFIG_KEY_MONGO_DATABASE] =   { type = "string", required = true },
}

-------------------------------------------------------------------------------------

function MongoConnection:Tag()
    return "MongoConnection"
end

function MongoConnection:Init()
    local uri = self.config[CONFIG_KEY_MONGO_CONNECTION]
    printf(self, "Connecting to '%s'", uri)

    self.database_name = self.config[CONFIG_KEY_MONGO_DATABASE]
    if not self.database_name then
    end
    assert(self.database_name)

    self.mongo_client = mongo.Client(uri)
    self.mongo_database = self.mongo_client:getDatabase(self.database_name)

    self.opened_collections = { }
end

function MongoConnection:BeforeReload()
end

function MongoConnection:AfterReload()
end

function MongoConnection:PostInit()
end

function MongoConnection:StartModule()
end

-------------------------------------------------------------------------------------

function MongoConnection:GetCollection(name, index_name)
    if self.opened_collections[name] then
        return self.opened_collections[name]
    end

    local new_collection = not self.mongo_database:hasCollection(name)
    local collection = self.mongo_database:getCollection(name)

    if new_collection and index_name then
        print(self, "COMMAND")
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

    local obj = loader_class:CreateObject("mongo/mongo-collection", {
        database = self.mongo_database,
        collection_handle = collection,
        name = name,
    })

    self.opened_collections[name] = obj

    printf(self, "Opened collection '%s'", name)

    return obj
end

-------------------------------------------------------------------------------------

return MongoConnection
