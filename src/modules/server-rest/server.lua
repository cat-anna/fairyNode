local copas = require "copas"
local file = require "pl.file"
local http = require "fairy_node/http-code"
local lfs = require "lfs"
local loader_module = require "fairy_node/loader-module"
local path = require "pl.path"
local scheduler = require "fairy_node/scheduler"
local restserver = require "modules/server-rest/restserver"
local json = require "rapidjson"

-------------------------------------------------------------------------------

local function ConcatRequest(args, sep)
    local t = {}
    for _,v in ipairs(args) do
        if type(v) == "table" then
            local r = pcall(function()
                table.insert(t, json.encode(v))
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

local RestServer = {}
RestServer.__tag = "RestServer"
RestServer.__type = "module"
RestServer.__deps = { }

-------------------------------------------------------------------------------

function RestServer:FindEndpoint(endpoint_name)
    -- for _,endpoint_path in ipairs(self.config.endpoint_paths) do
    --     local full = endpoint_path .. "/" .. endpoint_name .. ".lua"
    --     if path.isfile(full) then
    --         return path.normpath(full)
    --     end
    -- end
    for _,endpoint_path in ipairs(self.config.module_paths) do
        local full = endpoint_path .. "/" .. endpoint_name .. ".lua"
        if path.isfile(full) then
            return path.normpath(full)
        end
    end
end

function RestServer:AddEndpoint(endpoint_name, endpoint_file)
    local load_result = { pcall(dofile, endpoint_file) }
    local r = table.remove(load_result, 1)
    if not r then
        printf(self, "Failed to load endpoint: %s - %s", endpoint_name, load_result[1])
        return
    end

    assert(type(load_result[1]) ~= "boolean")
    for _,endpoint_def_func in ipairs(load_result) do
        local endpoint_def
        if type(endpoint_def_func) == "function" then
            local builder = require("modules/server-rest/builder-endpoint"):New()
            endpoint_def_func(builder)
            endpoint_def = builder.resource

        else
            endpoint_def = endpoint_def_func
        end

        assert(endpoint_def)
        local resource = endpoint_def.resource
        assert(resource)
        assert(not self.endpoints[resource])

        local module = loader_module:LoadModule(endpoint_def.service)
        assert(module)

        self.endpoints[resource] = {
            file = endpoint_file,
            definition = endpoint_def,
            timestamp = os.timestamp(),
        }

        for _,endpoint in ipairs(endpoint_def.endpoints) do
            if endpoint.service_method then
                endpoint.handler = self:HandlerModule(endpoint_def.service, module, endpoint.service_method)
                endpoint.service_method = nil
            end
        end

        self.server:add_resource(endpoint_def.resource, endpoint_def.endpoints)
        printf(self, "Registered endpoint /%s service:%s", endpoint_def.resource, endpoint_def.service)
    end
end

function RestServer:LoadEndpoints()
    local config_handler = require "fairy_node/config-handler"
    local endpoints = config_handler:QueryConfigItem("module.rest-server.endpoint.list")

    for _,endpoint_name in ipairs(endpoints) do
        local endpoint_file = self:FindEndpoint(endpoint_name)
        if not endpoint_file then
            printf(self, "failed to find source for endpoint %s", endpoint_name)
        else
            -- printf(self, "Adding endpoint %s", endpoint_name)
            self:AddEndpoint(endpoint_name, endpoint_file)
        end
    end
end

-------------------------------------------------------------------------------

function RestServer:InitServer()
    copas.sleep(0.1)
    local port = self.config.rest_port
    local host = self.config.rest_host
    local server = restserver:new()
    self.server = server
    server:port(port)
    server:host(host)
    server:response_headers({
        -- ["Access-Control-Allow-Origin"] = "*"
    })
    self:LoadEndpoints()
    printf(self, "Starting server initialized on port %s:%d", host, port)
end

function RestServer:ExecuteServer(task)
    local function HttpLogger(...)
        if self.logger:Enabled() then
            self.logger:WriteCsv{ ... }
        end
    end

    copas.sleep(1)
    if self.server then
        print(self, "Server started")
        self.server:enable("modules.server-rest.xavante"):start(HttpLogger)
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
                code = http.InternalServerError
                return
            end
            table.insert(args, request.params or {})
            code, result, content_type = handler(module, table.unpack(args))
        end

        local s, msg = SafeCall(invoke_func)
        if not s then
            print("ERROR:" .. (msg or "?"))
            code = http.InternalServerError
            result = msg
        end

        -- print(string.format("REST-RESPONSE: Code:%d body:%s bytes", code, (type(result) == "string" and result:len() or json.encode(result):len())))
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


function RestServer:Init(opt)
    RestServer.super.Init(self, opt)

    self.endpoints = { }
    self.logger = require("fairy_node/logger"):New("rest-server")
end

function RestServer:PostInit()
end

function RestServer:StartModule()
    RestServer.super.StartModule(self)
    copas.addthread(function()
        copas.sleep(0.1)
        self:InitServer()
    end)
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
