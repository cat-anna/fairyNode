return {
  Init = function()
    if adc and adc.force_init_mode(adc.INIT_VDD33) then
      node.restart()
    end
  end,
  Read = function()
    if adc then
      return {
        vdd = string.format("%.3f", adc.readvdd33(0) / 1000),
      }
    else
      return {}
    end
  end,
}
