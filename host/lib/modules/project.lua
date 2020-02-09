
local copas = require "copas"
local lfs = require "lfs"
local file = require "pl.file"
local path = require "pl.path"
local JSON = require "json"
local shell = require "lib/shell"
local md5 = require "md5"
local pretty = require 'pl.pretty'
local struct = require 'struct'
local file_image = require "lib/file-image"

local DeviceConfigFile = "devconfig.lua"
local FirmwareConfigFile = "fwconfig.lua"

local luac_cross = "../nodemcu-firmware/luac.cross" -- TODO
local CONFIG_HASH_NAME = "config_hash.cfg"

local ProjectMt = {}
ProjectMt.__index = ProjectMt

local function GenerateFileLists(storage, fileList)
   local function store(f, content)
      storage:AddFile(f, content)
      print("GENERATE:", f, #content, content)
   end

   local function store_table(f, t)
      table.sort(t)
      local content = "return {" .. table.concat(t, ",") .. "}"
      storage:AddFile(f, content)
      print("GENERATE:", f, #content, content)
   end

   table.insert(fileList, storage.basePath .. "/" .. "lfs-files.lua")
   table.insert(fileList, storage.basePath .. "/" .. "lfs-services.lua")
   table.insert(fileList, storage.basePath .. "/" .. "lfs-events.lua")

   local file_list = {}
   local event_list = {}
   local service_list = {}

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
   end

   store_table("lfs-services.lua", service_list)
   store_table("lfs-events.lua", event_list)
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

local function PreprocessGeneratedFile(self, conf, vars)
   for i, v in ipairs(conf) do
      local arg = path.normpath(v:formatEx(vars))
      -- print("GEN:", i, conf[i], "->", arg)
      conf[i] = arg
   end
end

-- local function PreprocessConditionalFile(self, fileList, name, item, vars)
--    if self.config.hw[name] then
--       for i, v in ipairs(item) do
--          local arg = path.normpath(v:formatEx(vars))
--          -- print("COND:", i, item[i], "->", arg)
--          table.insert(fileList, arg)
--       end
--    end
-- end

local function PreprocessFileList(self, fileList, vars)
   local keys = table.keys(fileList)
   table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)

   for _, key in ipairs(keys) do
      local k = key
      local v = fileList[k]

      local t = type(k)
      -- print(t, k, v)

      if t == "number" then
         -- print(k, fileList[k])
         fileList[k] = path.normpath(v:formatEx(vars))
      elseif t == "string" then
         print(k, v.mode)
         if v.mode == "generated" then
            PreprocessGeneratedFile(self, v, vars)
         else
            error("Unknown file entry mode: " .. v.mode)
         end
      else
         error("Unknown file entry type: " .. t)
      end
   end
end

function ProjectMt:AddModuleFiles() 
   for _,v in ipairs(self.modules) do
      -- print("PROCESSING MODULE: ", v)
      local fw_module = self.firmware.modules[v]
      if not fw_module then
         error("There is no module: " .. v)
      end
      self.lfs = table.merge(self.lfs, fw_module.lfs or {})
      self.files = table.merge(self.files, fw_module.files or {})
   end
end

function ProjectMt:Preprocess()
   self.modules = table.merge(self.config.project.modules or {}, table.keys(self.config.project.config.hw))
   print("MODULES: ", table.concat(self.modules, ","))

   self.lfs = table.merge(self.config.firmware.lfs, self.config.project.lfs)
   self.files = table.merge(self.config.firmware.files, self.config.project.files)
   self.config = table.merge(self.chip.config, self.config.project.config)

   self.config["hostname"] = self.chip.name

   local vars = {
      FW = configuration.fairy_node_base .. "/src/",
      PROJECT = self.projectDir .. "/files/",
      COMMON = "common/"
   }

   self:AddModuleFiles()

   -- print("LFS:")
   PreprocessFileList(self, self.lfs, vars)
   -- print("FILES:")
   PreprocessFileList(self, self.files, vars)
end

function ProjectMt:CalcTimestamps()
   function process(lst)
      local content = { }
      local max = 0
      for _, v in ipairs(lst) do
         if type(v) == "string" then
            local attr = lfs.attributes(v)
            if not attr then
               error("Cannot get attributes of file " .. v)
            end
            if attr.modification > max then
               max = attr.modification
            end
            table.insert(content, file.read(v))
         end
      end
      local all_code = table.concat(content, "")
      return { timestamp = max, hash = md5.sumhexa(all_code) }
   end

   return { 
      lfs = process(self.lfs),
      root = process(self.files),
      config = json.decode(self:GenerateConfigFiles()[CONFIG_HASH_NAME]),
   }
end

function ProjectMt:GetConfigFileContent(name)
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

function ProjectMt:GenerateConfigFiles()
   local r = { }
   local all_content = { }
   for k, _ in pairs(self.config) do
      local name = k .. ".cfg"
      local content = self:GetConfigFileContent(k)
      -- print("GENERATE:", name, #content)
      r[name] = content
      table.insert(all_content, name .. "|" .. content)
   end 

   table.sort(all_content)
   r[CONFIG_HASH_NAME] = JSON.encode({
        hash = md5.sumhexa(table.concat(all_content, "")),
        timestamp = os.time(),
   })

   return r
end

function ProjectMt:GenerateDynamicFiles(source, outStorage, list)
   for k, v in pairs(source) do
      local lines, code = shell.LinesOf("lua", nil, v)
      if not code then
         error("Command execution failed!")
      end
      local content = table.concat(lines, "\n")
      print("GENERATE", k, #content)
      table.insert(list, outStorage:AddFile(k, content))
   end

   local ts = self:CalcTimestamps()
   local pretty_ts = pretty.write(ts.lfs)

   local timestamp_file = string.format([[return %s ]], pretty_ts )
   print("LFS-TIMESTAMP: \n---------------\n" .. timestamp_file .. "\n---------------")
   
   table.insert(list, outStorage:AddFile("lfs-timestamp.lua", timestamp_file))
end

local function AssertFileUniqness(fileList)
   local arr = {}
   local succ = true
   for _, v in ipairs(fileList) do
      if arr[v] then
         succ = false
         print("FILE IS NOT UNIQUE: " .. v)
      end
      arr[v] = true
   end
   return succ
end

function ProjectMt:BuildLFS(outStorage)
   local generated_storage = require("lib/file_storage").new()

   local fileList = {}
   local generateList = {}
   FilterFiles(self.lfs, fileList, generateList)
   self:GenerateDynamicFiles(generateList, generated_storage, fileList)
   GenerateFileLists(generated_storage, fileList)
   if not AssertFileUniqness(fileList) then
      error("Canot generate lfs if not all files are unique!")
   end

   print("Files in lfs: ", #fileList, "\n" .. table.concat(table.sorted(fileList), "\n"))
   local args = {
      "f",
      o = outStorage:AddFile("lfs.pending.img")
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

function ProjectMt:BuildRootImage()
   local fileList = {}
   for _,v in ipairs(self.files) do
      fileList[path.basename(v)] = file.read(v)
   end

   local ts = self:CalcTimestamps()

   print(JSON.encode(ts.root))
   fileList["root-timestamp.lua"] = "return " .. pretty.write(ts.root)

   local files = table.keys(fileList)
   print("Files in root: ", #files, "\n" .. table.concat(files, "\n"))
   return file_image.Pack(fileList)
end

function ProjectMt:BuildConfigImage()
   local fileList = self:GenerateConfigFiles()
   
   local files = table.keys(fileList)
   print("Files in config: ", #files, "\n" .. table.concat(files, "\n"))
   return file_image.Pack(fileList)
end

-----------------------------------------------

local ProjectModule = {}
ProjectModule.__index = ProjectModule
ProjectModule.Deps = {
   devconfig = "project-config",
   fwconfig = "fw-config",
}

function ProjectModule:LogTag()
   return "ProjectModule"
end

function ProjectModule:BeforeReload()
end

function ProjectModule:AfterReload()
end

function ProjectModule:Init()
end

function ProjectModule:ProjectExists(chipid)
  return self.devconfig.chipid[chipid] ~= nil
end

function ProjectModule:ListDeviceIds()
   return table.keys(self.devconfig.chipid)
end

function ProjectModule:LoadProject(chipid)
   local chip_config = self.devconfig.chipid[chipid]
   if not chip_config then
      error("ERROR: Unknown chip " .. chipid)
   end

   local mt = {
      __index = function(t, name)      
         return rawget(t, name) or self.devconfig.chipid[chipid][name] or ProjectMt[name]
      end
   }

   local proj = {
      chip = chip_config,
   }

   proj.projectDir = self.devconfig.projectDir .. "/" .. chip_config.project

   proj.firmware = self.fwconfig -- TODO
   proj.config = {
      firmware = self.fwconfig,
      project = dofile(proj.projectDir .. "/" .. FirmwareConfigFile)
   }

   setmetatable(proj, mt)
   proj:Preprocess()
   return proj
end

return ProjectModule
