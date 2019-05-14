local ota_cfg = require("sys-config").JSON("rest.cfg")
if not ota_cfg then
  print "OTA: No config file"
  return
end

local n, total, size = 0, 0, 0
local image_file = "lfs.img.pending"

local function EndOta()
  local s = file.stat(image_file)
  if (s and size == s.size) then
    print "OTA: Preparing to reboot..."
    wifi.setmode(wifi.NULLMODE)
    if abort then
    print "OTA: Aborted"
    file.remove(image_file)
    else
      node.task.post(node.restart)
    end
  else
    print "OTA: Invalid save of image file"
    file.remove(image_file)
    node.restart()
  end
end

local function OtaDownloadContinue(sck, rec)
  total, n = total + #rec, n + 1
  if n % 2 == 1 then
    sck:hold()
    node.task.post(0, function() sck:unhold() end)
  end
  uart.write(0, ("OTA: %u of %u\n"):format(total, size))
  file.write(rec)
  rec = nil
  collectgarbage()
  if total == size then
    node.task.post(
      function()
        file.close()
        sck:on("receive", nil)
        pcall(sck.close, sck)
        print("OTA: Download completed")
        EndOta()
      end
    )
  end
end

local function HandleOtaDownload(sck, rec, state)
  state.buf = state.buf .. rec

  if not state.gotHeaders then
    local pos      = state.buf:find('\r\n\r\n',1,true) 
    if pos then
      state.gotHeaders = true
      local header = state.buf:sub(1,pos + 1):lower()
      size = tonumber(header:match("content%-length: (%d+)"))
      state.buf = state.buf:sub(pos + 4)
    else
      return
    end
  end

  if size > 0 then
    file.open(image_file, "w")
    sck:on("receive", OtaDownloadContinue)
    OtaDownloadContinue(sck, state.buf)
  else
    sck:on("receive", nil)
    pcall(sck.close, sck)
    print("OTA: download failed")
  end
  state.buf = nil
end

local function makeRequest(uri, host)
  local url = string.format("/ota/%06X/%s", node.chipid(), uri)
  return table.concat(
    {
      "GET " .. url .. " HTTP/1.1",
      "User-Agent: ESP8266 app (linux-gnu)",
      "Accept: application/octet-stream",
      "Accept-Encoding: identity",
      "Host: " .. host,
      "Connection: close",
      "",
      ""
    },
    "\r\n"
  )
end

local function BeginDownload(sk, hostIP)
  local con = net.createConnection(net.TCP, 0)
  con:connect(ota_cfg.port, hostIP)
  -- Note that the current dev version can only accept uncompressed LFS images
  con:on(
    "connection",
    function(sck)
      local request = makeRequest("image", ota_cfg.host)
      sck:send(request)
      local state = {buf = ""}
      sck:on("disconnection", function() 
          pcall(sck.on,sck,"receive", nil)
        end)
      sck:on("receive", function(a,b) return HandleOtaDownload(a,b,state) end)
    end
  )
end

local function BeginOtaDownload()
  if event then
    event("ota.start")
  end
  if cron then
    cron.reset()
  end

  if file.exists(image_file) then
    file.remove(image_file)
  end

  tmr.create():alarm(
    5000,
    tmr.ALARM_SINGLE,
    function()
      print("OTA: Starting download...")
      if ota_cfg.hostIP then
        BeginDownload(nil, ota_cfg.hostIP)
      else
        net.dns.resolve(ota_cfg.host, BeginDownload)
      end
    end
  )
end

local function HandleOtaStatusResponse(sck, rec, state)
  state.buf = state.buf .. rec

  if not state.gotHeaders then
    local pos      = state.buf:find('\r\n\r\n',1,true) 
    if pos then
      state.gotHeaders = true
      local header = state.buf:sub(1,pos + 1):lower()
      state.buf = state.buf:sub(pos + 4)
    else
      return
    end
  end
  
  local succ, status = pcall(sjson.decode, state.buf)
  if not succ then
    --not all data may have been received
    return
  end

  state.buf = nil

  local err, my_stamp = pcall(require, "lfs-timestamp")
  if not err or type(my_stamp) ~= "number" then
    my_stamp = 0
  end

  print("OTA: timestamp my:" .. tostring(my_stamp) .. " remote:" .. tostring(status.timestamp))

  if my_stamp < status.timestamp then
    print("OTA: Update is needed")
    if status.enabled or my_stamp == 0 then
      node.task.post(BeginOtaDownload)
    else
      print("OTA: update is disabled")
    end
  else
    print("OTA: lfs is up to date")
  end
end

local function QuerryStatus(sk, hostIP)
 ota_cfg.hostIP = hostIP
  print("OTA: querrying " .. hostIP)
  local con = net.createConnection(net.TCP, 0)
  con:connect(ota_cfg.port, hostIP)
  con:on(
    "connection",
    function(sck)
      local request = makeRequest("status", ota_cfg.host)
      sck:send(request)
      local state = {buf = ""}
      sck:on("disconnection", function() 
          pcall(sck.on,sck,"receive", nil)
        end)
      sck:on("receive", function(a,b) return HandleOtaStatusResponse(a,b,state) end)
    end
  )
end
    
return {
  Check = function()
    net.dns.resolve(ota_cfg.host, QuerryStatus)
  end,
  Update = function()
    node.task.post(BeginOtaDownload)
  end
}
