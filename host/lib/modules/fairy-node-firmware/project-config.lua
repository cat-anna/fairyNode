
local path = require "pl.path"
local file = require "pl.file"
local json = require "json"
local md5 = require "md5"
local pretty = require 'pl.pretty'
local file_image = require "lib/file-image"
local shell = require "lib/shell"

-------------------------------------------------------------------------------------

local CONFIG_HASH_NAME = "config_hash.cfg"

-------------------------------------------------------------------------------------

local ProjectMt = {}
ProjectMt.__index = ProjectMt

function ProjectMt:Init(arg)
    for k,v in pairs(arg) do
        self[k] = v
    end

    self.search_paths = {
        self.project_path,
        self.firmware_path,
    }

    self:Preprocess()
end

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

local function PreprocessGeneratedFile(self, conf, paths)
    for i, v in ipairs(conf) do
        local arg = v--path.normpath(v:formatEx(paths))
        print("GEN:", i, conf[i], "->", arg)
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

local function FindFile(f, paths)
    if (f:sub(1,1) == "/") and lfs.attributes(f) then
        -- print("GLOBAL ", f, " -> ", f)
        return f
    end

    for i,v in ipairs(paths) do
        local full = path.normpath(v .. "/" .. f)
        local att = lfs.attributes(full)
        if att then
            -- print("RESOLVE ", f, " -> ", full)
            return full
        end
    end

    error("Failed to find " .. f .. " in \n" .. table.concat(paths, "\n"))
end

local function PreprocessFileList(self, fileList, paths)
    local keys = table.keys(fileList)
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

    for _, key in ipairs(keys) do
        local k = key
        local v = fileList[k]

        local t = type(k)
        -- print(t, k, v)

        if t == "number" then
            -- print(k, fileList[k])
            fileList[k] = FindFile(v, paths)
        elseif t == "string" then
            -- print(k, v.mode)
            if v.mode == "generated" then
                PreprocessGeneratedFile(self, v, paths)
            else
                error("Unknown file entry mode: " .. v.mode)
            end
        else
            error("Unknown file entry type: " .. t)
        end
    end
end

function ProjectMt:AddModuleFiles()
    for _, v in ipairs(self.modules) do
        -- print("PROCESSING MODULE: ", v)
        local fw_module = self.firmware.modules[v]
        if not fw_module then --
            error("There is no module: " .. v)
        end
        self.lfs = table.merge(self.lfs, fw_module.lfs)
        self.root = table.merge(self.root, fw_module.root)
    end
end

function ProjectMt:Preprocess()
    print("Preprocessing", self.chip.name)

    self.modules = table.merge(self.project.modules, table.keys(self.project.config.hw))
    -- print("MODULES: ", table.concat(self.modules, ","))

    self.lfs = table.merge(self.firmware.base.lfs, self.project.lfs)
    self.root = table.merge(self.firmware.base.root, self.project.root)
    self.config = table.merge(self.chip.config, self.project.config)
    self.ota_install = self.firmware.ota_install

    self.config["hostname"] = self.chip.name

    local fairy_node_base = "../fairyNode"

    self:AddModuleFiles()

    -- print("LFS:")
    PreprocessFileList(self, self.lfs, self.search_paths)
    -- print("FILES:")
    PreprocessFileList(self, self.root, self.search_paths)
    -- print("ota_install:")
    PreprocessFileList(self, self.ota_install, self.search_paths)
end

function ProjectMt:Timestamps()
    if self.__timestamps then --
        return self.__timestamps
    end

    print("Preparing timestamps", self.name)
    function process(lst)
        local content = {}
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
        return {timestamp = max, hash = md5.sumhexa(all_code)}
    end

    self.__timestamps = {
        lfs = process(self.lfs),
        root = process(self.root),
        config = json.decode(self:GenerateConfigFiles()[CONFIG_HASH_NAME])
    }
    return self.__timestamps
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
        return json.encode(v)
    end
end

function ProjectMt:GenerateConfigFiles()
    local r = {}
    local all_content = {}
    for k, _ in pairs(self.config) do
        local name = k .. ".cfg"
        local content = self:GetConfigFileContent(k)
        -- print("GENERATE:", name, #content)
        r[name] = content
        table.insert(all_content, name .. "|" .. content)
    end

    table.sort(all_content)
    r[CONFIG_HASH_NAME] = json.encode({
        hash = md5.sumhexa(table.concat(all_content, "")),
        timestamp = os.time()
    })

    return r
end

function ProjectMt:GenerateDynamicFiles(source, outStorage, list)
    for k, v in pairs(source) do
        local lines, code = shell.LinesOf("lua", nil, v)
        if not code then error("Command execution failed!") end
        local content = table.concat(lines, "\n")
        print("GENERATE", k, #content)
        table.insert(list, outStorage:AddFile(k, content))
    end

    local ts = self:Timestamps()
    local pretty_ts = pretty.write(ts.lfs)

    local timestamp_file = string.format([[return %s ]], pretty_ts)

   --  print("LFS-TIMESTAMP: \n---------------\n" .. timestamp_file ..
   --            "\n---------------")

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

function ProjectMt:BuildLFS(luac)
    if not luac then error("LFS compiler is not available") end

    local generated_storage = require("lib/file-temp-storage").new()

    local fileList = {}
    local generateList = {}
    FilterFiles(self.lfs, fileList, generateList)
    self:GenerateDynamicFiles(generateList, generated_storage, fileList)
    GenerateFileLists(generated_storage, fileList)
    if not AssertFileUniqness(fileList) then
        error("Canot generate lfs if not all files are unique!")
    end

    print("Files in lfs: ", #fileList,
          table.concat(table.sorted(fileList), " "))
    local result_file = generated_storage:AddFile("lfs.pending.img")
    local args = {"f", o = result_file}
    if not self.chip.config.debug then table.insert(args, "s") end
    if not self.chip.config.integer then table.insert(args, "f") end
    if self.chip.lfs and self.chip.lfs.size then
        args.m = tostring(self.chip.lfs.size)
    end

    --
    shell.Start(luac, args, nil, table.unpack(fileList))

    local image = file.read(result_file)

    generated_storage:Clear()

    return image
end

function ProjectMt:BuildRootImage()
    local fileList = {}
    for _, v in ipairs(self.root) do
        fileList[path.basename(v)] = file.read(v)
    end

    local ts = self:Timestamps()

    --  print(JSON.encode(ts.root))
    fileList["root-timestamp.lua"] = "return " .. pretty.write(ts.root)

    local files = table.keys(fileList)
    print("Files in root: ", #files, table.concat(files, " "))
    return file_image.Pack(fileList), file_image.VersionHash()
end

function ProjectMt:BuildConfigImage()
    local fileList = self:GenerateConfigFiles()

    local files = table.keys(fileList)
    print("Files in config: ", #files, table.concat(files, " "))
    return file_image.Pack(fileList), file_image.VersionHash()
end

function ProjectMt:GetOtaInstallFiles()
    local fileList = { }
    for _, v in ipairs(self.ota_install) do
        fileList[path.basename(v)] = file.read(v)
    end
    return fileList
end

-------------------------------------------------------------------------------------

return ProjectMt
