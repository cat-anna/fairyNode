#!/usr/bin/lua

local path = require "pl.path"
local dir = require "pl.dir"
local json = require("json")
local baseDir = path.abspath(path.normpath(path.dirname(arg[0]) .. "/.."))
package.path = package.path .. ";" .. baseDir .. "/host/?.lua"

firmware = {
   baseDir = baseDir .. "/"
}

function LoadScript(name)
   return dofile(path.normpath(firmware.baseDir .. name))
end

local restserver = require("restserver")
server = restserver:new():port(8000)

function InvokeFile(file, method, ...)
   local succ, lib = pcall(dofile, firmware.baseDir .. file)
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

-- This loads the restserver.xavante plugin
server:enable("restserver.xavante"):start()
