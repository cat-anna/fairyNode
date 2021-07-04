local http = require "lib/http-code"
local copas = require "copas"
local file = require "pl.file"
local pretty = require 'pl.pretty'

local ServiceOta = {}
ServiceOta.__index = ServiceOta
ServiceOta.Deps = {
    project = "project",
    device = "device"
}

function ServiceOta:LogTag()
    return "ServiceOta"
end

--[[
function ServiceOta:ListDevices(request)
   local conf = self.chip.LoadConfig()

   local r = { }

   for k,v in pairs(conf.chipid) do
      local cfg = { }
      r[k] = cfg
      cfg.ota = not v.ota.disabled
      cfg.name = v.name
      cfg.project = v.project
   end

    return http.OK, r
end
]]

function ServiceOta:OtaStatus(request, id)
    if not self.project:ProjectExists(id) then
        print(self:LogTag() .. ": Unknown chip: " .. id)
        return http.NotFound
    end

    local project = self.project:LoadProject(id)
    print(self:LogTag() .. ": " .. id .. " is " .. project.name)

    local ts = project:CalcTimestamps()
    print(self:LogTag() .. ": Timestamps = " .. pretty.write(ts))

    ts.enabled = not project.ota.disabled
    return http.OK, ts
end

function ServiceOta:LfsImagePost(request, id)
    return self:LfsImage(request, id)
end

function ServiceOta:LfsImage(request, id)
    if not self.project:ProjectExists(id) then
        print(self:LogTag() .. ": Unknown chip: " .. id)
        return http.NotFound
    end

    local fw_commit_hash
    if request and request.git_commit_id then
        fw_commit_hash = request.git_commit_id
        print(self:LogTag() .. ": Using commit hash from request: " .. fw_commit_hash)
    end

    if not fw_commit_hash then
        local device = self.device:FindDeviceById(id)
        if device then
            fw_commit_hash = device.variables["fw/NodeMcu/git_commit_id"]
        end
        print(self:LogTag() .. ": Using commit hash from mqtt: " .. fw_commit_hash)
    end

    if not fw_commit_hash then
        print(self:LogTag() .. ": No commit hash provided")
    end

    local project = self.project:LoadProject(id)
    print(self:LogTag() .. ": " .. id .. " is " .. project.name .. "  OTA stamp: ", project.lfsStamp)

    local storage = require("lib/file_storage").new()
    project:BuildLFS(storage, fw_commit_hash)

    if #storage.list ~= 1 then
        print("CompileLFS produced incorrect count of files")
        return http.InternalServerError
    end

    local data = file.read(storage.list[1])
    print("Compiled size: ", #data)

    storage:Clear()

    return http.OK, data, "application/octet-stream"
end

function ServiceOta:RootImage(request, id)
    if not self.project:ProjectExists(id) then
        print(self:LogTag() .. ": Unknown chip: " .. id)
        return http.NotFound
    end

    local project = self.project:LoadProject(id)
    print(self:LogTag() .. ": " .. id .. " is " .. project.name .. "  OTA stamp: ", project.lfsStamp)

    local image = project:BuildRootImage()

    if not image then
        print("Compile Root failed")
        return http.InternalServerError
    end

    return http.OK, image, "application/octet-stream"
end

function ServiceOta:ConfigImage(request, id)
    if not self.project:ProjectExists(id) then
        print(self:LogTag() .. ": Unknown chip: " .. id)
        return http.NotFound
    end

    local project = self.project:LoadProject(id)
    print(self:LogTag() .. ": " .. id .. " is " .. project.name .. "  OTA stamp: ", project.lfsStamp)

    local image = project:BuildConfigImage()

    if not image then
        print("Compile Config failed")
        return http.InternalServerError
    end

    return http.OK, image, "application/octet-stream"
end

function ServiceOta:OtaDevices()
    return http.OK, self.project:ListDeviceIds()
end

function ServiceOta:BeforeReload()
end

function ServiceOta:AfterReload()
end

function ServiceOta:Init()
end

return ServiceOta
