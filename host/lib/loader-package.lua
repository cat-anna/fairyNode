
local config_handler = require "lib/config-handler"

-------------------------------------------------------------------------------

local PackageLoader = { }
PackageLoader.__index = PackageLoader

function PackageLoader:Load(base_path)
    -- TODO
    local p = dofile(base_path .. "/fairy-node-package.lua")
    print("PACKAGE: Loading " .. p.Name .. " from " .. base_path)

    config_handler:SetPackageConfig(p.Name, p.GetConfig(base_path))
end

-------------------------------------------------------------------------------

return setmetatable({}, PackageLoader)
