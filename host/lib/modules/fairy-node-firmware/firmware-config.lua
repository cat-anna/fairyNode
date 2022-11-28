local firmware_config = {}

firmware_config.root_install = {
    "init.lua", "init-bootstrap.lua", "ota-installer.lua"
}

firmware_config.files = {
    "{FW}/startup/init.lua", "{FW}/startup/init-hw.lua",
    "{FW}/startup/init-bootstrap.lua", "{FW}/startup/init-network.lua",
    "{FW}/startup/sys-config.lua", "{FW}/startup/sys-led.lua",
    "{FW}/startup/ota-core.lua", "{FW}/startup/ota-check.lua",
    "{FW}/startup/ota-http.lua", "{FW}/startup/ota-installer.lua"
}

firmware_config.lfs = {
    "{FW}/lfs/fairy-node-info.lua", "{FW}/lfs/init-lfs.lua",
    "{FW}/lfs/lfs-string.lua", "{FW}/lfs/init-service.lua",
    "{FW}/lfs/sys-event.lua", "{FW}/startup/init-hw.lua",
    "{FW}/startup/init-bootstrap.lua", "{FW}/startup/init-network.lua",
    "{FW}/startup/sys-config.lua", "{FW}/startup/sys-led.lua",

    "{FW}/startup/ota-core.lua", "{FW}/startup/ota-check.lua",
    "{FW}/startup/ota-http.lua", "{FW}/startup/ota-installer.lua",

    "{FW}/srv/srv-mqtt.lua", "{FW}/srv/srv-homie.lua", "{FW}/srv/srv-ntp.lua",
    "{FW}/srv/cmd/srv-command.lua", "{FW}/srv/cmd/cmd-gpio.lua",
    "{FW}/srv/cmd/cmd-help.lua", "{FW}/srv/cmd/cmd-sys.lua",

    "{FW}/srv/sensor/srv-sysinfo.lua", "{FW}/srv/sensor/srv-sensor.lua",
    "{FW}/srv/sensor/cmd-sensor.lua", "{FW}/lfs/event-error.lua",
    "{FW}/lfs/sys-error.lua", "{FW}/lfs/init-error.lua"
}

firmware_config.modules = {
    uart = {},
    led = {},
    adc = {lfs = {"{FW}/srv/sensor/srv-adc.lua"}},

    ow = {lfs = {"{FW}/srv/cmd/cmd-ow.lua"}},
    i2c = {lfs = {"{FW}/srv/cmd/cmd-i2c.lua"}},
    gpio = {lfs = {"{FW}/srv/srv-gpio.lua"}},
    dht11 = {lfs = {"{FW}/srv/sensor/srv-dht11.lua"}},
    telnet = {lfs = {"{FW}/lib/telnet.lua", "{FW}/srv/cmd/cmd-telnet.lua"}},
    ttp229 = {lfs = {"{FW}/srv/srv-ttp229.lua"}},
    bme280e = {lfs = {"{FW}/srv/sensor/srv-bme280e.lua"}},
    ws2812 = {lfs = {"{FW}/srv/srv-ws2812.lua"}},
    ds18b20 = {
        lfs = {"{FW}/lib/ds18b20.lua", "{FW}/srv/sensor/srv-ds18b20.lua"}
    },
    timezone = {lfs = {"{FW}/lib/timezone.lua"}, files = {"/etc/localtime"}},
    ["hd44780-i2c"] = {lfs = {"{FW}/srv/srv-hd44780-i2c.lua"}},

    -- TODO: Following modules must be refactored/fixed
    -- irx = { lfs = { "{FW}/srv/srv-irx.lua", }, }, -- not working
    pcm = {
        lfs = {
            "{FW}/srv/pcm/cmd-pcm.lua", "{FW}/srv/pcm/event-pcm.lua",
            "{FW}/srv/pcm/mod-pcm.lua"
        }
    }
    -- clock32x8
}

return firmware_config
