local Module = {}
Module.__index = Module

function Module:ResetPulse(level, t)
    print(string.format("VALUE 0x%08x",  self.value))
    -- gpio.write(3, gpio.LOW)

    print(sjson.encode(self.pulses))
    self.pulses = { }
    self:SetTrigger()

    if bit.band(self.value, 0x00f00000) ~= 0x00f00000 then
        print "invalid"
        return
    end

    local code = bit.rshift(bit.band(self.value, 0xFF00), 8)
    local negcode = bit.band(bit.bnot(self.value), 0xFF)
    -- print(string.format("%x %x", code, negcode))
    if code == negcode then
        self.last_code = code
        print(string.format("IRX: Got code %02x", code))
        -- if Event then
            -- Event("irx.code", { code = code })
        -- end
    end
end

function Module:BitPulse(level, t)
    local d = bit.band((t - self.pulse), 0x7fffffff)
    table.insert(self.pulses, d)
    local b
    if d > 1000 and d < 1200 then
        b = 0
    elseif d > 2100 and d < 2400 then
        b = 1
    end    

    if self.bitno >= 0 then
        if b == 1 then
            local bvalue = bit.lshift(1, self.bitno)
            self.value = bit.bor(self.value, bvalue)
        end
    else
        if self.bitno < -1 then
            gpio.trig(self.pin, "up", function(...) self:ResetPulse(...) end)
        end
    end
    self.bitno = self.bitno - 1
    self.pulse = t
end

function Module:SpacePulse(level, t)
    local d = bit.band((t - self.pulse), 0x7fffffff)
    -- print("SpacePulse", d, level)
    table.insert(self.pulses, d)
    if level == 1 then
        if d < 8 * 1000 then
            --abort
        end
    else
        if d > 4 * 1000 and d < 5 * 1000 then
            gpio.trig(self.pin, "down", function(...) self:BitPulse(...) end)
            self.bitno = 31
            self.value = 0
        else
            --abort
            if d > 2100 and d < 2300 then
                --repeat code?
                if self.last_code ~= nil
                --  and Event 
                 then
                    print(string.format("IRX: Repeat code %02x", self.last_code))
                    -- Event("irx.code", { code = self.last_code, is_repeat = true })
                end
                -- gpio.write(3, gpio.LOW)
            end
        end
    end
    self.pulse = t    
end

function Module:StartPulse(level, t)
    -- print "start"
    self.pulse = t
    gpio.trig(self.pin, "both", function(...) self:SpacePulse(...) end)
    -- gpio.write(3, gpio.HIGH) --?
end

function Module:SetTrigger()
    self.bitno = 31
    self.value = 0
    self.pulse = 0
    self.pulses = { }
    gpio.trig(self.pin, "down", function(...) self:StartPulse(...) end)
end
  
function Module:ClearTrigger()
-- gpio.trig(self.sd0)
end
  
function Module:Init()
    gpio.mode(self.pin, gpio.INT)
    self:SetTrigger()
end

Module.EventHandlers = {
    -- ["app.init.post-services"] = Module.Init,
    ["app.start"] = Module.Init,
    -- ["controller.init"] = Module.ContrllerInit,
    -- ["ota.start"] = Module.ClearTrigger,
}

return {
    Init = function()
        if not hw or not hw.irx or not bit then
            print("IRX: Preconditions not met")
            return
        end
  
        local conf = hw.irx
        hw.irx = nil
        
        return setmetatable(conf, Module)
    end,
}
  