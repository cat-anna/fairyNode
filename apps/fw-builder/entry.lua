#!/usr/bin/lua

require("uuid").seed()
local path = require "pl.path"

local function GetArgs()
    local args = require ('pl.lapp') [[
fairyNode firmware builder
    -d,--debug                         Enter debug mode
    -v,--verbose                       Print more logs

    --nodemcu_path (string)   Nodemcu fw path

    --host (default localhost:8080)    fairyNode host

    --device_port (optional string)    TODO
    --device      (optional string)    TODO
    --all_devices
    --rebuild                          TODO
    --package (optional string)        TODO

    --activate                         TODO
    --trigger_ota                      TODO
]]

    if args.device then
        args.device = string.split(args.device, ",")
    end

    if args.trigger_ota then
        args.activate = true
    end

    -- local r = {}
    -- if args.argfile then
    --     r = dofile(args.argfile)
    -- else
    --     r.packages = args.packages
    -- end
    -- r.debug = r.debug or args.debug
    -- r.verbose = r.verbose or args.verbose
    return args
end

local function SetupPath(base)
    local lib_path = base .. "/src"

    package.path = table.concat({
        package.path,
        "/usr/lib/lua/?.lua",
        "/usr/lib/lua/?/init.lua",
        lib_path .. "/?.lua",
        lib_path .. "/?/init.lua",
    }, ';')
end

local function SetupBaseArgs(base_path)
    local args = GetArgs()
    require("fairy_node/config-handler"):SetBaseConfig{
        debug = args.debug,
        verbose = args.verbose,
        ["path.fairy_node"] = base_path,
        ["loader.package.list"] = string.split(args.package, ","),
        ["loader.module.list"] = {
            "fairy_node-builder",
        },

        ["module.fairy_node-builder.host"] = args.host,
        ["module.fairy_node-builder.rebuild"] = args.rebuild,
        ["module.fairy_node-builder.device_port"] = args.device_port,
        ["module.fairy_node-builder.device"] = args.device,
        ["module.fairy_node-builder.all_devices"] = args.all_devices,
        ["module.fairy_node-builder.nodemcu_path"] = args.nodemcu_path,

        ["module.fairy_node-builder.trigger_ota"] = args.trigger_ota,
        ["module.fairy_node-builder.activate"] = args.activate,

        ["module.fairy_node-builder.firmware_path"] = {
            path.normpath(base_path .. "/firmware/src"),
        },
        ["module.fairy_node-builder.project_paths"] = {
            path.normpath(base_path .. "/firmware/config"),
        },

    --     ["loader.config.list"] = args.config,
    --     ["loader.package.paths"] = { , },
    }
end

local base_path = path.abspath(path.normpath(path.dirname(arg[0]) .. "/../../"))
SetupPath(base_path)

function assert(v, message, ...)
    if v then
        return
    end
    print(message or "ASSERT!")
    print(debug.traceback())
    os.exit(1)
end

require("fairy_node/stdlib")
require("fairy_node/logger"):Init()
SetupBaseArgs(base_path)

require("fairy_node/loader-package"):Init()
require("fairy_node/loader-class"):Init()
require("fairy_node/loader-module"):Init()
require("fairy_node/logger"):Start()

require("copas").loop()

print("== EXITING ==")
