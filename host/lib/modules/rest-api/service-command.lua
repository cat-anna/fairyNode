local http = require "lib/http-code"
local copas = require "copas"
-- local modules = require("lib/loader-module")

-------------------------------------------------------------------------------------

local ServiceCommand = {}
ServiceCommand.__index = ServiceCommand
ServiceCommand.__deps = {
    event_bus = "base/event-bus",
    -- mqtt = "mqtt-provider"
}

-------------------------------------------------------------------------------------

function ServiceCommand:LogTag()
    return "ServiceCommand"
end

function ServiceCommand:ListCommands()
    local r = { }
    for _,v in pairs(self.commands) do
        local cmd = {}
        table.insert(r, cmd)

        cmd.name = v.name
        cmd.args = v.args
    end
    return http.OK, r
end

function ServiceCommand:ExecuteCommand(request, command)
    local cmd = self.commands[command]
    if not cmd then
        error("ServiceCommand: Command " .. tostring(command) .. " is not registered")
        return http.NotFound, {}
    end

    local code = http.OK
    local r = nil
    local success, response = cmd.handler(self:ParseCommands(request, cmd))
    if not success then
        if type(response) == "number" then
            code = response
        else
            code = http.BadRequest
        end
    else
        r = response or {}
    end

    return code, r
end

function ServiceCommand:ParseCommands(request, cmd)

end

function ServiceCommand:RegisterCommand(module_id, command_name, args_desc, handler)
    if self.commands[command_name] then
        error("ServiceCommand: Command " .. command_name .. " is already registered")
        return
    end

    self.commands[command_name] = {
        name = command_name,
        module_id = module_id,
        args = args_desc,
        handler = handler,
    }
    print("ServiceCommand: Registerd command " .. command_name)
end

function ServiceCommand:UnregisterCommands(module_id)
    self.commands = table.filter(self.commands, function(_, c)
        return c.module_id ~= module_id
    end)
    print("ServiceCommand: Unregistered commands for module " .. module_id)
end

function ServiceCommand:BeforeReload()
    self:UnregisterCommands("ServiceCommand")
end

function ServiceCommand:AfterReload()
    self.commands = self.commands or {}

    self:RegisterCommand("ServiceCommand", "exit", nil, function(...) return self:ExitCommand(...) end)
    -- self:RegisterCommand("ServiceCommand", "reload_modules", nil, function(...) return self:ReloadModules(...) end)
end

function ServiceCommand:Init()
    self.commands = {}
end

function ServiceCommand:ReloadModules()
    -- modules.Reload()
    return true
end

function ServiceCommand:ExitCommand()
    copas.addthread(function()
        self.event_bus:PushEvent({
            event = "exit.pending",
            client = self,
        })
        print(self:LogTag() .. string.format(" Exiting in 10 seconds"))
        copas.sleep(10)
        print(self:LogTag() .. string.format(" Exiting"))
        self.event_bus:PushEvent({
            event = "exit.trigger",
            client = self,
        })
        os.exit(0)
    end)
    return true
end

-------------------------------------------------------------------------------------

return ServiceCommand
