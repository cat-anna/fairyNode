local lfs = require "lfs"
local file = require "pl.file"
local path = require "pl.path"
local JSON = require "json"

local device = {}
local chip = {}

function table.append(t1, t2, t3, t4, t5)
   for k, v in pairs(t2) do
      if type(k) == "number" then
         t1[#t1 + 1] = v
      else
         t1[k] = v
      end
   end
   for k, v in pairs(t3) do
      if type(k) == "number" then
         t1[#t1 + 1] = v
      else
         t1[k] = v
      end
   end
   for k, v in pairs(t4) do
      if type(k) == "number" then
         t1[#t1 + 1] = v
      else
         t1[k] = v
      end
   end
   for k, v in pairs(t5) do
      if type(k) == "number" then
         t1[#t1 + 1] = v
      else
         t1[k] = v
      end
   end
   return t1
end

local DeviceConfigFile = "devconfig.lua"
local FirmwareConfigFile = "fwconfig.lua"
luac_cross = "../nodemcu-firmware/luac.cross"

function device.GetChipConfig(chipid)
   local config = dofile(DeviceConfigFile)

   local r = config.chipid[chipid]
   r.id = chipid
   r.projectDir = config.projectDir .. "/" .. r.project
   return setmetatable(r, {__index = chip})
end

function device:UpdateLFSStamp()
   local max = 0

   function process(lst)
      for _, v in ipairs(lst) do
         local attr = lfs.attributes(v)
         if not attr then
            error("Cannot get attributes of file " .. v)
         end
         if attr.modification > max then
            max = attr.modification
         end
      end
   end

   process(self.lfs)

   self.lfsStamp = max

   return max
end

function device:GenerateConfigFiles(storage)
   local function store(f, content)
      storage:AddFile(f, content)
      print("GENERATE:", f, #content)
   end

   store("hostname.cfg", self.chip.name)

   for k, v in pairs(self.chip.config) do
      print(k, v)
      store(k .. ".cfg", JSON.encode(v))
   end
end

function device:CompileLFS(out_storage)
   local storage = require("lib/tmp_storage").new()

   local file_list = [[return { ]]

   local function store(f, content)
      storage:AddFile(f, content)
      print("GENERATE:", f, #content)

      local base = path.basename(f)
      local name = base:gsub(".lua", "")      
      file_list = file_list .. string.format([["%s",]], name)
   end

   store("lfs-timestamp.lua", string.format([[
        return %d
    ]], self:UpdateLFSStamp()))

   local event_list = [[return { ]]
   local sensor_list = [[return { ]]
   local service_list = [[return { ]]
   local init_service = ""

   for _, v in ipairs(self.lfs) do
      local base = path.basename(v)
      local name = base:gsub(".lua", "")

      file_list = file_list .. string.format([["%s",]], name)
      if name:find("srv%-") then
         service_list = service_list .. string.format([["%s",]], name)
         init_service =
            init_service .. string.format('print("INIT: Loading %s")\npcall(require("%s").Init)\n', name, name)
      end

      if name:find("event%-") then
         event_list = event_list .. string.format([["%s",]], name)
      end
      if name:find("sensor%-") then
         sensor_list = sensor_list .. string.format([["%s",]], name)
      end      
   end

   sensor_list = sensor_list .. "}"
   event_list = event_list .. "}"
   service_list = service_list .. "}"

   store("lfs-services.lua", service_list)
   store("lfs-events.lua", event_list)
   store("lfs-sensors.lua", sensor_list)
   store("init-service.lua", init_service)
   
   file_list = file_list .. "}"
   store("lfs-files.lua", file_list)

   local args = {
      luac_cross,
      "-f",
      "-o", out_storage:AddFile("lfs.img.pending"),
   }

   if not self.chip.config.debug then
      table.insert(args, "-s")
   end

   if  self.chip.lfs and  self.chip.lfs.size then
      table.insert(args, "-m")
      table.insert(args, tostring(self.chip.lfs.size))
   end

   table.insert(args, table.concat(self.lfs, " "))
   table.insert(args, table.concat(storage.list, " "))
   
   local cmd = table.concat(args, " ")
   print(cmd)
   os.execute(cmd)

   storage:Clear()
end

function chip:GetDeviceConfig()
   local cfg = {}
   setmetatable(cfg, {__index = device})

   local global = dofile(FirmwareConfigFile)
   local device = dofile(self.projectDir .. "/" .. FirmwareConfigFile)

   local function addPrefix(lst, prefix)
      local r = {}
      for i, v in ipairs(lst) do
         r[#r + 1] = prefix .. v
      end
      return r
   end

   local chip_prefix = self.projectDir .. "/files/"
   local fw_prefix = _G.cfg.baseDir .. "/src/"
   local common_prefix = "common/"

   device.lfs = addPrefix(device.lfs, chip_prefix)
   device.files = addPrefix(device.files, chip_prefix)
   device.firmware.lfs = addPrefix(device.firmware.lfs, fw_prefix)
   device.firmware.files = addPrefix(device.firmware.files, fw_prefix)
   device.common.lfs = addPrefix(device.common.lfs, common_prefix)
   device.common.files = addPrefix(device.common.files, common_prefix)

   global.lfs = addPrefix(global.lfs, common_prefix)
   global.files = addPrefix(global.files, common_prefix)
   global.firmware.lfs = addPrefix(global.firmware.lfs, fw_prefix)
   global.firmware.files = addPrefix(global.firmware.files, fw_prefix)

   cfg.chip = self

   cfg.lfs = table.append(global.lfs, global.firmware.lfs, device.common.lfs, device.lfs, device.firmware.lfs)
   cfg.files =
      table.append(global.files, global.firmware.files, device.common.files, device.files, device.firmware.files)

   return cfg
end

return device
