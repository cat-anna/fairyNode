local copas = require "copas"
local lfs = require "lfs"
local file = require "pl.file"
local json = require "json"
local configuration = require("configuration")

local Storage = {}
Storage.__index = Storage
Storage.__deps = { }

if not configuration.path.storage then
    Storage.__disable = true
    return Storage
end

-------------------------------------------------------------------------------

function Storage:LogTag()
    return "Storage"
end

function Storage:BeforeReload()
end

function Storage:AfterReload()
    self.storage_path = configuration.path.storage
    os.execute("mkdir -p " .. self.storage_path)
end

function Storage:Init()
end

function Storage:StorageFile(id)
    return string.format("%s/%s", self.storage_path, id)
end

function Storage:WriteStorage(id, data)
    SafeCall(function()
        print("STORAGE: write", id)
        file.write(self:StorageFile(id), tostring(data))
        self:CheckStorage()
    end)
end

function Storage:AddFile(id, source_file)
    SafeCall(function()
        print("STORAGE: add file", id)
        file.copy(source_file, self:StorageFile(id))
        self:CheckStorage()
    end)
end

function Storage:GetStoredPath(id)
    local file_name = self:StorageFile(id)
    local attr = lfs.attributes(file_name)

    if (not attr) or attr.mode ~= "file" then
        print("NOT IN STORAGE:", id)
        return
    end

    return file_name
end

function Storage:FileExists(id)
    local attr = lfs.attributes(self:StorageFile(id))
    return attr and attr.mode == "file"
end

function Storage:GetFromStorage(id)
    local result
    SafeCall(function()
        local file_name = self:StorageFile(id)
        local attr = lfs.attributes(file_name)

        if (not attr) or attr.mode ~= "file" then
            print("NOT IN STORAGE:", id)
            return
        end

        print("STORAGE GET:", id)
        lfs.touch(file_name)
        result = file.read(file_name)
    end)
    return result
end

function Storage:CheckStorage()
    local total_size = 0
    local entry_count = 0
    for file in lfs.dir(self.storage_path .. "/") do
        if file ~= "." and file ~= ".." then
            local f = self.storage_path .. '/' .. file
            local attr = lfs.attributes(f)
            if attr and attr.mode == "file" then
                total_size = total_size + attr.size
                entry_count = entry_count + 1
            end
        end
    end
    if self.homie_node then
        self.homie_node:SetValue("storage_size", string.format("%.1f", total_size / 1024))
        self.homie_node:SetValue("storage_entries", tostring(entry_count))
    end
end

function Storage:SetNodeValue(topic, payload, node_name, prop_name, value)
    print("STORAGE: config changed: ", self.configuration[prop_name], "->", value)
    self.configuration[prop_name] = value
    self:CheckStorage()
end

function Storage:InitHomieNode(event)
    self.homie_node = event.client:AddNode("storage_control", {
        ready = true,
        name = "Server storage",
        properties = {
            storage_size = { name = "Storage size", datatype = "float", unit="KiB" },
            storage_entries = { name = "Storage entries", datatype = "integer" },
        }
    })
end

function Storage:ListEntries(regex)
    local result = { }
    regex = regex or ".*"
    for file in lfs.dir(self.storage_path .. "/") do
        if file ~= "." and file ~= ".." then
            local f = self.storage_path .. '/' .. file
            local attr = lfs.attributes(f)
            if attr and attr.mode == "file" then
                if not regex or file:match(regex) then
                    print(string.format("STORAGE: Looking entries with regex '%s' matched '%s'", regex, file))
                    table.insert(result, file)
                end
            end
        end
    end
    return result
end

Storage.EventTable = {
    ["homie-client.init-nodes"] = Storage.InitHomieNode,
    ["homie-client.ready"] = Storage.CheckStorage,
    ["timer.sensor.read.slow"] = Storage.CheckStorage
}

return Storage
