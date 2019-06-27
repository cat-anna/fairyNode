print "INIT: Initializing network..."

if Event then Event("wifi.disconnected", T) end

local hostname = require("sys-config").Read("hostname.cfg")
if not hostname then
  print "WiFi: No name config file"
  local majorVer, minorVer, devVer, chipid, flashid, flashsize, flashmode, flashspeed = node.info()
  hostname = string.format("ESP-%X", chipid)
else
  hostname = hostname:match("%w+")
end

print("WiFi: My name is '" .. hostname .. "'")

local station_cfg = require("sys-config").JSON("wifi.cfg")
if not station_cfg then
  print "WiFi: Network is disabled"
  wifi.setmode(wifi.NULLMODE)
else
  print("WiFi: Connecting to " .. station_cfg.ssid .. "...")

  wifi.eventmon.register(
    wifi.eventmon.STA_GOT_IP,
    function(T)
      print("WiFi: got IP address: " .. T.IP)
      if Event then Event("wifi.gotip", T) end 
      node.task.post(function() pcall(function() require("sys-ota").Check() end) end)
    end
  )
  wifi.eventmon.register(
    wifi.eventmon.STA_CONNECTED,
    function(T)
      print("WiFi: connected SSID: "..T.SSID.." BSSID: "..T.BSSID.." channel: "..T.channel)
      if Event then Event("wifi.connected", T) end
    end
  )
  wifi.eventmon.register(
    wifi.eventmon.STA_DISCONNECTED,
    function(T)
      print("WiFi: disconnected SSID: "..T.SSID.." BSSID: "..T.BSSID.." reason: "..T.reason)
      if Event then Event("wifi.disconnected", T) end
    end
  )

  wifi.setmode(wifi.STATION)
  wifi.sta.sethostname(hostname)
  station_cfg.save = false
  station_cfg.auto = true
  wifi.sta.config(station_cfg)
end
