print("INIT: Initializing network...")

local wifi_connected = nil
local function SetWifiState(value)
    if wifi_connected == value then
        return
    end
    wifi_connected = value

    node.task.post(function()
        require("sys-led").Set("wifi", value)
    end)
    if Event then
        if wifi_connected then
            Event("wifi.connected")
        else
            Event("wifi.disconnected")
        end
    end
end

SetWifiState(false)

local hostname = require("sys-config").Read("hostname.cfg")
if not hostname then
    print("WiFi: No name config file")
    local chipid = node.chipid()
    hostname = string.format("ESP-%X", chipid)
else
    hostname = hostname:match("%w+")
end

print("WiFi: My name is", hostname, "'")

local station_cfg = require("sys-config").JSON("wifi.cfg")
if not station_cfg then
    print("WiFi: Network is disabled")
    wifi.setmode(wifi.NULLMODE)
else
    print("WiFi: Connecting to", station_cfg.ssid)

    wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(T)
        print("WiFi: got IP address:", T.IP)
        SetWifiState(true)
        if failsafe then
            node.task.post(function()
                pcall(function() require("ota-core").Check(failsafe) end)
            end)
        end
    end)
    wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, function(T)
        print("WiFi: connected SSID: " .. T.SSID .. " BSSID: " .. T.BSSID .. " channel: " .. T.channel)
    end)
    wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, function(T)
        print("WiFi: disconnected SSID: " .. T.SSID .. " BSSID: " .. T.BSSID .. " reason: " .. T.reason)
        SetWifiState(false)
    end)

    wifi.setmode(wifi.STATION)
    wifi.sta.sethostname(hostname)
    station_cfg.save = false
    station_cfg.auto = true
    wifi.sta.config(station_cfg)
end
