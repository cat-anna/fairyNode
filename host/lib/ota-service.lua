
local Chip = LoadScript("/host/lib/chip.lua")

local file = require "pl.file"

local ota = {}

function ota.ListDevices()
   local conf = Chip.LoadConfig(id)

   local r = { }

   for k,v in pairs(conf.chipid) do
      local cfg = { }
      r[k] = cfg
      cfg.ota = not v.ota.disabled
      cfg.name = v.name
      cfg.project = v.project
   end

   return r
end

function ota.Status(id) 
   local chip = Chip.GetChipConfig(id)
   print(id .. " is " .. chip.name)

   local project = chip:LoadProjectConfig()
   print("OTA stamp: ", project.lfsStamp)

   return {
      timestamp = project.lfsStamp,
      enabled = not chip.ota.disabled
   }
end

function ota.Image(id) 
   local chip = Chip.GetChipConfig(id)
   print(id .. " is " .. chip.name)

   local project = chip:LoadProjectConfig()
   print("OTA stamp: ", project.lfsStamp)

   local storage = require("lib/file_storage").new()
   project:BuildLFS(storage)

   if #storage.list ~= 1 then
      error "CompileLFS produced incorrect count of files"
   end

   local data = file.read(storage.list[1])
   print("Compiled size: ", #data)

   storage:Clear()

   return data
end

return ota
