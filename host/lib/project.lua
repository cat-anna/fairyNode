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
      print("GENERATE:", f, #content, content)
   end

   local function store_table(f, t)
      table.sort(t)
      local content = "return {" .. table.concat( t, ",") .. "}"
      storage:AddFile(f, content)
      print("GENERATE:", f, #content, content)
   end

   table.insert(fileList, storage.basePath .. "/" .. "lfs-files.lua")
   table.insert(fileList, storage.basePath .. "/" .. "lfs-services.lua")
   table.insert(fileList, storage.basePath .. "/" .. "lfs-events.lua")
   table.insert(fileList, storage.basePath .. "/" .. "lfs-sensors.lua")

   local file_list = { }
   local event_list = { }
   local sensor_list = { }
   local service_list = { }

   for _, v in ipairs(fileList) do
      local base = path.basename(v)
      local name = base:gsub(".lua", "")

      table.insert(file_list, string.format([["%s"]], name))
      if name:find("srv%-") then
         table.insert(service_list, string.format([["%s"]], name))
      end
      if name:find("event%-") then
         table.insert(event_list, string.format([["%s"]], name))
      end
      if name:find("sensor%-") then
         table.insert(sensor_list, string.format([["%s"]], name))
      end
   end

   store_table("lfs-services.lua", service_list)
   store_table("lfs-events.lua", event_list)
   store_table("lfs-sensors.lua", sensor_list)
   store_table("lfs-files.lua", file_list)
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
   self.config = table.merge(self.chip.config, self.config.project.config)

   self.config["hostname"] = self.chip.name

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

function project:GetConfigFileContent(name)
   local v = self.config[name]
   if not v then
      print("There is no config " .. name)
      return nil
   end
   if type(v) == "string" then
      return v
   else
      return JSON.encode(v)
   end 
end

function project:GenerateConfigFiles(outStorage, list)
   local function store(f, content)
      outStorage:AddFile(f, content)
      if list then
         list[#list + 1] = f
      end
      print("GENERATE:", f, #content)
   end

   for k,_ in pairs(self.config) do
      store(k .. ".cfg",self:GetConfigFileContent(k))
   end
end

function project:GenerateDynamicFiles(source, outStorage, list)
   for k, v in pairs(source) do
      local lines, code = shell.LinesOf("lua", nil, v)
      if not code then
         error("Command execution failed!")
      end
      local content = table.concat(lines, "\n")
      print("GENERATE", k, #content)
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
