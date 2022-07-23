local lfs = require "lfs"
local json = require "json"
local file = require "pl.file"
local path = require "pl.path"
local pl_dir = require "pl.dir"
local fs = require "lib/fs"

-------------------------------------------------------------------------------

local CONFIG_KEY_SERVER_STORAGE_CACHE_PATH =  "module.server-storage.cache.path"
local CONFIG_KEY_SERVER_STORAGE_CACHE_TTL =   "module.server-storage.cache.ttl"
local CONFIG_KEY_SERVER_STORAGE_RWDATA_PATH = "module.server-storage.rw.path"
local CONFIG_KEY_SERVER_STORAGE_RODATA_PATH = "module.server-storage.ro.paths"
local CONFIG_KEY_LOG_PATH = "logger.path"

-------------------------------------------------------------------------------

local ServerStorage = {}
ServerStorage.__index = ServerStorage
ServerStorage.__deps = {
    sensor_handler = "base/sensors",
}
ServerStorage.__config = {
    [CONFIG_KEY_SERVER_STORAGE_CACHE_TTL] =   { type = "number", default = 86400 },
    [CONFIG_KEY_SERVER_STORAGE_CACHE_PATH] =  { type = "string", required = true },
    [CONFIG_KEY_SERVER_STORAGE_RWDATA_PATH] = { type = "string", required = true },
    [CONFIG_KEY_SERVER_STORAGE_RODATA_PATH] = { type = "string-table", default = { } },
    [CONFIG_KEY_LOG_PATH] = { type = "string", required = true },
}

-------------------------------------------------------------------------------

function ServerStorage:LogTag()
    return "ServerStorage"
end

function ServerStorage:BeforeReload() end

function ServerStorage:AfterReload()
    pl_dir.makepath(self:GetCachePath())
    pl_dir.makepath(self:GetStoragePath())
    self:InitSensors(self.sensor_handler)
end

function ServerStorage:Init() end

-------------------------------------------------------------------------------

function ServerStorage:GetCachePath()
    return self.config[CONFIG_KEY_SERVER_STORAGE_CACHE_PATH]
end

function ServerStorage:GetCacheTTL()
    return self.config[CONFIG_KEY_SERVER_STORAGE_CACHE_TTL]
end

function ServerStorage:CacheFilePath(id)
    return string.format("%s/%s",self:GetCachePath(), id)
end

function ServerStorage:UpdateCache(id, data)
    local r = SafeCall(function()
        if self.config.verbose then
            print(self, "Update cache:", id)
        end
        file.write(self:CacheFilePath(id), json.encode(data))
    end)
    if not r then print(self, "failed to write cache", id) end
end

function ServerStorage:AddCache(id, source_file)
    SafeCall(function()
        print(self, "Add cache:", id)
        file.copy(source_file, self:CacheFilePath(id))
        self:CheckCache()
    end)
end

function ServerStorage:GetCacheFilePath(id)
    local file_name = self:CacheFilePath(id)
    local attr = lfs.attributes(file_name)

    if (not attr) or attr.mode ~= "file" then
        print(self, "Not in cache:", id)
        return
    end

    return file_name
end

function ServerStorage:CacheFileExists(id)
    local attr = lfs.attributes(self:CacheFilePath(id))
    return attr and attr.mode == "file"
end

function ServerStorage:GetFromCache(id)
    local result
    SafeCall(function()
        local file_name = self:CacheFilePath(id)
        local attr = lfs.attributes(file_name)

        if (not attr) or attr.mode ~= "file" then
            if self.config.verbose then
                print(self, "Not in cache:", id)
            end
            return
        end

        if os.time() > attr.modification + self:GetCacheTTL() then
            print(self, "Cache entry expired:", id)
            os.remove(file_name)
            self:CheckCache()
            return
        end

        if self.config.verbose then
            print(self, "Cache get:", id)
        end

        lfs.touch(file_name)
        local data = file.read(file_name)

        result = json.decode(data)
    end)
    return result
end

function ServerStorage:CheckCache()
    local total_size = 0
    local entry_count = 0
    for file in lfs.dir(self:GetCachePath() .. "/") do
        if file ~= "." and file ~= ".." then
            local f = self:GetCachePath() .. '/' .. file
            local attr = lfs.attributes(f)
            if attr and attr.mode == "file" then
                if os.time() > attr.modification + self:GetCacheTTL() then
                    print(self, "Cache expired:", f)
                    os.remove(f)
                else
                    total_size = total_size + attr.size
                    entry_count = entry_count + 1
                end
            end
        end
    end
    if self.storage_sensor then
        self.storage_sensor:UpdateAll {
            cache_size = total_size / 1024,
            cache_entries = entry_count,
        }
    end
