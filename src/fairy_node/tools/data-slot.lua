local copas = require "copas"

-------------------------------------------------------------------------------------

local SlotMt = { }
SlotMt.__index = SlotMt

function SlotMt:Tag()
    return "Slot"
end

function SlotMt:WaitForData()
    assert(self.waiting_thread == nil)
    self.waiting_thread = coroutine.running()
    copas.pauseforever()
    local data = self.data
    self.data = nil
    return data
end

function SlotMt:SendData(data)
    if self.waiting_thread then
        self.data = data
        local th = self.waiting_thread
        self.waiting_thread = nil
        copas.wakeup(th)
    else
        print(self, "Thread is not waiting") --?
    end
end

-------------------------------------------------------------------------------------

local Slot = { }

function Slot.New()
    return setmetatable({}, SlotMt)
end

return Slot
