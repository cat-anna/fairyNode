
local Device = dofile(cfg.baseDir .. "host/lib/device.lua")

local file = require "pl.file"

local ota = {}

function ota.Status(id) 
   local chip = Device.GetChipConfig(id)
   print(id .. " is " .. chip.name)

   local device = chip:GetDeviceConfig()
   device:UpdateLFSStamp()
   print("OTA stamp: ", device.lfsStamp)

   return {
      timestamp = device.lfsStamp,
      enable = not (chip.Ota and chip.ota.disable)
   }
end

function ota.Image(id) 
   local chip = Device.GetChipConfig(id)
   print(id .. " is " .. chip.name)

   local device = chip:GetDeviceConfig()
   device:UpdateLFSStamp()
   print("OTA stamp: ", device.lfsStamp)

   local storage = require("lib/tmp_storage").new()
   device:CompileLFS(storage)

   if #storage.list ~= 1 then
      error "CompileLFS produced more than one file"
   end

   local data = file.read(storage.list[1])
   print("Compiled size: ", #data)

   storage:Clear()

   return data
end

return ota
