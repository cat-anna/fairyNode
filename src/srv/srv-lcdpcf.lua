local module = { }

function module:Init()
    return {
      HandleMessage = function(topic, data, disp)
        require("srv-lcdpcf"):HandleMessage(topic, data, disp)
      end,
    }
end

function module:HandleMessage(topic, data, disp)
    print("lcdpcf:", topic, data)

    local nbeg,nend = topic:find(disp.name)
    nend = nend + 2
    local cmd = topic:sub(nend)

    print("lcdpcf cmd:", cmd, data)
    self:Command(cmd, data, disp)
end

function module:PrintLine(disp, line, txt)
    if txt == "" then
        txt = string.rep(" ", disp.size[0])
    end

    self:SetCursor(disp, 0, line)
    self:Print(disp, txt)
end

function module:Command(cmd, data, disp)
    local commands = {
        backlight = function(cmd, data, disp)
            disp.backlight = data == "1"
            self:SetBackLight(disp)
        end,
        ["line/0"] = function(cmd, data, disp)
            self:PrintLine(disp, 0, data)
        end,
        ["line/1"] = function(cmd, data, disp)
            self:PrintLine(disp, 1, data)
        end,
    }

    local h = commands[cmd]
    if h then
        h(cmd, data, disp)
    else
        print("lcdpcf: unknown command:", cmd, data)
    end
end

function module:Add(data)
    local disp = {
        size = data.size,
        name = data.name,
        address = 0x27,
        backlight = data.backlight,
    }

    disp.topic = "/device/" .. cfg.hostname .. "/" .. data.name .. "/#"
    disp.handler = modules.lcdpcf.HandleMessage

    self:Reset(disp)
    modules.mqtt:Subscribe(disp)
end

local function write(addr, data)
    i2c.start(0)
    i2c.address(0,addr,i2c.TRANSMITTER)
    i2c.write(0,data)
	i2c.stop(0)
end

local function sendLcdToI2C(disp, rs, e, data)
    local LSRS = 0 --regselect
    local LSRW = 1 --readwrite
    local LSE  = 2 --enable
    local LSLED= 3 --led backlight-- duplicated
    local LSDAT= 4 --data

	local value = bit.lshift(rs, LSRS)
    value = value + bit.lshift(e, LSE)
    value = value + bit.lshift(data, LSDAT)
    value = value + bit.lshift(ifthen(disp.backlight, 1, 0), LSLED)
	write(disp.address, value)
end

local function sendLcdRaw(disp, rs, data)
	sendLcdToI2C(disp, rs, 1, data)
	sendLcdToI2C(disp, rs, 0, data)
end

local function sendLcd(disp, rs, data)
	local hignib = bit.rshift(bit.band(data, 0xF0),4)
	local lownib = bit.band(data, 0x0F)
	sendLcdRaw(disp, rs, hignib)
	sendLcdRaw(disp, rs, lownib)
end

function module:Reset(disp)
        --setup done, reset
    sendLcdRaw(disp, 0, 0x03)
    tmr.delay(4500)
    sendLcdRaw(disp, 0, 0x03)
    tmr.delay(4500)
    sendLcdRaw(disp, 0, 0x03)
    tmr.delay(4500)
        --4bit
    sendLcdRaw(disp, 0, 0x02)
    tmr.delay(150)
        --5x8 and 2line
    sendLcd(disp, 0, 0x28)
    tmr.delay(70)
        --dispoff
    sendLcdRaw(disp, 0, 0x08)
    tmr.delay(70)
        --entryset
    sendLcdRaw(disp, 0, 0x06)
    tmr.delay(70)
        --clear
    sendLcd(disp, 0, 0x01)
    tmr.delay(70)
        --dispon
    sendLcd(disp, 0, 0x0C)
    tmr.delay(70)
end

function module:Print(disp, txt)
    for i = 1, #txt do
        sendLcd(disp, 1, string.byte(txt, i))
    end
end

function module:SetCursor(disp, col, row)
    local ROW_OFFSETS = {0, 0x40, 0x14, 0x54}
    local val = bit.bor(0x80, col, ROW_OFFSETS[row + 1])
    sendLcd(disp, 0, val)
end

function module:SetBackLight(disp)
    local LSLED = 3 --led backlight -- duplicated
    local backlight = bit.lshift(ifthen(disp.backlight, 1, 0), LSLED)
    write(disp.address, backlight)
end

return module
