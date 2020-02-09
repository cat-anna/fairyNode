
local Module = {}
Module.__index = Module

function Module:ContrllerInit(event, ctl)
end

function Module:Init()
end

function Module:OnOtaStart()
    ws2812_effects.set_speed(100)
    ws2812_effects.set_brightness(10)
    ws2812_effects.set_color(0,255,0)
    ws2812_effects.set_mode("halloween")
    ws2812_effects.start()
end

Module.EventHandlers = {
    ["ota.start"] = Module.OnOtaStart,
--   ["app.init.post-services"] = Module.Init,
--   ["controller.init"] = Module.ContrllerInit,
}

return {
  Init = function()
      if not hw or not hw.ws2812 or not ws2812 or not ws2812_effects then
          return
      end

      local conf = hw.ws2812
      hw.ws2812 = nil
      
      ws2812.init(ws2812.MODE_SINGLE)
      ws2812.write(string.rep(string.char(0,0,0), conf.count))
      local strip_buffer = ws2812.newBuffer(conf.count, 3)
      ws2812_effects.init(strip_buffer)

      return setmetatable({}, Module)
  end,
}
