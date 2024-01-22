
local path = require "pl.path"
local file = require "pl.file"
local json = require "rapidjson"
-- local md5 = require "md5"
local pretty = require 'pl.pretty'
local file_image = require "fairy_node/tools/file-image"
local shell = require "fairy_node/shell"
local tablex = require "pl.tablex"
-- local stringx = require "pl.stringx"
local lfs = require "lfs"

-------------------------------------------------------------------------------------

local CONFIG_HASH_NAME = "config_hash.cfg"

local function sha256(data)
    local sha2 = require "fairy_node/sha2"
    return sha2.sha256(data):lower()
end

local function md5(data)
    local md5_lib = require "md5"
    return md5_lib.sumhexa(data)
end

-------------------------------------------------------------------------------------

local DeviceConfig = { }
DeviceConfig.__type = "class"

function DeviceConfig:Init(arg)
    DeviceConfig.super.Init(self, arg)

    self.project = arg.project
    self.chip = arg.chip
    self.owner = arg.owner

    self.firmware = arg.firmware

    self:Preprocess()
end

function DeviceConfig:GetLfsSize()
    --TODO
    return 128*1024
    -- local poject_image = self.project.image
    -- if poject_image and poject_image.lfs_size then
    --     return poject_image.lfs_size
    -- end

    -- return self.firmware.image.lfs_size
end

local function GenerateFileLists(storage, fileList)
    local function store(f, content)
        storage:AddFile(f, content)
        -- print("GENERATE:", f, #content, content)
    end

    local function store_table(f, t)
        table.sort(t)
        local content = "return {" .. table.concat(t, ",") .. "}"
        storage:AddFile(f, content)
        -- print("GENERATE:", f, #content, content)
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

function DeviceConfig:Preprocess()
    if self.ready then
        return
    end

    print("Preprocessing", self.chip.name)
    self.project:Preprocess()

    self.modules = tablex.deepcopy(self.project.modules)

    self.lfs =    tablex.deepcopy(self.project.components.lfs) -- table.merge(self.firmware.base.lfs, self.project.lfs)
    self.root =   tablex.deepcopy(self.project.components.root) -- table.merge(self.firmware.base.root, self.project.root)

    local is_debug = self.chip.debug
    self.config = table.merge(
        self.owner.config[is_debug and "debug" or "current"],
        self.project.components.config
    )

    self.ota_install = tablex.deepcopy(self.project.components.ota_install)

    self.config["hostname"] = self.chip.name

    self.ready = true
end

function DeviceConfig:Timestamps()
    if self.__timestamps then --
        return self.__timestamps
    end

    print(self, "Preparing timestamps")
    local function process(lst)
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

                local entry = {
                    v,
                    sha256(file.read(v))
                }

                table.insert(content, table.concat(entry, ","))
            end
        end

        table.sort(content)
        local all_code = table.concat(content, "\n")

        return {
            timestamp = max,
            hash = md5(all_code)
        }
    end

    self.__timestamps = {
        lfs = process(self.lfs),
        root = process(self.root),
        config = json.decode(self:GenerateConfigFiles()[CONFIG_HASH_NAME])
    }
    return self.__timestamps
end

function DeviceConfig:GetConfigFileContent(name)
    local v = self.config[name]
    if not v then
        print("There is no config " .. name)
        return nil
    end
    if type(v) == "string" then
        return v
    else
        local r = table.encode_json_stable(v)
        json.decode(r)
        return r
    end
end

function DeviceConfig:GenerateConfigFiles()
    if self.generated_config then
        return self.generated_config
    end

    local r = {}
    local all_content = {}

    local keys = tablex.keys(self.config)
    table.sort(keys)
    for _, k in ipairs(keys) do
        local name = k .. ".cfg"
        local content = self:GetConfigFileContent(k)
        -- print("GENERATE-CONFIG:", name, content)
        r[name] = content
        table.insert(all_content, name .. "|" .. sha256(content))
    end

    table.sort(all_content)
    local c = table.concat(all_content, "\n")

    r[CONFIG_HASH_NAME] = json.encode({
        hash = md5(c),
        timestamp = os.time()
    })

    self.generated_config = r

    return r
end

function DeviceConfig:GenerateDynamicFiles(source, outStorage, list)
    for k, v in pairs(source) do
        local lines, code = shell.LinesOf("lua", nil, v)
        if not code then error("Command execution failed!") end
        local content = table.concat(lines, "\n")
        -- print("GENERATE", k, #content)
        table.insert(list, outStorage:AddFile(k, content))
    end

    local ts = self:Timestamps()
    local pretty_ts = pretty.write(ts.lfs)

    local timestamp_file = string.format([[return %s ]], pretty_ts)

   --  print("LFS-TIMESTAMP: \n---------------\n" .. timestamp_file .. "\n---------------")

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

function DeviceConfig:BuildLFS(luac)
    if not luac then error("LFS compiler is not available") end

    local generated_storage = require("fairy_node/tools/file-temp-storage").new()

    local fileList = {}
    local generateList = {}
    FilterFiles(self.lfs, fileList, generateList)
    self:GenerateDynamicFiles(generateList, generated_storage, fileList)
    GenerateFileLists(generated_storage, fileList)
    if not AssertFileUniqness(fileList) then
        error("Canot generate lfs if not all files are unique!")
    end

    -- print("Files in lfs: ", #fileList, table.concat(table.sorted(fileList), ","))
    -- print(pretty.write(table.sorted(fileList)))
    local result_file = generated_storage:AddFile("lfs.pending.img")
    local args = {
        "f",
        o = result_file,
        m = tostring(self:GetLfsSize()),
    }
    if not self.chip.debug then --
        table.insert(args, "s")
    end
    -- if not self.chip.integer then --
    --     table.insert(args, "f")
    -- end

    --
    shell.Start(luac, args, nil, table.unpack(fileList))

    local image = file.read(result_file)

    generated_storage:Clear()

    if not image or #image < 1024 then
        return nil
    end

    return image
end

function DeviceConfig:BuildRootImage()
    local fileList = {}
    for _, v in ipairs(self.root) do
        fileList[path.basename(v)] = file.read(v)
    end

    local ts = self:Timestamps()

    --  print(JSON.encode(ts.root))
    fileList["root-timestamp.lua"] = "return " .. pretty.write(ts.root)

    local files = table.keys(fileList)
    -- print("Files in root: ", #files, table.concat(files, ","))
    return file_image.Pack(fileList), file_image.VersionHash()
end

function DeviceConfig:BuildConfigImage()
    local fileList = self:GenerateConfigFiles()
    local files = table.keys(fileList)
    table.sort(files)
    -- print("Files in config: ", #files, table.concat(files, ","))
    return file_image.Pack(fileList), file_image.VersionHash()
end

function DeviceConfig:GetOtaInstallFiles()
    local fileList = { }
    for _, v in ipairs(self.ota_install) do
        fileList[path.basename(v)] = file.read(v)
    end
    return fileList
end

-------------------------------------------------------------------------------------

return DeviceConfig
