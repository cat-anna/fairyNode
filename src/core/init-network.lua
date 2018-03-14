
print "INIT: Initializing network..."

local hostname = loadScript("sys-config").Read("hostname.cfg")
if not hostname then
  print "WiFi: No name config file"
  local majorVer, minorVer, devVer, chipid, flashid, flashsize, flashmode, flashspeed = node.info()
  hostname = string.format("ESP-%X", chipid)
else
  hostname = hostname:match("%w+")
end

print("WiFi: My name is '" .. hostname .. "'")

--gpio.mode(4, gpio.OUTPUT)
--gpio.write(4, gpio.HIGH)

local station_cfg = loadScript("sys-config").JSON("wifi.cfg")
if not station_cfg then
  print "WiFi: Network is disabled"
  wifi.setmode(wifi.NULLMODE)
else
  print "WiFi: Starting..."

  wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(T)
    event("wifi.gotip", T)
--    gpio.write(4, gpio.LOW)
    -- print("WiFi: got IP address: " .. T.IP)
    -- local ntp = loadScript("sys-ntp", true)
    -- if ntp then
      -- ntp.Init()
    -- end    
  end)
  wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, function(T)
    event("wifi.connected", T)
    -- print("WiFi: connected SSID: "..T.SSID.." BSSID: "..T.BSSID.." channel: "..T.channel)
  end)
  wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, function(T)
    event("wifi.disconnected", T)
    -- gpio.write(4, gpio.HIGH)
    -- print("WiFi: disconnected SSID: "..T.SSID.." BSSID: "..T.BSSID.." reason: "..T.reason)
  end)    

  wifi.setmode(wifi.STATION)
  wifi.sta.sethostname(hostname)
  station_cfg.save = false
  station_cfg.auto = true
  wifi.sta.config(station_cfg)
end
