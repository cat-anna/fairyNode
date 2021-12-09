local http = require "lib/http-code"
local copas = require "copas"
local file = require "pl.file"
local path = require "pl.path"

local ServiceFile = {}
ServiceFile.__index = ServiceFile
ServiceFile.__deps = {
}

local FileSearchPaths = {
    "./files",
    "../fairyNode/host/web",
}

local MimeTypes = {
    [".json"] = "application/json",
    [".html"] = "text/html",
    [".css"] = 	"text/css",
}
local function DetectMimeType(fn)
    local base
    local ext
    base, ext = path.splitext(fn)
    return MimeTypes[ext] or "text/plain"
end

function ServiceFile:LogTag()
    return "ServiceFile"
end

function ServiceFile:GetFile(request, fname)
    local file_path
    for _,v in ipairs(FileSearchPaths) do
        local full_path = path.normpath(v .. "/" .. fname)
        if path.isfile(full_path) then
            file_path = full_path
            break
        end
    end

    if file_path then
        local data = file.read(file_path)
        local mime = DetectMimeType(file_path)
        print("FILE: " .. file_path .. " size: " .. tostring(#data) .. " mime: " .. mime)
        return http.OK, data, mime
    else
        print("FILE: " .. fname .. " not found")
        return http.NotFound
    end
end

function ServiceFile:BeforeReload()
end

function ServiceFile:AfterReload()
end

function ServiceFile:Init()
end

return ServiceFile
