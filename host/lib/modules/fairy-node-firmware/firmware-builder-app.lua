
local json = require "json"
-- local tablex = require "pl.tablex"
-- local file = require "pl.file"
-- local shell = require "lib/shell"
local scheduler = require "lib/scheduler"
local loader_class = require "lib/loader-class"
local copas = require "copas"

-------------------------------------------------------------------------------------

local CONFIG_KEY_CONFIG = "fw-builder.config"

local FirmwareBuilderApp = {}
FirmwareBuilderApp.__index = FirmwareBuilderApp
FirmwareBuilderApp.__type = "module"
FirmwareBuilderApp.__deps = {}
FirmwareBuilderApp.__config = {
    [CONFIG_KEY_CONFIG] = { type = "table", },
}

-------------------------------------------------------------------------------------

function FirmwareBuilderApp:Tag()
    return "FirmwareBuilderApp"
end

-------------------------------------------------------------------------------------

function FirmwareBuilderApp:Init() end

function FirmwareBuilderApp:StartModule()
    local config = self.config[CONFIG_KEY_CONFIG]

    self.compiler = {}

    -- local project_lib = require "lib/modules/fairy-node-firmware/project"
    -- local all_devs = project_lib:ListDeviceIds()

    self.host_client = require("lib.http-client").New()
    self.host_client:SetHost(config.host)

    if config.port then
        --TODO
    elseif config.device then
        self:CreateBuilder(config.device)
    else
        for i,v in ipairs(self:GetOtaDevices()) do
            self:CreateBuilder(v)
        end
    end
end

function FirmwareBuilderApp:CreateBuilder(dev_id)
    local config = self.config[CONFIG_KEY_CONFIG]
    loader_class:CreateObject("fairy-node-firmware/firmware-builder", {
        owner = self,
        host_client = self.host_client,
        dev_id = dev_id,
        rebuild = config.rebuild,
    })
end

-------------------------------------------------------------------------------------

function FirmwareBuilderApp:QueryDeviceStatus(device_id)
    return self.host_client:GetJson(string.format("ota/%s/status", device_id:upper()))
end

function FirmwareBuilderApp:GetOtaDevices()
    return self.host_client:GetJson("ota/list")
end

function FirmwareBuilderApp:UploadImage(request)
    local url_base = string.format("ota/%s", request.device_id:upper())
    local req = self.host_client:PostJson(url_base .. "/update/prepare", {
        image = request.image,
        timestamp = request.timestamp,
        payload_hash = request.payload_hash,
        payload_size = #request.payload,
    })

    local req = self.host_client:Post({
        url = url_base .. "/update/upload/" .. req.key,
        body = request.payload,
        mime_type = "text/plain",
    })
end

-------------------------------------------------------------------------------------

function FirmwareBuilderApp:PrepareCompiler(worker, dev_info, device_id)
    local config = self.config[CONFIG_KEY_CONFIG]
    local git_commit_id = dev_info.nodeMcu.git_commit_id
    assert(git_commit_id)

    if not self.compiler[git_commit_id] then
        local c = {
            pending = { },
        }
        self.compiler[git_commit_id] = c

        c.builder = loader_class:CreateObject("fairy-node-firmware/luac-builder", {
            nodemcu_firmware_path = config.nodemcu_firmware_path,
            git_commit_id = git_commit_id,
            callback = function(...) self:CompilerReady(c, ...) end
        })
    end

    local compiler = self.compiler[git_commit_id]

    table.insert(compiler.pending, (coroutine.running()))

    while compiler.pending do
        print(worker, "Waiting for compiler git_commit_id=" .. git_commit_id)
        copas.sleep(10)
    end

    assert(compiler.exec_path)
    return compiler.exec_path
end

function FirmwareBuilderApp:CompilerReady(compiler, object, path)
    print(self, "Compiler ready:", path)
    assert(path)
    compiler.exec_path = path

    for _,v in ipairs(compiler.pending) do
        copas.wakeup(v)
    end
    compiler.pending = nil
end

-------------------------------------------------------------------------------------

return FirmwareBuilderApp
