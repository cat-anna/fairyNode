
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

function ServiceStatus:GetModuleGraph(module_name, theme)
    local mod_name = self.graph_modules[module_name]
    if mod_name then
        local module = loader_module:GetModule(mod_name)
        if module and module.GetDebugGraph then
            local graph_builder = require("fairy_node/tools/graph-builder"):New()

            module:GetDebugGraph(graph_builder)
            if type(theme) == "string" then
                graph_builder:SetTheme(theme)
            end
            return graph_builder
        end
    end
end

function ServiceStatus:GetModuleGraphText(request, module_name)
    local graph_builder = self:GetModuleGraph(module_name, request.theme)
    if not graph_builder then
        return http.BadRequest
    end
    return http.OK, graph_builder:ToPlantUMLText()
end

function ServiceStatus:GetModuleGraphUrl(request, module_name)
    local graph_builder = self:GetModuleGraph(module_name, request.theme)
    if not graph_builder then
        return http.BadRequest
    end

    local format = graph_builder.Format.svg
    if request.colors and (request.colors == "dark") then
        format = graph_builder.Format.dark_svg
    end

    local url = graph_builder:ToPlantUMLUrl(format)
    if url then
        return http.OK, { url = url }
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

function ServiceStatus:StartModule()
    ServiceStatus.super.StartModule(self)
    self:ReloadDebugInfo()
end

-------------------------------------------------------------------------------------

return ServiceStatus
