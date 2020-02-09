local Module = { }
Module.__index = Module

function Module:Write(data)
    i2c.start(0)
    i2c.address(0,self.address,i2c.TRANSMITTER)
    i2c.write(0,data)
	i2c.stop(0)
end

function Module:SetBackLight(value)
    self.backlight = value and true or false
    self:sendLcdToI2C(0,0,0)
end

function Module:SetCursor(col, row)
    local ROW_OFFSETS = {0, 0x40, 0x14, 0x54}
    local val = bit.bor(0x80, col, ROW_OFFSETS[row + 1])
    self:sendLcd(0, val)
end

function Module:PrintLine(line, txt)
    if txt == "" then
        txt = string.rep(" ", self.size[1])
    elseif txt:len() > self.size[1] then
        txt = txt:sub(1, self.size[1])
    elseif txt:len() < self.size[1] then
        txt = txt .. string.rep(" ", self.size[1] - txt:len())
    end

    self:SetCursor(0, line)
    self:Print(txt)
end

function Module:sendLcd(rs, data)
	local hignib = bit.rshift(bit.band(data, 0xF0),4)
	local lownib = bit.band(data, 0x0F)
	self:sendLcdRaw(rs, hignib)
	self:sendLcdRaw(rs, lownib)
end

function Module:Print(txt)
    for i = 1, #txt do
        self:sendLcd(1, string.byte(txt, i))
    end
end

function Module:Clear()
    self:sendLcd(0, 0x01)
end

function Module:sendLcdToI2C(rs, e, data)
    local LSRS = 0 --regselect
    local LSRW = 1 --readwrite
    local LSE  = 2 --enable
    local LSLED= 3 --led backlight
    local LSDAT= 4 --data

	local value = bit.lshift(rs, LSRS)
    value = value + bit.lshift(e, LSE)
    value = value + bit.lshift(data, LSDAT)
    value = value + bit.lshift((self.backlight and 1 or 0), LSLED)
	self:Write(value)
end

function Module:sendLcdRaw(rs, data)
	self:sendLcdToI2C(rs, 1, data)
	self:sendLcdToI2C(rs, 0, data)
end

function Module:DisplayOff()
    self:sendLcdRaw(0, 0x08)
end

function Module:DisplayOn()
    self:Clear()
    self:sendLcd(0, 0x0C)
end

function Module:Reset()
    --setup done, reset
    self:sendLcdRaw(0, 0x03)
    tmr.delay(4500)
    self:sendLcdRaw(0, 0x03)
    tmr.delay(4500)
    self:sendLcdRaw(0, 0x03)
    tmr.delay(4500)
        --4bit
    self:sendLcdRaw(0, 0x02)
    tmr.delay(150)
        --5x8 and 2line
    self:sendLcd(0, 0x48)
    tmr.delay(70)
        --dispoff
    self:DisplayOff()
        --entryset
    self:sendLcdRaw(0, 0x06)
        --clear
    self:DisplayOn()
end

function Module:OnOtaStart(id, arg)
    self:Clear()
    tmr.delay(70)
    self:SetBackLight(true)
    self:PrintLine(0, "OTA...")
end

function Module:OnEvent(id, arg)
    local handlers = {
        ["ota.start"] = self.OnOtaStart,
    }
    local h = handlers[id]
    if h then
        pcall(h, self, id, arg)
    end   
end

return {
    Init = function(add_service)
        if not hw["hd44780-i2c"] then
            return nil
        end

        for k,v in pairs(hw["hd44780-i2c"]) do
            local module = setmetatable(v, Module)
            pcall(function() module:Reset() module:PrintLine(0, "Initializing...") end)
            add_service(k, module)
        end

        return nil
    end,
}

