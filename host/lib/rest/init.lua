
require "lib/ext"
local modules = require("lib/modules")
local restserver = require "restserver"
local http = require "lib/http-code"
local lfs = require "lfs"
local copas = require "copas"
local JSON = require "json"

local base_dir = configuration.fairy_node_base .. "/host/lib/rest"

local RestPublic = {}

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

function RestPublic.HandlerModule(module, handler_name)
    local f = function(...)
        local args = { ... }
        local code, result

        local invoke_func = function()
            print(string.format("REST-REQUEST: %s.%s(%s)", module, handler_name, ConcatRequest(args, "; ")))
            local dev = modules.GetModule(module)
            code, result = dev[handler_name](dev, unpack(args))
        end

        local s, msg = SafeCall(invoke_func)
        if not s then
            print("ERROR:" .. msg)
            code = http.InternalServerError
            result = msg
        end
        print(string.format("REST-RESPONSE: Code:%d body:%s bytes", code, JSON.encode(result):len()))
        return restserver.response():status(code):entity(result)       
    end
    return f
end

local function LoadEndpoints(server)
    for file in lfs.dir(base_dir .. "/") do
        if file ~= "." and file ~= ".." and file ~= "init.lua" then
            local f = base_dir..'/'..file
            local attr = lfs.attributes (f)
            assert (type(attr) == "table")

            if attr.mode == "file" then
                local name = file:match("endpoint%-([^%.]+).lua")
                if name then
                    print("Loading REST endpoint " .. name)
                    local f = require("lib/rest/endpoint-" .. name)
                    SafeCall(f, server)
                end
            end
        end
    end
end

copas.addthread(function()
    copas.sleep(1)
    local restserver = require("lib/rest/restserver")
    local server = restserver:new()
    server:port(8000)
    server:response_headers({
        ["Access-Control-Allow-Origin"] = "*"
    })
    LoadEndpoints(server)
    server:enable("lib.rest.restserver.xavante"):start()
end)

return RestPublic
