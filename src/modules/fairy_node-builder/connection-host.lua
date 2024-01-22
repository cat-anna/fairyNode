local http = require "fairy_node/http-code"

-------------------------------------------------------------------------------------

local HostConnection = { }
HostConnection.__type = "class"
HostConnection.__name = "HostConnection"
HostConnection.__deps = { }

-------------------------------------------------------------------------------------

function HostConnection:Tag()
    return string.format("HostConnection(%s)", self.host)
end

function HostConnection:Init(config)
    HostConnection.super.Init(self, config)
    -- self.database = config.database
    self.host = config.host

    self.host_client = require("fairy_node.http-client").New()
    self.host_client:SetHost(self.host)
end

function HostConnection:PostInit()
end

-------------------------------------------------------------------------------------

-- function FirmwareBuilderApp:CheckOtaStorage()
--     assert(false)
--     -- self.host_client:GetJson("ota/storage/check")
-- end

function HostConnection:QueryDeviceStatus(chip_id)
    return self.host_client:GetJson(string.format("api/firmware/device/%s/status", chip_id:upper()))
end

function HostConnection:GetOtaDevices()
    return self.host_client:GetJson("api/firmware/device")
end

function HostConnection:UploadImage(request)
    local prepare, prep_code = self.host_client:PostJson("api/firmware/image/upload/request", {
        image = request.image,
        timestamp = request.timestamp,
        hash = request.payload_hash,
        size = #request.payload,
        compiler_id = request.compiler_id,
    })

    if prep_code == http.Conflict then
        print(self, "Upload rejected, image already exists")
        return true
    end

    if not prepare then
        return false
    end

    local req, req_code = self.host_client:Post({
        url = "api/firmware/image/upload/content/" .. prepare.key,
        body = request.payload,
        mime_type = "text/plain",
    })

    return req_code == http.OK
end

function HostConnection:CommitFwSet(dev_id, fw_set)
    local url_base = string.format("api/firmware/device/%s", dev_id:upper())
    local req = self.host_client:PostJson(url_base .. "/commit", {
        device_id = dev_id,
        set = fw_set,
        timestamp = os.timestamp(),
    })
end

-------------------------------------------------------------------------------------

return HostConnection
