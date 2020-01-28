
local fwconfig = {}
fwconfig.__index = fwconfig

fwconfig.files = {
    "{FW}/startup/init.lua",
    "{FW}/startup/init-hw.lua",
    "{FW}/startup/init-bootstrap.lua",
    "{FW}/startup/init-network.lua",
    "{FW}/startup/sys-config.lua",
    "{FW}/startup/sys-led.lua",
    "{FW}/startup/ota-core.lua",
    "{FW}/startup/ota-http.lua",
    "{FW}/startup/ota-installer.lua",
}

fwconfig.lfs = {
    "{FW}/lfs/fairy-node-info.lua",
    
    "{FW}/lfs/init-lfs.lua",
    "{FW}/lfs/lfs-string.lua", 
    "{FW}/lfs/init-service.lua",
    "{FW}/lfs/sys-event.lua",
    "{FW}/startup/init-hw.lua",
    "{FW}/startup/init-bootstrap.lua",
    "{FW}/startup/init-network.lua",
    "{FW}/startup/sys-config.lua",
    "{FW}/startup/sys-led.lua",

    "{FW}/startup/ota-core.lua",
    "{FW}/startup/ota-http.lua",            
    "{FW}/startup/ota-installer.lua",

    "{FW}/srv/srv-mqtt.lua",
    "{FW}/srv/srv-homie.lua",
    "{FW}/srv/srv-ntp.lua",
    "{FW}/srv/cmd/srv-command.lua",
    "{FW}/srv/cmd/cmd-gpio.lua",
    "{FW}/srv/cmd/cmd-help.lua",
    "{FW}/srv/cmd/cmd-sys.lua",

    "{FW}/srv/sensor/srv-sysinfo.lua",
    "{FW}/srv/sensor/srv-sensor.lua",
    "{FW}/srv/sensor/cmd-sensor.lua",
    
    "{FW}/lfs/event-error.lua",
    "{FW}/lfs/sys-error.lua",
    "{FW}/lfs/init-error.lua",

    bme280e = {
        mode = "conditional",
        "{FW}/srv/sensor/srv-bme280e.lua",
    },
    -- ds18b20 = {
    --     mode = "conditional",
    --     "{FW}/lib/ds18b20.lua",
    --     "{FW}/srv/sensor/sensor-ds18b20.lua",
    -- },
    -- dht11 = {
    --     mode = "conditional",
    --     "{FW}/srv/sensor/sensor-dht11.lua",
    -- },

    i2c = {
        mode = "conditional",
        "{FW}/srv/cmd/cmd-i2c.lua",
    },
    ow = {
        mode = "conditional",
        "{FW}/srv/cmd/cmd-ow.lua",
    },
    gpio = {
        mode = "conditional",
        "{FW}/srv/srv-gpio.lua",
    },
    ["hd44780-i2c"] = {
        mode = "conditional",
        "{FW}/srv/srv-hd44780-i2c.lua",
    },
}

    -- "{FW}/lib/fifosock.lua",
    -- "srv/cmd/cmd-telnet.lua",
    -- "lib/telnet.lua",
    -- "srv/cmd/cmd-ftpserver.lua",
    -- "lib/ftpserver.lua",
}

return fwconfig
