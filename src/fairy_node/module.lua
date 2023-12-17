local scheduler = require "fairy_node/scheduler"

-------------------------------------------------------------------------------------

local Module = { }
Module.__name = "Module"
Module.__type = "interface"

-------------------------------------------------------------------------------------

function Module:Init(config)
    Module.super.Init(self, config)
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

-------------------------------------------------------------------------------------

return Module
