-- local TOKEN_FILE_NAME = "ota.ready"
-- local LFS_PENDING_FILE = "lfs.pending.img"
-- local ROOT_PENDING_FILE = "root.pending.img"
-- local CONFIG_PENDING_FILE = "config.pending.img"

local function makeRestRequestUrl(command)
    return string.format("/ota/%06X/%s", node.chipid(), command)
end

local OtaCheck = {}
OtaCheck.__index = OtaCheck

local function LoadTimestamps()
    local r = {}

    local loaded, lfs_stamp = pcall(require, "lfs-timestamp")
    if loaded then if type(lfs_stamp) == "table" then r.lfs = lfs_stamp end end
    package.loaded["lfs-timestamp"]=nil

    loaded, root_stamp = pcall(require, "root-timestamp")
    if loaded then r.root = root_stamp end
    package.loaded["root-timestamp"]=nil

    if file.exists("config_hash.cfg") then
        r.config = require("sys-config").JSON("config_hash.cfg")
    end

    -- print("OTA: My timestamps: ", sjson.encode(r))
    return r
end

local function CheckOtaStatus(cb, data)
    if not data then
        print("OTA: Failed to get remote status")
        node.task.post(function() pcall(cb, nil) end)
        return
    end

    print("OTA: Remote status:" .. data)

    local succ, update_info = pcall(sjson.decode, data)
    if not succ then
        print("OTA: Failed to parse status json:" .. tostring(data))
        return
    end

    node.task.post(function() pcall(cb, update_info) end)
end

local function GetStatusPayload()
    local r = {
        failsafe = failsafe,
        device = {
            chip_id = string.format("%06X", node.chipid()),
            lfs_size = node.info("lfs").lfs_size,
        },
        fairyNode = LoadTimestamps(),
        nodeMcu = {
            git_commit_id = node.info("sw_version").git_commit_id
        }
    }
    local result = sjson.encode(r)
    -- print("STATUS: ", result)
    return result
end

local function Check(cb)
    local ota_cfg = require("sys-config").JSON("rest.cfg")
    if not ota_cfg then error("OTA: No config file") end
    local http_handler = require("ota-http").New(ota_cfg.host, ota_cfg.port)

    package.loaded["sys-config"] = nil
    package.loaded["ota-http"] = nil

    http_handler:AddRequest({
        action = "POST",
        payload = GetStatusPayload(),
        request = makeRestRequestUrl("status"),
        response_cb = function(data) CheckOtaStatus(cb, data) end
    })

    package.loaded["ota-http"] = nil
    http_handler:SetFinishedCallback(function(r)
        if not r then CheckOtaStatus(cb, nil) end
    end)
    http_handler:Start()
end

return {Check = Check}
