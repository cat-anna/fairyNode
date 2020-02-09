local Module = {}
Module.__index = Module

function Module:ContrllerInit(event, ctl)
  -- local props = { }
  -- local any = false

  -- for _,v in pairs(hw.gpio) do
  --     print("GPIO: Preparing:", v.pin, v.trig)

  --     v.pulse = tmr.now()
  --     v.state = 0

  --     any = true
  --     props[v.trig] = {
  --         datatype = "integer",
  --         name = "gpio " .. v.trig,
  --     }

  --     gpio.mode(v.pin, gpio.INT, v.pullup and gpio.PULLUP or nil)
  --     gpio.trig(v.pin, "both", function(...) pcall(self.HandlePinChange, self, v, ...) end)

  --     v.pullup = nil
  -- end

  -- if any then
  --     self.node = ctl:AddNode("gpio", {
  --         name = "gpio",
  --         properties = props,
  --     })    
  -- end  
end

local kTpClockDelay = 2

function Module:TriggerRead()
  self:ClearTrigger()

  local st = 0
  for i=0,15 do 
    gpio.write(self.scl, gpio.LOW)
    tmr.delay(kTpClockDelay)
    gpio.write(self.scl, gpio.HIGH)   
    tmr.delay(kTpClockDelay)
    if gpio.read(self.sd0) == 0 then
      st = bit.bor(st, bit.lshift(1, i))
    end
  end

  if self.state ~= nil and self.state ~= st then
      for i=0,15 do
        local flag = bit.lshift(1, i)
        local new_state =  bit.band(st, flag)
          if bit.band(self.state, flag) ~= new_state then
            print("TP229: BUTTON:", i + 1, new_state ~= 0 and "down" or "up")
            Event("tp229.btn_" .. tonumber(i + 1), new_state ~= 0)
        end
    end
  end

  self.state = st
  self:SetTrigger()
end

function Module:SetTrigger()
  gpio.trig(self.sd0, "up", function(...) self:TriggerRead(...) end)
end

function Module:ClearTrigger()
  gpio.trig(self.sd0)
end

function Module:Init()
  gpio.mode(self.scl, gpio.OUTPUT)
  gpio.write(self.scl, gpio.HIGH)
  gpio.mode(self.sd0, gpio.INPUT)
  self:SetTrigger()
end

Module.EventHandlers = {
  ["app.init.post-services"] = Module.Init,
  ["controller.init"] = Module.ContrllerInit,
  ["ota.start"] = Module.ClearTrigger,
}

return {
  Init = function()
      if not hw or not hw.ttp229 or not gpio then
          return
      end

      local conf = hw.ttp229
      hw.ttp229 = nil
      
      conf.state = 0
      return setmetatable(conf, Module)
  end,
}
