return {
  Init = function()
    if adc.force_init_mode(adc.INIT_VDD33) then
      node.restart()
    end
  end,
  Read = function(output)
    local vcc = adc.readvdd33(0),
    MQTTPublish("/system/vcc", tostring(vcc))
  end,
}
