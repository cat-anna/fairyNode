local json = require "rapidjson"
-- local tablex = require "pl.tablex"
local file = require "pl.file"
-- local pretty = require "pl.pretty"

-------------------------------------------------------------------------------

local M = {}

-------------------------------------------------------------------------------

local function SanitizeId(id)
    return id:gsub("([%- ])", "_")
end

-------------------------------------------------------------------------------

function M.ParseJsonOutput(text)
    local data = json.decode(text)
    if not data then
        print("Failed to parse sensors json output")
        return nil
    end

    local devices = { }

    for dev_k,dev_v in pairs(data) do
        local key = SanitizeId(dev_k)
        local name = dev_v.Adapter

        local values = { }

        for prop_k,prop_v in pairs(dev_v) do
            if type(prop_v) == "table" then
                for k,v in pairs(prop_v) do
                    local name = k:match("(.-)_input")
                    if name then
                        local id = SanitizeId(prop_k .. "_" .. name)
                        values[id] = v
                    end
                end
            end
        end

        table.insert(devices, {
            id = key,
            name = name,
            values = values,
            unit = "°C",
            datatype = "float",
        })
    end

    return devices
end

function M.ParseJsonFile(f)
    return M.ParseJsonOutput(file.read(f))
end

function M.GetCurrentReadings()
    local f = io.popen("sensors", "r")
    if not f then
        return
    end

    local output = f:read("*a")
    io.close(f)

    return M.ParseJsonOutput(output)
end

-------------------------------------------------------------------------------

return M
