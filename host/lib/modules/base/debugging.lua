
local copas = require "copas"
local scheduler = require "lib/scheduler"
local logger = require "lib/logger"

-------------------------------------------------------------------------------------

local Debugging = {}
Debugging.__index = Debugging
Debugging.__deps = {
    loader_module = "base/loader-module"
}
Debugging.__config = { }
Debugging.__name = "Debugging"

-------------------------------------------------------------------------------------

function Debugging:BeforeReload()
end

function Debugging:AfterReload()
end

function Debugging:Init()
end

function Debugging:StartModule()
    if self.config.debug then
        self.stats_task = scheduler:CreateTask(self, "stats", 60, self.CollectDebugStats)
    end
end

function Debugging:StopModule()
    if self.stats_task then
        self.stats_task:Stop()
        self.stats_task = nil
    end
end

-------------------------------------------------------------------------------------

function Debugging:CollectDebugStats()
    local l = logger:DebugLogger()

    self.loader_module:EnumerateModules(
        function(name, module)
            if module.GetStatistics then
                local stats = module:GetStatistics()
                l:WriteObject(ExtractObjectTag(module), stats)
            end
        end)
end

-------------------------------------------------------------------------------------

return Debugging
