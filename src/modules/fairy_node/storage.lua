local lfs = require "lfs"
local json = require "dkjson"
local file = require "pl.file"
local path = require "pl.path"
local pl_dir = require "pl.dir"
local fs = require "fairy_node/fs"

-------------------------------------------------------------------------------

local Storage = {}
Storage.__tag = "Storage"
Storage.__deps = { }

-------------------------------------------------------------------------------

function Storage:BeforeReload() end

function Storage:AfterReload()
    if self.config.debug then
        self.json_args = { indent = true }
    else
        self.json_args = nil
    end
    pl_dir.makepath(self:GetCachePath())
    pl_dir.makepath(self:GetStoragePath())
end

function Storage:Init(opt)
    Storage.super.Init(self, opt)
end

-------------------------------------------------------------------------------

function Storage:GetCachePath()
    return self.config.storage_cache_path
end

function Storage:GetCacheTTL()
    return self.config.storage_cache_ttl
end

function Storage:CacheFilePath(id)
    return string.format("%s/%s",self:GetCachePath(), id)
end

function Storage:UpdateCache(id, data)
    local r = SafeCall(function()
        if self.config.verbose then
            print(self, "Update cache:", id)
        end
        file.write(self:CacheFilePath(id), json.encode(data, self.json_args))
    end)
    if not r then print(self, "failed to write cache", id) end
end

function Storage:AddCache(id, source_file)
    SafeCall(function()
        print(self, "Add cache:", id)
        file.copy(source_file, self:CacheFilePath(id))
    end)
end

function Storage:GetCacheFilePath(id)
    local file_name = self:CacheFilePath(id)
    local attr = lfs.attributes(file_name)

    if (not attr) or attr.mode ~= "file" then
        print(self, "Not in cache:", id)
        return
    end

    return file_name
end

function Storage:CacheFileExists(id)
    local attr = lfs.attributes(self:CacheFilePath(id))
    return attr and attr.mode == "file"
end

function Storage:GetFromCache(id)
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

function Storage:CheckCache()
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
        self.storage_sensor:UpdateValues {
            cache_size = total_size / 1024,
            cache_entries = entry_count,
        }
    end
end

-------------------------------------------------------------------------------

function Storage:GetStoragePath()
    return self.config.storage_rwdata_path
end

function Storage:StorageFile(id)
    return string.format("%s/%s", self:GetStoragePath(), id)
end

function Storage:AddFileToStorage(id, source_file)
    SafeCall(function()
        print(self, "Add file to storage:", id)
        file.copy(source_file, self:StorageFile(id))
    end)
end

function Storage:GetStoredFilePath(id)
    local file_name = self:StorageFile(id)
    local attr = lfs.attributes(file_name)

    if (not attr) or attr.mode ~= "file" then
        print(self, "Not in storage:", id)
        return
    end

    return file_name
end

function Storage:GetObjectFromStorage(id)
    local r = self:GetFromStorage(id)
    if r then
        return json.decode(r)
    end
end

function Storage:GetFromStorage(id)
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

function Storage:FindStorageFiles(regex)
    local result = { }
    regex = regex or ".*"
    for file in lfs.dir(self:GetStoragePath() .. "/") do
        if file ~= "." and file ~= ".." then
            local f = self:GetStoragePath() .. '/' .. file
            local attr = lfs.attributes(f)
            if attr and attr.mode == "file" then
                if not regex or file:match(regex) then
                    -- printf(self, "Looking entries with regex '%s' matched '%s'", regex, file)
                    table.insert(result, file)
                end
            end
        end
    end
    return result
end

function Storage:StorageFileExists(id)
    local attr = lfs.attributes(self:StorageFile(id))
    return attr and attr.mode == "file"
end

function Storage:WriteStorage(id, data)
    SafeCall(function()
        print(self, "Write storage:", id)
        file.write(self:StorageFile(id), tostring(data))
    end)
end

function Storage:RemoveFromStorage(id)
    SafeCall(function()
        print(self, "Remove from storage:", id)
        os.remove(self:StorageFile(id))
    end)
end

function Storage:WriteObjectToStorage(id, data)
    return self:WriteStorage(id, json.encode(data, self.json_args))
end

function Storage:CheckStorage()
    if self.storage_sensor then
        local r = fs.CountFilesInFolder(self:GetStoragePath())
        self.storage_sensor:UpdateValues {
            storage_size = r.size / 1024,
            storage_entries = r.count,
        }
    end
end

-------------------------------------------------------------------------------

function Storage:GetRoFilePath(name)
    for _,base_path in ipairs(self.config.storage_rodata_path) do
        local full = base_path .. "/" .. name
        local att = lfs.attributes(full)
        if att ~= nil then
            return path.normpath(full)
        end
    end
    return nil
end

function Storage:RoFileExists(name)
    return self:GetFilePath(name) ~= nil
end

-------------------------------------------------------------------------------

function Storage:GetLogPath()
    return self.config.logger_path
end

function Storage:CheckLogs()
    if self.storage_sensor then
        local r = fs.CountFilesInFolder(self:GetLogPath())
        self.storage_sensor:UpdateValues {
            log_size = r.size / 1024,
            log_entries = r.count,
        }
    end
end

-------------------------------------------------------------------------------

function Storage:InitProperties(manager)
    self.storage_sensor = manager:RegisterSensor{
        owner = self,
        proxy = true,
        name = "Server storage",
        id = "server_storage",
        values = {
            cache_size = { name = "Cache size", datatype = "float", unit = "KiB" },
            cache_entries = { name = "Cache entries", datatype = "integer" },

            storage_size = { name = "Storage size", datatype = "float", unit = "KiB" },
            storage_entries = { name = "Storage entries", datatype = "integer" },

            log_size = { name = "Log size", datatype = "float", unit = "KiB" },
            log_entries = { name = "Log entries", datatype = "integer" },
        }
    }
end

-------------------------------------------------------------------------------

function Storage:SensorReadoutSlow()
    self:CheckCache()
    self:CheckStorage()
    self:CheckLogs()
end

-------------------------------------------------------------------------------

return Storage
