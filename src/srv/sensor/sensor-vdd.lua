return {
  Init = function()
    if not adc then
      return
    end

    if adc.force_init_mode(adc.INIT_VDD33) then
      node.restart()
    end

    HomieAddNode("supplyvoltage", {
        name = "Supply Voltage",
        properties = {
            voltage = {
                datatype = "float",
                name = "Supply Voltage",
                unit = "V",
            }
        }
    })
  end,
  Read = function()
    if adc then
      local v = string.format("%.3f", adc.readvdd33(0) / 1000)
      HomiePublishNodeProperty("supplyvoltage", "voltage", v)
    end
  end,
}