end

-------------------------------------------------------------------------------

function ServerStorage:GetStoragePath()
    return self.config[CONFIG_KEY_SERVER_STORAGE_RWDATA_PATH]
end

function ServerStorage:StorageFile(id)
    return string.format("%s/%s", self:GetStoragePath(), id)
end

function ServerStorage:AddFileToStorage(id, source_file)
    SafeCall(function()
        print(self, "Add file to storage:", id)
        file.copy(source_file, self:StorageFile(id))
        self:CheckStorage()
    end)
end

function ServerStorage:GetStoredFilePath(id)
    local file_name = self:StorageFile(id)
    local attr = lfs.attributes(file_name)

    if (not attr) or attr.mode ~= "file" then
        print(self, "Not in storage:", id)
        return
    end

    return file_name
end

function ServerStorage:GetFromStorage(id)
    local result
    SafeCall(function()
        local file_name = self:StorageFile(id)
        local attr = lfs.attributes(file_name)

        if (not attr) or attr.mode ~= "file" then
            print(self, "Not in storage:", id)
            return
        end

        print(self, "Storage get:", id)
        lfs.touch(file_name)
        result = file.read(file_name)
    end)
    return result
end

function ServerStorage:FindStorageFiles(regex)
    local result = { }
    regex = regex or ".*"
    for file in lfs.dir(self:GetStoragePath() .. "/") do
        if file ~= "." and file ~= ".." then
            local f = self:GetStoragePath() .. '/' .. file
            local attr = lfs.attributes(f)
            if attr and attr.mode == "file" then
                if not regex or file:match(regex) then
                    printf(self,"Looking entries with regex '%s' matched '%s'", regex, file)
                    table.insert(result, file)
                end
            end
        end
    end
    return result
end

function ServerStorage:StorageFileExists(id)
    local attr = lfs.attributes(self:StorageFile(id))
    return attr and attr.mode == "file"
end

function ServerStorage:WriteStorage(id, data)
    SafeCall(function()
        print(self, "Write storage:", id)
        file.write(self:StorageFile(id), tostring(data))
        self:CheckStorage()
    end)
end


function ServerStorage:CheckStorage()
    if self.storage_sensor then
        local r = fs.CountFilesInFolder(self:GetStoragePath())
        self.storage_sensor:UpdateAll {
            storage_size = r.size / 1024,
            storage_entries = r.count,
        }
    end
end

-------------------------------------------------------------------------------

function ServerStorage:GetRoFilePath(name)
    for _,base_path in ipairs(self.config[CONFIG_KEY_SERVER_STORAGE_RODATA_PATH]) do
        local full = base_path .. "/" .. name
        local att = lfs.attributes(full)
        if att ~= nil then
            return path.normpath(full)
        end
    end
    return nil
end

function ServerStorage:RoFileExists(name)
    return self:GetFilePath(name) ~= nil
end

-------------------------------------------------------------------------------

function ServerStorage:GetLogPath()
    return self.config[CONFIG_KEY_LOG_PATH]
end

function ServerStorage:CheckLogs()
    if self.storage_sensor then
        local r = fs.CountFilesInFolder(self:GetLogPath())
        self.storage_sensor:UpdateAll {
            log_size = r.size / 1024,
            log_entries = r.count,
        }
    end
end

-------------------------------------------------------------------------------

function ServerStorage:InitSensors(sensors)
    self.storage_sensor = sensors:RegisterSensor{
        owner = self,
        handler = self,
        name = "Server storage",
        id = "server_storage",
        nodes = {
            cache_size = { name = "Cache size", datatype = "float", unit = "KiB" },
            cache_entries = { name = "Cache entries", datatype = "integer" },

            storage_size = { name = "Storage size", datatype = "float", unit="KiB" },
            storage_entries = { name = "Storage entries", datatype = "integer" },

            log_size = { name = "Log size", datatype = "float", unit="KiB" },
            log_entries = { name = "Log entries", datatype = "integer" },
        }
    }
end

-------------------------------------------------------------------------------

function ServerStorage:SensorReadoutSlow()
    self:CheckCache()
    self:CheckStorage()
    self:CheckLogs()
end

-------------------------------------------------------------------------------

ServerStorage.EventTable = { }

-------------------------------------------------------------------------------

return ServerStorage
