-- local scheduler = require "fairy_node/scheduler"
-- local loader_module = require "fairy_node/loader-module"

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

return Module
