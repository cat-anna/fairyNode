#!/usr/bin/lua

require("uuid").seed()
local path = require "pl.path"

local function GetArgs()
    local args = require ('pl.lapp') [[
FairyNode server entry
    -d,--debug                      Enter debug mode
    -v,--verbose                    Print more logs
    --argfile     (optional string) Load args from script and ignores all other args
    <packages...> (optional string) Packages to load
]]
    local r = {}
    if args.argfile then
        r = dofile(args.argfile)
    else
        r.packages = args.packages
    end
    r.debug = r.debug or args.debug
    r.verbose = r.verbose or args.verbose
    return r
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
        ["loader.module.list"] = args.modules,
        ["loader.config.list"] = args.config,

        -- ["loader.package.paths"] = { , },
        ["loader.package.list"] = args.packages,
    }
end

local base_path = path.abspath(path.normpath(path.dirname(arg[0]) .. "/../../"))
SetupPath(base_path)

require("fairy_node/stdlib")
require("fairy_node/logger"):Init()
SetupBaseArgs(base_path)

require("fairy_node/loader-package"):Init()
require("fairy_node/loader-class"):Init()
require("fairy_node/loader-module"):Init()
require("fairy_node/logger"):Start()

require("copas").loop()

print("== EXITING ==")
