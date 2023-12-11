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
end

function Module:BeforeReload()
end

function Module:AfterReload()
end

-------------------------------------------------------------------------------------

function Module:GetErrorManager()
    if not self.error_manager then
        self.error_manager = require "fairy_node/loader-module"
    end
    return self.error_manager
end

function Module:SetError(id, message)
    return self:GetErrorManager():SetModuleError(self, id, message)
end

function Module:ClearError(id)
    return self:GetErrorManager():ClearModuleError(self, id)
end

function Module:ClearAllErrors()
    return self:GetErrorManager():ClearAllModuleErrors(self)
end

-------------------------------------------------------------------------------------

return Module
