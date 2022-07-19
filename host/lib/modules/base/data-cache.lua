local copas = require "copas"
local lfs = require "lfs"
local file = require "pl.file"
local json = require "json"

-------------------------------------------------------------------------------

local CONFIG_KEY_CACHE_PATH = "module.data.cache.path"
local CONFIG_KEY_CACHE_TTL = "module.data.cache.ttl"

-------------------------------------------------------------------------------

local Cache = {}
Cache.__index = Cache
Cache.__deps = {}
Cache.__config = {
    [CONFIG_KEY_CACHE_PATH] = { type = "string" },
    [CONFIG_KEY_CACHE_TTL] = { type = "number", default = 86400 },
}

-------------------------------------------------------------------------------

function Cache:LogTag()
    return "Data-Cache"
end

function Cache:BeforeReload() end

function Cache:AfterReload()
    os.execute("mkdir -p " .. self:GetPath())
end

function Cache:Init() end

function Cache:GetPath()
    return self.config[CONFIG_KEY_CACHE_PATH]
end

function Cache:GetTTL()
    return self.config[CONFIG_KEY_CACHE_TTL]
end

function Cache:CacheFile(id) return string.format("%s/%s",self:GetPath(), id) end

function Cache:UpdateCache(id, data)
    local r = SafeCall(function()
        -- print(self, "UPDATE CACHE:", id)
        file.write(self:CacheFile(id), json.encode(data))
    end)
    if not r then print(self, "FAILED TO WRITE CACHE " .. id) end
end

function Cache:AddFile(id, source_file)
    SafeCall(function()
        print(self, "Add file", id)
        file.copy(source_file, self:CacheFile(id))
        self:CheckCache()
    end)
end

function Cache:GetStoredPath(id)
    local file_name = self:CacheFile(id)
    local attr = lfs.attributes(file_name)

    if (not attr) or attr.mode ~= "file" then
        print(self, "NOT IN CACHE:", id)
        return
    end

    return file_name
end

function Cache:FileExists(id)
    local attr = lfs.attributes(self:CacheFile(id))
    return attr and attr.mode == "file"
end

function Cache:GetFromCache(id)
    local result
    SafeCall(function()
        local file_name = self:CacheFile(id)
        local attr = lfs.attributes(file_name)

        if (not attr) or attr.mode ~= "file" then
            if self.config.verbose then
                print(self, "NOT IN CACHE:", id)
            end
            return
        end

        if os.time() > attr.modification + self:GetTTL() then
            print(self, "CACHE EXPIRED:", id)
            os.remove(file_name)
            self:CheckCache()
            return
        end

        if self.config.verbose then
            print(self, "CACHE GET:", id)
        end

        lfs.touch(file_name)
        local data = file.read(file_name)

        result = json.decode(data)
    end)
    return result
end

function Cache:CheckCache()
    local total_size = 0
    local entry_count = 0
    for file in lfs.dir(self:GetPath() .. "/") do
        if file ~= "." and file ~= ".." then
            local f = self:GetPath() .. '/' .. file
            local attr = lfs.attributes(f)
            if attr and attr.mode == "file" then
                if os.time() > attr.modification + self:GetTTL() then
                    print(self, "CACHE EXPIRED:", f)
                    os.remove(f)
                else
                    total_size = total_size + attr.size
                    entry_count = entry_count + 1
                end
            end
        end
    end
    if self.homie_node then
        self.homie_node:SetValue("cache_size", string.format("%.1f", total_size / 1024))
        self.homie_node:SetValue("cache_entries", tostring(entry_count))
    end
end

function Cache:InitHomieNode(event)
    self.homie_node = event.client:AddNode("cache_control", {
        ready = true,
        name = "Server cache",
        properties = {
            cache_size = {name = "Cache size", datatype = "float", unit = "KiB"},
            cache_entries = {name = "Cache entries", datatype = "integer"},
        }
    })
end

Cache.EventTable = {
    ["homie-client.init-nodes"] = Cache.InitHomieNode,
    ["timer.basic.hour"] = Cache.CheckCache
}

return Cache
