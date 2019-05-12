#!/usr/bin/lua

local path = require "pl.path"
local dir = require "pl.dir"
local json = require("json")
local baseDir = path.abspath(path.normpath(path.dirname(arg[0]) .. "/.."))
print(baseDir)
package.path = package.path .. ";" .. baseDir .. "/host/?.lua"

cfg = {
   baseDir = baseDir .. "/"
}

local restserver = require("restserver")
server = restserver:new():port(8080)

function InvokeFile(file, method, ...)
   local succ, lib = pcall(dofile, cfg.baseDir .. file)
   if not succ then
      print("ERROR: " .. lib)
      return restserver.response():status(500):entity("500: " .. lib)
   end

   local status, result = pcall(lib[method], ...)
   if not status then
      print("ERROR: " .. result)
      return restserver.response():status(500):entity("500: " .. result)
   end

   if type(result) == "table" then
      result = json.encode(result)
   end

   print("RESULT: ", tostring(result))
   return restserver.response():status(200):entity(result)
end

require "lib/rest-ota"
require "lib/rest-file"

-- This loads the restserver.xavante plugin
server:enable("restserver.xavante"):start()
