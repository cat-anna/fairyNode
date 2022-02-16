print "INIT: Initializing network..."

if Event then Event("wifi.disconnected", T) end

local hostname = require("sys-config").Read("hostname.cfg")
if not hostname then
  print "WiFi: No name config file"
  local chipid = node.chipid()
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
      node.task.post(function() if Event then Event("wifi.gotip") end end)
      node.task.post(function() require("sys-led").Set("wifi", true) end)
      tmr.create():alarm((failsafe and 1 or 60) * 1000, tmr.ALARM_SINGLE,
        function(t)
            t:unregister()
            pcall(function()
              require("ota-core").Check(failsafe)
            end)
        end)
    end
  )
  wifi.eventmon.register(
    wifi.eventmon.STA_CONNECTED,
    function(T)
      print("WiFi: connected SSID: "..T.SSID.." BSSID: "..T.BSSID.." channel: "..T.channel)
      node.task.post(function() if Event then Event("wifi.connected") end end)
    end
  )
  wifi.eventmon.register(
    wifi.eventmon.STA_DISCONNECTED,
    function(T)
      print("WiFi: disconnected SSID: "..T.SSID.." BSSID: "..T.BSSID.." reason: "..T.reason)
      node.task.post(function() if Event then Event("wifi.disconnected") end end)
      node.task.post(function() require("sys-led").Set("wifi", false) end)
    end
  )

  wifi.setmode(wifi.STATION)
  wifi.sta.sethostname(hostname)
  station_cfg.save = false
  station_cfg.auto = true
  wifi.sta.config(station_cfg)
end
