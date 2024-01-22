-- local scheduler = require "fairy_node/scheduler"
local loader_module = require "fairy_node/loader-module"
local loader_class = require "fairy_node/loader-class"

-------------------------------------------------------------------------------------

local Module = { }
Module.__name = "Module"
Module.__type = "interface"

-------------------------------------------------------------------------------------

function Module:Init(config)
    Module.super.Init(self, config)
    self.module_prefix = config.module_prefix
end

function Module:PostInit()
end

function Module:StartModule()
    if self.verbose then
        print(self, "Starting")
    end
    self.started = true
end

function Module:BeforeReload()
end

function Module:AfterReload()
end

function Module:Shutdown()
    self.mongo_collections = nil
    Module.super.Shutdown(self)
end

function Module:StartSystemTick()
    loader_module:RegisterSystemTick(self)
end

function Module:OnSystemTick()
end

-------------------------------------------------------------------------------------

function Module:EmitEvent(event, arg)
    assert(self.module_prefix)
    local bus = self:GetEventBus()
    bus:PushEvent({
        event = string.format("module.%s.%s", self.module_prefix, event),
        sender = self,
        argument = arg or { }
    })
end

-------------------------------------------------------------------------------------

function Module:CreateSubObject(sub_class, opt)
    opt = opt or { }
    opt.module_prefix = self.module_prefix
    opt.module_owner = self
    return loader_class:CreateObject(
        string.format("%s/%s", self.module_prefix, sub_class),
        opt
    )
end

-------------------------------------------------------------------------------------

function Module:GetMongoClient()
    return loader_module:GetModule("mongo-client")
end

function Module:GetFullMongoCollectionName(name)
    assert(self.module_prefix)
    return string.format("module.%s.%s", self.module_prefix, name)
end

function Module:SetupDatabase(opt)
    assert(opt.name)
    assert(opt.index)

    if not self.mongo_collections then
        self.mongo_collections = { }
    end

    local id = self:GetFullMongoCollectionName(opt.name)
    local entry = {
        handle = self:GetMongoClient():CreateCollection(id, opt.index),
        collection_id = id
    }
    self.mongo_collections[opt.name] = entry

    if (not self.mongo_collections["_"]) or opt.default then
        self.mongo_collections["_"] = entry
    end
end

function Module:GetDatabase(name)
    name = name or "_"
    assert(self.mongo_collections)
    return self.mongo_collections[name].handle
end

-------------------------------------------------------------------------------------

return Module
