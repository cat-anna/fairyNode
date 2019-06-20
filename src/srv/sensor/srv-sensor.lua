
sensor = sensor or {}

return {
    Init = function()
        if cron and not sensor.schedule then
            sensor.schedule = cron.schedule(
                "*/10 * * * *",
                function()
                    require("srv-sensor").Read()
                end
            )
        end
    end,
    Read = function()
        MQTTPublish("/status/uptime", tmr.time())
        MQTTPublish("/status/heap", node.heap())
        MQTTPublish("/status/rssi", wifi.sta.getrssi())

        local s, lst = pcall(require, "lfs-sensors")
        if s then
            for _,v in ipairs(lst) do
                pcall(function()
                    local m = require(v)
                    m.Read(sensor)
                end)
            end
        end
    end
}
