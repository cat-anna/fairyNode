return {
    Init = function()
        local pcfcfg = require("sys-config").JSON("pcf8591.cfg")
        if not pcfcfg then
            return
        end

        local props = {}

        for i=1,4 do 
            local name = pcfcfg.channels[i] or (string.format("channel_%d", i - 1))
            props[name] = {
                datatype = "float",
                name = name,
                unit = "%",
            }
        end

        HomieAddNode("pcf8591", {
            name = "pcf8591",
            properties = props
        })
    end,
    Read = function()
        local pcfcfg = require("sys-config").JSON("pcf8591.cfg")
        if not pcfcfg then
            pcfcfg = { }
        end

        if not pcfcfg.channels then
            pcfcfg.channels = { }
        end

        local pcf = require "pcf8591"

        local i2cfg = hw.i2c
        if i2cfg.sda and i2cfg.scl then
            i2c.setup(0, i2cfg.sda, i2cfg.scl, i2c.SLOW)
        end

        local read = { }
        for i=1,4 do 
            local name = pcfcfg.channels[i] or (string.format("channel_%d", i - 1))
            local value = pcf.adc(i - 1) / 255
            read[name] = string.format("%.3f", value)
            HomiePublishNodeProperty("pcf8591", name, string.format("%.3f", value * 100))
        end

        local name = pcfcfg.name or "pcf8591"
        local r = { }
        r[name] = read
        return r
    end,
  }
  