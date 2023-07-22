#!/usr/bin/lua

package.path = package.path .. ";/usr/lib/lua/?.lua;/usr/lib/lua/?/init.lua"
local path = require "pl.path"
local copas = require "copas"

require("uuid").seed()

local fairy_node_base = path.abspath(path.normpath(path.dirname(arg[0]) .. "/.."))
package.path = package.path .. ";" ..
            fairy_node_base .. "/host/?.lua" .. ";" ..
            fairy_node_base .. "/host/?/init.lua"

require("lib/ext")
require("lib/logger"):Init()
require("lib/setup-alternatives")

local args = require('pl.lapp')([[
fairyNode firmware builder
    -d,--debug                         Enter debug mode
    -v,--verbose                       Print more logs

    --package (string)                 TODO

    --nodemcu_firmware_path (string)   Nodemcu fw path

    --host (default localhost:8000)    fairyNode host

    --device (optional string)         TODO
    --rebuild                          TODO
    --port (optional string)           TODO
]])

local config_handler = require "lib/config-handler"
config_handler:SetBaseConfig{
    debug = false,
    verbose = false,
    ["path.fairy_node"] = fairy_node_base,
    ["loader.package.list"] = {
        fairy_node_base .. "/host/apps/fairy-node-fw-builder.lua"
    },
}

local function SplitArg(v, c)
    if v then
        return v:split(c)
    end
end

config_handler:SetCommandLineArgs{
    debug = args.debug,
    verbose = args.verbose,
    ["loader.config.list"] = { },-- args.config:split(","),
    ["loader.package.list"] = { args.package },
    ["fw-builder.config"] = {
        device = SplitArg(args.device, ","),
        port = SplitArg(args.port, ":"),
        nodemcu_firmware_path = args.nodemcu_firmware_path,
        host = args.host,
        rebuild = args.rebuild,
    },
    ["project.source.path"] = { fairy_node_base .. "/../DeviceConfig/projects/" },
}

require("lib/loader-package"):Init()
require("lib/loader-module"):Init()
require("lib/loader-class"):Init()
require("lib/logger"):Start()

copas.loop()
