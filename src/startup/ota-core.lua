local TOKEN_FILE_NAME = "ota.ready"
local LFS_PENDING_FILE = "lfs.pending.img"
local ROOT_PENDING_FILE = "root.pending.img"
local CONFIG_PENDING_FILE = "config.pending.img"

local function makeRestRequestUrl(command)
    return string.format("/ota/%06X/%s", node.chipid(), command)
end

local function PackageCleanup()
    package.loaded["ota-http"] = nil
    package.loaded["ota-core"] = nil
    package.loaded["ota-check"] = nil
    package.loaded["ota-installer"] = nil
    package.loaded["sys-config"] = nil
end

local OtaCoreMt = {}
OtaCoreMt.__index = OtaCoreMt

function OtaCoreMt.New() return setmetatable({}, OtaCoreMt) end

function OtaCoreMt:AddDownload(file_name, request)
    if file.exists(file_name) then file.remove(file_name) end
    self.http_handler:AddRequest({
        request = makeRestRequestUrl(request),
        target_file = file_name
    })
end

function OtaCoreMt:DownloadCompleted(result)
    if not result then
        print("OTA: Download failed")
        PackageCleanup()
        return
    end

    print("OTA: Download completed")
    self.http_handler = nil
    wifi.setmode(wifi.NULLMODE)

    local token = file.open(TOKEN_FILE_NAME, "w")
    token:write("1")
    token:close()

    print "OTA: Restarting..."
    node.task.post(node.restart)
end

function OtaCoreMt:BeginUpdate()
    print("OTA: Starting download...")

    if cron then cron.reset() end
    if Event then Event("ota.start") end

    if file.exists(TOKEN_FILE_NAME) then file.remove(TOKEN_FILE_NAME) end

    self.http_handler:SetFinishedCallback(function(r) self:DownloadCompleted(r) end)
    node.task.post(function()
        PackageCleanup()
        self.http_handler:Start()
    end)
end

function OtaCoreMt:CheckWhatToUpdate(update_info)
    local any_download = false

    if update_info.lfs then
        print("OTA: LFS update is needed")
        self:AddDownload(LFS_PENDING_FILE, "lfs_image")
        any_download = true
    end

    if update_info.root then
        print("OTA: ROOT update is needed")
        self:AddDownload(ROOT_PENDING_FILE, "root_image")
        any_download = true
    end

    if update_info.config then
        print("OTA: CONFIG update is needed")
        self:AddDownload(CONFIG_PENDING_FILE, "config_image")
        any_download = true
    end

    if not any_download then
        print("OTA: Nothing to update")
        return false
    end

    return true
end

function OtaCoreMt:Prepare(update_info)
    if update_info then
        local ota_cfg = require("sys-config").JSON("rest.cfg")
        if not ota_cfg then error("OTA: No config file") end
        self.http_handler = require("ota-http").New(ota_cfg.host, ota_cfg.port)
        PackageCleanup()
        if self:CheckWhatToUpdate(update_info) then
            self:BeginUpdate()
        end
    end
    PackageCleanup()
end

function OtaCoreMt:Check(forced_mode)
    if file.exists(TOKEN_FILE_NAME) and file.exists(ROOT_PENDING_FILE) then
        print("OTA: Root update is pending.")
        node.task.post(function() require("ota-installer").Install() end)
        return
    end

    if forced_mode then
        self:Prepare({lfs = true, root = true, config = true})
    else
        require("ota-check").Check(function(r) self:Prepare(r) end)
    end
end

return {
    Check = function(forced_mode)
        node.task.post(function() OtaCoreMt.New():Check(forced_mode) end)
    end
}
