local copas = require "copas"
local file = require "pl.file"
local http = require "lib/http-code"
local JSON = require "json"
local lfs = require "lfs"
local modules = require "lib/loader-module"
local path = require "pl.path"
local restserver = require "lib/rest/restserver"
local scheduler = require "lib/scheduler"

-------------------------------------------------------------------------------

local function ConcatRequest(args, sep)
    local t = {}
    for _,v in ipairs(args) do
        if type(v) == "table" then
            local r = pcall(function()
                table.insert(t, JSON.encode(v))
            end)
            if not r then
                table.insert(t, "<?>")
            end
        else
            table.insert(t, v)
        end
    end
    return table.concat(t, sep)
end

-------------------------------------------------------------------------------

local CONFIG_KEY_REST_ENDPOINT_LIST = "rest.endpoint.list"
local CONFIG_KEY_REST_ENDPOINT_PATHS = "rest.endpoint.paths"
local CONFIG_KEY_REST_PORT = "rest.port"
local CONFIG_KEY_MODULE_PATHS = "loader.module.paths"

-------------------------------------------------------------------------------

local RestServer = {}
RestServer.__index = RestServer
RestServer.__deps = {
    loader_module = "base/loader-module"
}
RestServer.__config = {
    [CONFIG_KEY_REST_ENDPOINT_LIST] = { mode = "merge", type = "string-table", default = { } },
    [CONFIG_KEY_REST_ENDPOINT_PATHS] = { mode = "merge", type = "string-table", default = { } },
    [CONFIG_KEY_REST_PORT] = { type = "integer", default = 8000 },

    [CONFIG_KEY_MODULE_PATHS] = { mode = "merge", type = "string-table", default = { } },
}

-------------------------------------------------------------------------------

function RestServer:FindEndpoint(endpoint_name)
    for _,endpoint_path in ipairs(self.config[CONFIG_KEY_REST_ENDPOINT_PATHS]) do
        local full = endpoint_path .. "/" .. endpoint_name .. ".lua"
        if path.isfile(full) then
            return path.normpath(full)
        end
    end
    for _,endpoint_path in ipairs(self.config[CONFIG_KEY_MODULE_PATHS]) do
        local full = endpoint_path .. "/" .. endpoint_name .. ".lua"
        if path.isfile(full) then
            return path.normpath(full)
        end
    end
end

function RestServer:AddEndpoint(endpoint_def)
    local module = self.loader_module:LoadModule(endpoint_def.service)

    for _,endpoint in ipairs(endpoint_def.endpoints) do
        if endpoint.service_method then
            endpoint.handler = self:HandlerModule(endpoint_def.service, module, endpoint.service_method)
            endpoint_def.service_method = nil
        end
    end

    self.server:add_resource(endpoint_def.resource,endpoint_def.endpoints)
end

function RestServer:LoadEndpoints()
    for _,endpoint_name in ipairs(self.config[CONFIG_KEY_REST_ENDPOINT_LIST]) do
        local endpoint_file = self:FindEndpoint(endpoint_name)
        if not endpoint_file then
            printf(self, "failed to find source for endpoint %s", endpoint_name)
        else
            printf(self, "Adding endpoint %s", endpoint_name)
            self:AddEndpoint(dofile(endpoint_file))
        end
    end
end

-------------------------------------------------------------------------------

function RestServer:InitServer()
    copas.sleep(0.1)
    local port = self.config[CONFIG_KEY_REST_PORT]
    local server = restserver:new()
    self.server = server
    server:port(port)
    server:response_headers({
        ["Access-Control-Allow-Origin"] = "*"
    })
    self:LoadEndpoints()
    printf(self, "Starting server initialized on port %d", port)
end


function RestServer:ExecuteServer(task)
    copas.sleep(1)
    if self.server then
        print(self, "Server started")
        self.server:enable("lib.rest.restserver.xavante"):start()
        print(self, "Server stopped")
        self.server = nil
        self.server_task = nil
    end
    task:Stop()
end

-------------------------------------------------------------------------------

function RestServer:HandlerModule(module_name, module, handler_name)
    local f = function(...)
        local args = { ... }
        local code, result, content_type

        -- print(tostring(args[1]))
        local request = table.remove(args, 1)

        local invoke_func = function()
            -- print(string.format("REST-REQUEST: %s.%s(%s)", module, handler_name, ConcatRequest(args, "; ")))
            local handler = (module or {})[handler_name]
            if not handler then
                print(string.format("No handler for request : %s.%s(%s)", module_name, handler_name, ConcatRequest(args, "; ")))
                return
            end
            table.insert(args, request.params or {})
            code, result, content_type = handler(module, unpack(args))
        end

        local s, msg = SafeCall(invoke_func)
        if not s then
            print("ERROR:" .. (msg or "?"))
            code = http.InternalServerError
            result = msg
        end

        -- print(string.format("REST-RESPONSE: Code:%d body:%s bytes", code, (type(result) == "string" and result:len() or JSON.encode(result):len())))
        local response = restserver.response()
        response:status(code)
        response:entity(result)
        if content_type then
            response:content_type(content_type)
        end
        return response
    end
    return f
end

-------------------------------------------------------------------------------

function RestServer:Tag()
    return "RestServer"
end

function RestServer:BeforeReload()
end

function RestServer:AfterReload()
end

function RestServer:Init()
    copas.addthread(function()
        copas.sleep(0.1)
        self:InitServer()
    end)
end

function RestServer:PostInit()
end

function RestServer:StartModule()
    if not self.server_task then
        self.server_task = scheduler:CreateTask(
            self,
            "Rest server",
            1,
            self.ExecuteServer)
    end
end

-------------------------------------------------------------------------------

return RestServer
