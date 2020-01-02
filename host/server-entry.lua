#!/usr/bin/lua

local lapp = require 'pl.lapp'
local path = require "pl.path"
local dir = require "pl.dir"
local json = require("json")
local fairy_node_base = path.abspath(path.normpath(path.dirname(arg[0]) .. "/.."))
package.path = package.path .. ";" .. fairy_node_base .. "/host/?.lua" .. ";" .. fairy_node_base .. "/host/?/init.lua"

local args = lapp [[
FairyNode rest server entry
    --debug                        enter debug mode
]]

local conf = { }
conf.__index = conf
conf.__newindex = function()
   error("Attempt to change conf at runtime")
end

conf.debug = args.debug
conf.fairy_node_base = fairy_node_base

configuration = setmetatable({}, conf)

function LoadScript(name)
   return dofile(path.normpath(configuration.fairy_node_base .. "/" .. name))
end

local restserver = require("restserver")
server = restserver:new():port(8000)

function InvokeFile(file, method, ...)
   local succ, lib = pcall(dofile, configuration.fairy_node_base .. "/" .. file)
   if not succ then
      print("ERROR: " .. lib)
      return restserver.response():status(500):entity("500: " .. lib)
   end

   local status, result = pcall(lib[method], ...)
   if not status then
      print("ERROR: " .. result)
      return restserver.response():status(500):entity("500: " .. result)
   end

   -- if type(result) == "table" then
   --    result = json.encode(result)
   -- end

   local str = tostring(result)
   print("RESULT: " .. tostring(#str) .. " bytes")
   print(str:sub(1,256))
   return restserver.response():status(200):entity(result)
end

require "lib/rest-ota"
require "lib/rest-file"

require "lib/modules"

require("lib/rest").LoadEndpoints()
server:enable("restserver.xavante"):start()
