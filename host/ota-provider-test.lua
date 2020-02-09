#!/usr/bin/lua
local lapp = require 'pl.lapp'
local path = require "pl.path"
local file = require "pl.file"
local dir = require "pl.dir"
local json = require "json"
local copas = require "copas"
local asynchttp = require("copas.http").request

local fairy_node_base = path.abspath(path.normpath(path.dirname(arg[0]) .. "/.."))
package.path = package.path .. ";" .. fairy_node_base .. "/host/?.lua" .. ";" .. fairy_node_base .. "/host/?/init.lua"

local shell = require "lib/shell"
local file_image = require "lib/file-image"
local JSON = require "json"

-- local args = lapp [[
-- Upload software using serial
-- ]]

local cfg = {
    host = "localhost:8000",
}

local downloads = { }

local MakeQuerry

MakeQuerry = function(chipid, what)
    local url = "http://" .. cfg.host .. "/ota/" .. chipid .. "/" .. what
    res, err = asynchttp(url)
    if err ~= 200 then
        print("Failed to query " .. url)
        print("RESPONSE: ", res)
        copas.sleep(5)
        copas.addthread(MakeQuerry, chipid, what)
        return
    end
    print("Got response from " .. url .. " " .. tostring(res:len()) .. " bytes")
end

local function QuerryDeviceList()
    local url = "http://" .. cfg.host .. "/ota/devices"
    res, err = asynchttp(url)
    if err ~= 200 then
        print("Failed to query " .. url)
        print("RESPONSE: ", res)
        os.exit(1)
    end
    print("Got response from " .. url .. " " .. tostring(res:len()) .. " bytes")
    local devices = JSON.decode(res)
    for _,v in ipairs(devices) do
        copas.addthread(MakeQuerry, v, "config_image")
        copas.addthread(MakeQuerry, v, "root_image")
        copas.addthread(MakeQuerry, v, "lfs_image")
    end
end

copas.addthread(QuerryDeviceList)

copas.loop()

print "Done"
