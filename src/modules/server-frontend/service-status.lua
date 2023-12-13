
local http = require "fairy_node/http-code"
local loader_class = require "fairy_node/loader-class"
local loader_module = require "fairy_node/loader-module"

-------------------------------------------------------------------------------------

local ServiceStatus = {}
ServiceStatus.__tag = "ServiceStatus"
ServiceStatus.__type = "module"
ServiceStatus.__deps = { }

-------------------------------------------------------------------------------------

function ServiceStatus:GetStatus()
    return http.OK, {
        table = table.flatten_map(self.stat_modules),
        graph = table.flatten_map(self.graph_modules),
    }
end

-------------------------------------------------------------------------------------

function ServiceStatus:GetTablesList()
    return http.OK, table.flatten_map(self.stat_modules)
end

function ServiceStatus:GetModuleTable(request, module_name)
    local mod_name = self.stat_modules[module_name]
    if mod_name then
        local module = loader_module:GetModule(mod_name)
        if module and module.GetDebugTable then
            local r = module:GetDebugTable()
            if module.Tag then
                r.tag = module:Tag()
            end
            return http.OK, r
        end
    end
    return http.BadRequest
end

-------------------------------------------------------------------------------------

function ServiceStatus:GetGraphsList()
    return http.OK, table.flatten_map(self.graph_modules)
end

function ServiceStatus:GetModuleGraphText(request, module_name)
    local mod_name = self.graph_modules[module_name]

    if mod_name then
        local module = loader_module:GetModule(mod_name)
        if module and module.GetDebugGraph then
            local graphBuilder = require "fairy_node/tools/graph-builder"
            local graph = graphBuilder:New()

            module:GetDebugGraph(graph)
            if type(request.theme) == "string" then
                graph:SetTheme(request.theme)
            end
            return http.OK, graph:ToPlantUMLText()
        end
    end
    return http.BadRequest
end

function ServiceStatus:GetModuleGraphUrl(request, module_name)
    local code,text = self:GetModuleGraphText(request, module_name)
    if code ~= http.OK then
        return code
    end

    local format = self.plantuml.Format.svg
    if request.colors and (request.colors == "dark") then
        format = self.plantuml.Format.dark_svg
    end

    local url = self.plantuml:EncodeUrl(text, format)
    if url then
        return http.OK, url
    end
    return http.BadRequest
end

-------------------------------------------------------------------------------------

function ServiceStatus:ReloadDebugInfo()
    local stat_modules = { }
    local graph_modules = { }

    local function to_network_id(n)
        return n:gsub("[%.-/]", "_")
    end

    loader_module:EnumerateModules(function (name, instance)
        instance = instance or {}
        local net_name = to_network_id(name)
        if instance.GetDebugTable then
            stat_modules[net_name] = name
        end
        if instance.GetDebugGraph then
            graph_modules[net_name] = name
        end
    end)

    self.stat_modules = stat_modules
    self.graph_modules = graph_modules
end

-------------------------------------------------------------------------------------

function ServiceStatus:BeforeReload()
end

function ServiceStatus:AfterReload()
end

function ServiceStatus:Init()
end

function ServiceStatus:StartModule()
    self:ReloadDebugInfo()
end

-------------------------------------------------------------------------------------

return ServiceStatus
