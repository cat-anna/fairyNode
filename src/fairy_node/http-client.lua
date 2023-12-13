
local copas = require "copas"
local copas_http = require("copas.http")
local ltn12 = require("ltn12")
local tablex = require "pl.tablex"
local json = require "rapidjson"

-------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------

local HttpClient = {}
HttpClient.__index = HttpClient

-------------------------------------------------------------------------------------

local function make_request_func(method)
    return function(self, arg)
        local copy = tablex.copy(arg)
        copy.method = method
        return self:Request(copy)
    end
end

HttpClient.Get = make_request_func("GET")
HttpClient.Post = make_request_func("POST")

-------------------------------------------------------------------------------------

local function make_json_request_func(method)
    return function(self, url, body)
        local copy = {
            url = url,
            body = body,
        }
        copy.method = method

        if copy.body then
            copy.mime_type = "application/json"
            copy.body = json.encode(copy.body)
        else
            copy.body = ""
        end

        local r, c = self:Request(copy)
        if r and c == 200 then
            return json.decode(r), c
        else
            return nil, c
        end
    end
end

HttpClient.GetJson = make_json_request_func("GET")
HttpClient.PostJson = make_json_request_func("POST")

-------------------------------------------------------------------------------------

function HttpClient:Request(arg)
    if arg.callback then
        copas.addthread(function() self:ProcessRequest(arg) end )
    else
        return self:ProcessRequest(arg)
    end
end

function HttpClient:ProcessRequest(arg)
    local url = "http://" .. self.host .. "/" .. arg.url
    local err
    local response = "" -- for the response body
    if type(arg.body) == "table" then
        arg.mime_type = "application/json"
        arg.body = json.encode(arg.body)
    else
        arg.body = tostring(arg.body)
    end
    print(string.format("Request(%s %s): size=%d", arg.method, url, #arg.body))
    if arg.body then
        local dummy
        local table_response = { }
        dummy, err = copas_http.request({
          method = arg.method,
          url = url,
          source = ltn12.source.string(arg.body),
          sink = ltn12.sink.table(table_response),
          headers = {
            ["content-type"] =  arg.mime_type or "application/octet-stream",
            ["content-length"] = tostring(#arg.body)
        },
      })
      response = table.concat(table_response, "")
    else
        response, err = copas_http.request(url)
    end
    print(string.format("Response(%s %s): code=%s size=%d", arg.method, url, tostring(err), response:len()))
    if err ~= 200 then
        print("Failed to query " .. url .. " code " .. tostring(err))
        print(response)
    end
    if arg.callback then
        arg.callback(response, err)
    else
        return response, err
    end
end

-------------------------------------------------------------------------------------

function HttpClient:SetHost(new_host)
    self.host = new_host
end

-------------------------------------------------------------------------------------

return {
    New = function(arg)
       return setmetatable(arg or {}, HttpClient)
    end
}

