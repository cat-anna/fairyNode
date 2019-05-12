--
-- If you have the LFS _init loaded then you invoke the provision by
-- executing LFS.HTTP_OTA('your server','directory','image name').  Note
-- that is unencrypted and unsigned. But the loader does validate that
-- the image file is a valid and complete LFS image before loading.
--

local ota_cfg = require("sys-config").JSON("rest.cfg")
if not ota_cfg then
  print "OTA: No config file"
  return
end

local n, total, size = 0,0,0
local image_file = "lfs.img.pending"

local function EndOta()
  local s = file.stat(image_file)
  if (s and size == s.size) then
    print "OTA: Preparing to reboot..."
    wifi.setmode(wifi.NULLMODE)
    node.task.post(node.restart)
  else
    print "OTA: Invalid save of image file"
    file.remove(image_file)
    node.restart()
  end
end

local function subsRec(sck, rec)
  total, n = total + #rec, n + 1
  if n % 4 == 1 then
    sck:hold()
    node.task.post(
      0,
      function()
        sck:unhold()
      end
    )
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
        print("OTA: download completed")
        EndOta()
      end
    )
  end
end

local postHeader_firstRec = false
local function firstRec(sck, rec)
  if rec == "\r\n" then
    postHeader_firstRec = true
    return
  end
  if not postHeader_firstRec then
    if size == 0 then
      size = tonumber(rec:lower():match("content%-length: (%d+)") or 0)
    end
    return
  end

  if size > 0 then
    file.open(image_file, "w")
    sck:on("receive", subsRec)
    subsRec(sck, rec)
  else
    sck:on("receive", nil)
    sck:close()
    print("OTA: download failed")
  end
end

local function makeRequest(uri, host)
  local url = string.format("/ota/%06X/%s", node.chipid(), uri)
  return table.concat( {
      "GET " .. url .. " HTTP/1.1",
      "User-Agent: ESP8266 app (linux-gnu)",
      "Accept: application/octet-stream",
      "Accept-Encoding: identity",
      "Host: " .. host,
      "Connection: close",
      "",
      ""
    }, "\r\n")
end

local function DoUpdate(sk, hostIP)
  if hostIP then
    local con = net.createConnection(net.TCP, 0)
    con:connect(ota_cfg.port, hostIP)
    -- Note that the current dev version can only accept uncompressed LFS images
    con:on(
      "connection",
      function(sck)
        local request = makeRequest("image", ota_cfg.host)
        sck:send(request)
        sck:on("receive", firstRec)
      end
    )
  end
end

local function BeginOta()
  if event then event("ota.start") end 
  if cron then
    cron.reset()
  end

  if file.exists(image_file) then
    file.remove(image_file)
  end

  tmr.create():alarm(5000, tmr.ALARM_SINGLE, function()
    print("OTA: Starting download...")
    if ota_cfg.hostIP then
      DoUpdate(nil, ota_cfg.hostIP)
    else
      net.dns.resolve(ota_cfg.host, DoUpdate)
    end
  end)
end

local postHeader_querryResult = false
local function querryResult(sck, rec)
  if rec == "\r\n" then
    postHeader_querryResult = true
    return
  end
  if not postHeader_querryResult then
    return
  end
  
  pcall(sck.close, sck)

  local payload = rec
  local stamp = tonumber(payload)

  local err, my_stamp = pcall(require, "lfs-timestamp")
  if not err or type(my_stamp) ~= "number" then
    my_stamp = 0
  end
  
  if not stamp then
    print("OTA: Timestamp error! (" .. tostring(payload) .. ")")
    return
  end

  print("OTA: timestamp my:" .. tostring(my_stamp) .. " remote:" .. tostring(stamp))

  if my_stamp < stamp then
    print("OTA: Update is needed")
    node.task.post(BeginOta)
  else
    print("OTA: lfs is up to date")
  end
end

local function doQuerry(sk, hostIP)
  if hostIP then
    ota_cfg.hostIP = hostIP
    local con = net.createConnection(net.TCP, 0)
    con:connect(ota_cfg.port, hostIP)
    con:on( "connection", function(sck)
        local request = makeRequest("timestamp", ota_cfg.host)
        sck:send(request)
        sck:on("receive", querryResult)
      end)
  end
end

return  {
  Check = function()
    net.dns.resolve(ota_cfg.host, doQuerry)
  end,
  Update = function()
    node.task.post(BeginOta)
  end,  
}