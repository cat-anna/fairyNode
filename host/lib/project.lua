local lfs = require "lfs"
local file = require "pl.file"
local path = require "pl.path"
local JSON = require "json"
local shell = require "lib/shell"

local project = {}

local DeviceConfigFile = "devconfig.lua"
local FirmwareConfigFile = "fwconfig.lua"
luac_cross = "../nodemcu-firmware/luac.cross"

local function GenerateFileLists(storage, fileList)
   local function store(f, content)
      storage:AddFile(f, content)
      print("GENERATE:", f, #content)
   end

   table.insert(fileList, storage.basePath .. "/" .. "lfs-files.lua")
   table.insert(fileList, storage.basePath .. "/" .. "lfs-services.lua")
   table.insert(fileList, storage.basePath .. "/" .. "lfs-events.lua")
   table.insert(fileList, storage.basePath .. "/" .. "lfs-sensors.lua")
   table.insert(fileList, storage.basePath .. "/" .. "init-service.lua")

   local file_list = [[return { ]]
   local event_list = [[return { ]]
   local sensor_list = [[return { ]]
   local service_list = [[return { ]]
   local init_service = ""

   for _, v in ipairs(fileList) do
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
end

local function FilterFiles(source, fileList, generateList)
   for k, v in pairs(source) do
      local t = type(k)
      if t == "number" then
         fileList[#fileList + 1] = v
      elseif t == "string" then
         generateList[k] = v
      else
         error("Unknown file entry type: " .. t)
      end
   end
end

local function PreprocessGeneratedFile(conf, vars)
   for i, v in ipairs(conf) do
      local arg = path.normpath(v:formatEx(vars))
      -- print("GEN:", i, conf[i], "->", arg)
      conf[i] = arg
   end
end

local function PreprocessFileList(fileList, vars)
   table.sort(fileList)
   for k, v in pairs(fileList) do
      local t = type(k)
      -- print(t, k, v)
      if t == "number" then
         fileList[k] = path.normpath(v:formatEx(vars))
         -- print(k, fileList[k])
      elseif t == "string" then
         PreprocessGeneratedFile(v, vars)
      else
         error("Unknown file entry type: " .. t)
      end
   end
end

function project:Preprocess()
   self.lfs = table.merge(self.config.firmware.lfs, self.config.project.lfs)
   self.files = table.merge(self.config.firmware.files, self.config.project.files)

   local vars = {
      FW = firmware.baseDir .. "/src/",
      PROJECT = self.projectDir .. "/files/",
      COMMON = "common/"
   }

   print("LFS:")
   PreprocessFileList(self.lfs, vars)
   print("FILES:")
   PreprocessFileList(self.files, vars)

   self:UpdateLFSStamp()
end

function project:UpdateLFSStamp()
   if self.lfsStamp and self.lfsStamp > 0 then
      return self.lfsStamp
   end
   local max = 0

   function process(lst)
      for _, v in ipairs(lst) do
         if type(v) == "string" then
            local attr = lfs.attributes(v)
            if not attr then
               error("Cannot get attributes of file " .. v)
            end
            if attr.modification > max then
               max = attr.modification
            end
         end
      end
   end

   process(self.lfs)
   self.lfsStamp = max
   return self.lfsStamp
end

function project:GenerateConfigFiles(outStorage, list)
   local function store(f, content)
      outStorage:AddFile(f, content)
      if list then
         list[#list + 1] = f
      end
      print("GENERATE:", f, #content)
   end

   store("hostname.cfg", self.chip.name)

   for k, v in pairs(self.chip.config) do
      store(k .. ".cfg", JSON.encode(v))
   end
end

function project:GenerateDynamicFiles(source, outStorage, list)
   for k, v in pairs(source) do
      local lines, code = shell.LinesOf(nil, nil, v)
      if not code then
         error("Command execution failed!")
      end
      local content = table.concat(lines, "\n")
      -- print("GENERATE", k, #content, content)
      table.insert(list, outStorage:AddFile(k, content))
   end
   table.insert(list, outStorage:AddFile("lfs-timestamp.lua", string.format([[
      return %d
  ]], self:UpdateLFSStamp())))
end

function project:BuildLFS(outStorage)
   local generated_storage = require("lib/file_storage").new()

   local fileList = {}
   local generateList = {}
   FilterFiles(self.lfs, fileList, generateList)
   self:GenerateDynamicFiles(generateList, generated_storage, fileList)
   GenerateFileLists(generated_storage, fileList)

   local args = {
      "f",
      o = outStorage:AddFile("lfs.img.pending"),
   }
   if not self.chip.config.debug then
      table.insert(args, "s")
   end
   if self.chip.lfs and self.chip.lfs.size then
      args.m = tostring(self.chip.lfs.size)
   end

   shell.Start(luac_cross, args, nil, unpack(fileList))

   generated_storage:Clear()
end

return project
