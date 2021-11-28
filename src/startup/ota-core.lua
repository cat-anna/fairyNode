
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
  package.loaded["ota-installer"] = nil
  package.loaded["sys-config"] = nil
end

local OtaCoreMt = {}
OtaCoreMt.__index = OtaCoreMt

function OtaCoreMt.New()
  local ota_cfg = require("sys-config").JSON("rest.cfg")
  if not ota_cfg then
    error("OTA: No config file")
  end
  local http_handler = require("ota-http").New(ota_cfg.host, ota_cfg.port)
  local obj = setmetatable({
    http_handler = http_handler,
  }, OtaCoreMt)
  PackageCleanup()
  return obj
end

function OtaCoreMt:AddDownload(file_name, request)
  if file.exists(file_name) then
    file.remove(file_name)
  end
  self.http_handler:AddDownloadItem({
    request = makeRestRequestUrl(request),
    target_file = file_name,
  })
end

function OtaCoreMt:AddLfsDownload()
  self:AddDownload(LFS_PENDING_FILE, "lfs_image")
end

function OtaCoreMt:AddRootDownload()
  self:AddDownload(ROOT_PENDING_FILE, "root_image")
end

function OtaCoreMt:AddConfigDownload()
  self:AddDownload(CONFIG_PENDING_FILE, "config_image")
end

function OtaCoreMt:DownloadCompleted()
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

  if file.exists(TOKEN_FILE_NAME) then
    file.remove(TOKEN_FILE_NAME)
  end

  self.http_handler:SetFinishedCallback(function() self:DownloadCompleted() end)

  tmr.create():alarm(5000, tmr.ALARM_SINGLE, function()
    self.http_handler:Start()
  end)
end

local function LoadTimestamps()
  local r = { }

  local loaded, lfs_stamp = pcall(require, "lfs-timestamp")
  if loaded then
    if type(lfs_stamp) == "table" then
      r.lfs = lfs_stamp
    end
  end

  loaded, root_stamp = pcall(require, "root-timestamp")
  if loaded then
      r.root = root_stamp
  end

  if file.exists("config_hash.cfg") then
    r.config = require("sys-config").JSON("config_hash.cfg")
  end

  print("OTA: My timestamps: " .. sjson.encode(r))
  return r
end

function OtaCoreMt:CheckWhatToUpdate(remote_status, my_timestamps, ignore_host_disable)
  local any_download = false

  ignore_host_disable = ignore_host_disable or (failsafe == true)

  local function compare(remote, my)
    if not my or not my.hash then
      return true
    end
    if not remote or not remote.hash then
      return false
    end

    return my.hash ~= remote.hash
  end

  if compare(remote_status.lfs, my_timestamps.lfs) then
    if remote_status.enabled or ignore_host_disable then
      print("OTA: LFS update is needed")
      self:AddLfsDownload()
      any_download = true
    else
      print("OTA: LFS update is needed, but ota is disabled for this device")
    end
  else
    print("OTA: LFS is up to date")
  end

  if compare(remote_status.root, my_timestamps.root) then
    if remote_status.enabled or ignore_host_disable then
      print("OTA: ROOT update is needed")
      self:AddRootDownload()
      any_download = true
    else
      print("OTA: ROOT update is needed, but ota is disabled for this device")
    end
  else
    print("OTA: ROOT is up to date")
  end

  if compare(remote_status.config, my_timestamps.config) then
    if remote_status.enabled or ignore_host_disable then
      print("OTA: CONFIG update is needed")
      self:AddConfigDownload()
      any_download = true
    else
      print("OTA: CONFIG update is needed, but ota is disabled for this device")
    end
  else
    print("OTA: CONFIG is up to date")
  end

  if not any_download then
    print("OTA: Nothing to update")
    return false
  end

  return any_download
end

function OtaCoreMt:CheckOtaStatus(data, ignore_host_disable)
  print("OTA: Remote status:" .. data)

  local succ, remote_status = pcall(sjson.decode, data)
  if not succ then
    print("OTA: Failed to parse status json:" .. tostring(data))
    return
  end
  data = nil

  local my_timestamps = LoadTimestamps()
  local status, any_download = pcall(self.CheckWhatToUpdate, self, remote_status, my_timestamps, ignore_host_disable)

  if status and any_download then
    node.task.post(function() self:BeginUpdate() end)
  end
end

function OtaCoreMt:Update()
  PackageCleanup()

  self:AddLfsDownload()
  self:AddRootDownload()
  self:AddConfigDownload()
  self:BeginUpdate()
end

function OtaCoreMt:Check(ignore_host_disable)
  PackageCleanup()

  if file.exists(TOKEN_FILE_NAME) and file.exists(ROOT_PENDING_FILE) then
    print("OTA: Root update is pending.")
    node.task.post(function() require("ota-installer").Install() end)
    return
  end

  self.http_handler:AddDownloadItem({
    request = makeRestRequestUrl("status"),
    response_cb = function(data) self:CheckOtaStatus(data, ignore_host_disable) end,
  })

  self.http_handler:Start()
end

return {
  Check = function(ignore_host_disable)
    node.task.post(function() OtaCoreMt.New():Check(ignore_host_disable) end)
  end,
  Update = function()
    node.task.post(function() OtaCoreMt.New():Update() end)
  end
}
