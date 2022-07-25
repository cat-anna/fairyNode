local http = require "lib/http-code"

-------------------------------------------------------------------------------------

local ServiceStatus = {}
ServiceStatus.__index = ServiceStatus
ServiceStatus.__deps = {
    plantuml = "util/plantuml",
    loader_module = "base/loader-module",
    loader_class = "base/loader-class",
    -- event_bus = "base/event-bus"
    -- loader_package = "base/loader-package",
}

-------------------------------------------------------------------------------------

function ServiceStatus:Tag()
    return "ServiceStatus"
end

-------------------------------------------------------------------------------------

function ServiceStatus:GenerateModuleDiagram()
    local lines = {
        "@startuml",--
        "hide empty description",--
        "skinparam BackgroundColor transparent", --
        "skinparam ranksep 20", --
        "left to right direction", --
        "scale 0.7", --
        "",
    }
    local dependencies = { }

    self.loader_module:EnumerateModules(function (name, instance)
        local id = self.plantuml:NameToId(name)

        local state_line = string.format([[state %s as "%s"]], id, name)
        table.insert(lines, state_line)

        for k,v in pairs(instance.__deps or {}) do
            local l = {id, "-->", self.plantuml:NameToId(v)}
            table.insert(dependencies, table.concat(l, " "))
        end
    end)

    table.insert(lines, "")
    table.insert(lines, table.concat(dependencies, "\n"))

    table.insert(lines, "")
    table.insert(lines, "@enduml")

    return lines
end

function ServiceStatus:GenerateClassesDiagram()
    local lines = {
        "@startuml",--
        "hide empty description", --
        "hide empty members", --
        "skinparam BackgroundColor transparent", --
        "skinparam ranksep 20", --
        "left to right direction", --
        "scale 0.7", --
        "",
    }

    local function Count(v)
        local r = 0
        for _,_ in pairs(v) do r = r+1 end
        return r
    end

    self.loader_class:EnumerateClasses(function (name, class_meta)
        local id = self.plantuml:NameToId(name)

        local opts = {
            string.format("Name: %s", class_meta.metatable.__class_name or "?"),
        }

        if not class_meta.interface then
            table.insert(opts, string.format("Instances: %d", Count(class_meta.instances)))
        else
            table.insert(opts, "Interface")
        end

        local mode = class_meta.interface and "interface" or " class"
        local state_line = string.format("%s %s as \"%s\" {\n%s\n}", mode, id, name, table.concat(opts, "\n"))
        table.insert(lines, state_line)
    end)

    table.insert(lines, "")

    self.loader_class:EnumerateClasses(function (name, class_meta)
        local id = self.plantuml:NameToId(name)
        for k,v in pairs(class_meta.base_for) do
            local l = {id, "-->", self.plantuml:NameToId(k)}
            table.insert(lines, table.concat(l, " "))
        end
    end)

    table.insert(lines, "")
    table.insert(lines, "@enduml")

    return lines
end

-------------------------------------------------------------------------------------

function ServiceStatus:GetStatus()
    return http.OK, {}  --, { url = self:EncodedStateDiagram() }
end

-------------------------------------------------------------------------------------

function ServiceStatus:GetModuleGraphUrl()
    return http.OK, { url = self.plantuml:EncodeUrl(self:GenerateModuleDiagram()) }
end

function ServiceStatus:GetModuleGraphText()
    return http.OK, table.concat(self:GenerateModuleDiagram(), "\n")
end

-------------------------------------------------------------------------------------

function ServiceStatus:GetClassesGraphUrl()
    return http.OK, { url = self.plantuml:EncodeUrl(self:GenerateClassesDiagram()) }
end

function ServiceStatus:GetClassesGraphText()
    return http.OK,table.concat(self:GenerateClassesDiagram(), "\n")
end

-------------------------------------------------------------------------------------

function ServiceStatus:GetStatModules()
    return http.OK, { modules = self.stat_modules }
end

function ServiceStatus:GetModuleStats(request, module_name)
    local result
    local mod_name = self.stat_modules[module_name]
    if mod_name then
        local module = self.loader_module:GetModule(mod_name)
        if module and module.GetStatistics then
            return http.OK, { table = module:GetStatistics() }
        end
    end

    return http.BadRequest
end

-------------------------------------------------------------------------------------

function ServiceStatus:BeforeReload()
end

function ServiceStatus:AfterReload()
    self:OnAppStart()
end

function ServiceStatus:Init()
end

-------------------------------------------------------------------------------------

function ServiceStatus:OnAppStart()
    local stat_modules = { }

    local function to_network_id(n)
        local r = n:gsub("[%.-/]", "_")
        return r
    end

    self.loader_module:EnumerateModules(function (name, instance)
        if instance.__stats then
            stat_modules[to_network_id(name)] = name
        end
    end)

    self.stat_modules = stat_modules
end

-------------------------------------------------------------------------------------

ServiceStatus.EventTable = {
    ["app.start"] = ServiceStatus.OnAppStart
}

return ServiceStatus
