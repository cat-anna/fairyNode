
local M = { }

function M.gotip(evid, T)
    if hw and hw.led and hw.led.wifi then
        local l = hw.led.wifi
        gpio.write(l.pin, l.invert and gpio.LOW or gpio.HIGH)
    end
    print("WiFi: got IP address: " .. T.IP)
    node.task.post(function()
        local ntp = loadScript("sys-ntp", true)
        if ntp then
        ntp.Init()
        end    
    end)
end

function M.connected(evid, T)
    print("WiFi: connected SSID: "..T.SSID.." BSSID: "..T.BSSID.." channel: "..T.channel)    
end

function M.disconnected(evid, T)
    if hw and hw.led and hw.led.wifi then
        local l = hw.led.wifi
        gpio.write(l.pin, l.invert and gpio.HIGH or gpio.LOW)
    end    
    print("WiFi: disconnected SSID: "..T.SSID.." BSSID: "..T.BSSID.." reason: "..T.reason)    
end

return M
