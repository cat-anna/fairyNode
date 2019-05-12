local CLK = {}

local timezone = require "timezone"

function CLK:AddScreen(data)
    local entry = {
        f = data.func,
        duration = data.duration,
        refresh = data.refresh or data.duration,
        single = data.singleTime,
        speed = data.speed,
    }
    if data.front then
        table.insert(self.q, 1, entry)
    else
        table.insert(self.q, entry)
    end
end

function CLK:PrintTime(curr, diff)
    local unix, usec = rtctime.get()
    if unix < 946684800 then -- 01/01/2000 @ 12:00am (UTC)
        return "no NTP"
    end
    local tm = rtctime.epoch2cal(unix + timezone.getoffset(unix))
    local s = tm["sec"]
    local s1 = math.floor(s / 10) + 1
    local ddot = (bit.band(s, 1) > 0) and ":" or "\25"
    return string.format("%02d%s%02d%c%c", tm["hour"], ddot, tm["min"], 0x19, s1)
end

function CLK:PrintDate(curr, diff)
    local unix, usec = rtctime.get()
    if unix < 946684800 then -- 01/01/2000 @ 12:00am (UTC)
        return "no NTP"
    end
    local tm = rtctime.epoch2cal(unix + timezone.getoffset(unix))
    local s = tm["sec"]
    local s1 = math.floor(s / 10) + 1
    return string.format("%02d/%02d %c", tm["day"], tm["mon"], s1)
end

function CLK:TextSwing(curr, diff, txt)
    if not self.swingBuffer then
        local mat = self:PrintText({}, 1, txt)
        local str = string.char(unpack(mat))
        mat = nil
        self.swingBuffer = string.rep("\0", self.w+1) .. str .. string.rep("\0", self.w+1)
    end
    local speed = curr.speed or 15
    local pos = math.floor((diff / 1000) * speed)
    local done = pos > (self.swingBuffer:len() - self.w)
    if done then
        self.swingBuffer = nil
        return "", nil, true
    end
    local buf = {self.swingBuffer:byte(pos, pos + self.w)}
    return nil, nil, false, buf
end

function CLK:MakeBuffer(t)
    local now = tmr.now() / 1000

    local curr = self.curr
    local startTime = self.startTime or 0
    local diff = bit.band((now - startTime), 0x7fffffff) or 0
    if not curr or (curr.duration and diff > curr.duration) then
        diff = 0
     
        curr = self.q[1]
        curr = table.remove(self.q, 1)
        if not curr.single then
            table.insert(self.q, curr)
        end

        self.curr = curr
        self.startTime = now
        if t then
            t:interval(curr.refresh or 1000)
        end
    end

    local succ, str, pos, done, buf = pcall(curr.f, self, curr, diff)
    if not succ then
        print("CLOCK: iERR:", str)
        str = "iERR"
    end
    if done then
        self.curr = nil
    end

    if str then
        buf = self.display:DisplayBuffer()
        self:PrintText(buf, pos or 1, str)
    end

    return buf
end

function CLK:PrintText(mat, x, txt, neg)
    local font = self.font
    if not font then
        collectgarbage()
        local hbeg = node.heap()
        self.font = require "font-5x7"
        collectgarbage()
        local hend = node.heap()
        print("CLOCK: font uses " .. tostring(hbeg - hend) .. " bytes")
        font = self.font
    end
    
    local limit = #mat
    local function put(p, v)
        if neg then
            v = bit.bnot(v)
        end
        if p > 0 and (limit == 0 or p <= limit) then
            mat[p] = v
        end
    end
    for i = 1, txt:len() do
        local char = txt:byte(i)
        local glyph = font[char]
        if not glyph then
            print("no glyph: ", char, string.char(char))
        else
            for n = 1, #glyph do
                put(x, glyph:byte(n))
                x = x + 1
            end
            put(x, 0x00)
            x = x + 1
        end
        if limit > 0 and x > limit then
            break
        end
    end
    return mat
end

function CLK:Refresh(t)
    -- local s = tmr.now()

    pcall(function()
        self.display:WriteColumns(self:MakeBuffer(t or self.timer))
    end)

    -- local e = tmr.now()
    -- if debugMode then
    --     print(string.format("refresh done in %f ms", (e - s) / 1000))
    -- end
end

function CLK:Flush()
    self.curr = nil
end

function CLK:Pause()
    if self.timer then
        self.timer:stop()
    end
end

return {
    StartClock = function (timer)
        local clk = {}

        clk.timer = timer
        clk.display = require("max7219").Setup()
        clk.w = 32

        clk.q = {
            {f = function(self, c, d) return "Node" end, duration = 2 * 1000, refresh = 2000, single = true},
            {f = function(self, c, d) return "MCU", self.w - 17 + 1 end, duration = 2 * 1000, refresh = 2000, single = true},
            {f = function(self, c, d) return self:TextSwing(c, d, wifi.sta.gethostname() .. " Welcome") end, speed = 15, refresh = 100, single = true},        
            {f = CLK.PrintTime, duration = 30 * 1000, refresh = 1000},
            {f = CLK.PrintDate, duration = 5 * 1000, refresh = 1000}
        }

        if timer then
            timer:alarm(10 * 1000, tmr.ALARM_AUTO, function(t) clk:Refresh(t) end)
        end

        return setmetatable(clk, {__index = CLK})
    end,
}