local scheduler = require "fairy_node/scheduler"

-------------------------------------------------------------------------------------

local Module = { }
Module.__name = "Module"
Module.__type = "interface"

-------------------------------------------------------------------------------------

function Module:Init(config)
    Module.super.Init(self, config)
    self.config = config.config
end

function Module:PostInit()
end

function Module:StartModule()
end

function Module:BeforeReload()
end

function Module:AfterReload()
end

-------------------------------------------------------------------------------------

return Module
