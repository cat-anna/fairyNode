
local path = require "pl.path"
local config_handler = require "lib/config-handler"

-------------------------------------------------------------------------------

local DefaultPackageFile = "fairy-node-package.lua"

-------------------------------------------------------------------------------

local PackageLoader = { }
PackageLoader.__index = PackageLoader

function PackageLoader:Load(input_path)
    -- TODO

    local package_file
    local base_path
    if path.isfile(input_path) then
        package_file = input_path
        base_path = path.dirname(input_path)
    elseif path.isdir(input_path) then
        base_path = input_path
        package_file = input_path .. "/" .. DefaultPackageFile
    else
        assert(false)
    end


    local p = dofile(package_file)
    print("PACKAGE: Loading " .. p.Name .. " from " .. base_path)

    config_handler:SetPackageConfig(p.Name, p.GetConfig(base_path))
end

-------------------------------------------------------------------------------

return setmetatable({}, PackageLoader)
