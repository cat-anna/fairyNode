
local clock = { } 

function clock:printText(mat,x,txt,neg)
    local font = self.font
    local fontext
    local hasfontext
    
    local limit = #mat
    local function put(p, v)
        if neg then
            v = bit.bnot(v)
        end
        if p > 0 and (limit == 0 or p <= limit) then
            mat[p] = v
        end
    end
    for i=1,txt:len() do
        local char = txt:byte(i)
        local glyph = font[char] or (fontext and fontext[char])
        if not glyph and not hasfontext then            
            hasfontext = true
            fontext = loadScript("font-5x7-ext")
            glyph = fontext and fontext[char]
        end
        if not glyph then            
            print("no glyph: ", char, string.char(char))
        else
            for n=1,#glyph do
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

function clock:printTime(curr, diff)
    local unix, usec = rtctime.get()
    if unix < 946684800 then
        return "no NTP"
    end
    local tm = rtctime.epoch2cal(unix)
    local s = tm["sec"]
    local s1 = math.floor(s / 10) + 1
    local ddot = (bit.band(s, 1) > 0) and ":" or "\25"
    return string.format("%02d%s%02d%c%c", tm["hour"]+1, ddot, tm["min"],0x19,s1)
end

function clock:printDate(curr, diff)
    local unix, usec = rtctime.get()
    if unix < 946684800 then
        return "no NTP"
    end    
    local tm = rtctime.epoch2cal(unix)
    local s = tm["sec"]
    local s1 = math.floor(s / 10) + 1
    return string.format("%02d/%02d %c", tm["day"], tm["mon"], s1)
end

function clock:textSwing(curr, diff, txt)
    if not self.swingBuffer then
        local mat = self:printText({}, 1, txt)
        local str = string.char(unpack(mat))
        mat = nil
        self.swingBuffer = string.rep("\0", 33) .. str .. string.rep("\0", 33)
    end
    local pos = math.floor((diff/1000) * 15)
    local done = pos > (self.swingBuffer:len()-32)
    if done then
        self.swingBuffer = nil
        return "", nil, true
    end
    local buf = { self.swingBuffer:byte(pos, pos+32) }
    return nil, nil, false, buf
end

function clock:makeBuffer(t)
    local now = tmr.now() / 1000

    local curr = self.curr    
    local diff = curr and bit.band((now - curr.beg), 0x7fffffff) or 0
    if not curr or (curr.duration > 0 and diff > curr.duration) then
        diff = 0
        local next = table.remove( self.q, 1 )
        if not next then
            t:interval(1000)
            return ""
        end
        curr = {
            func = next[1],
            duration = next[2] * 1000,
            beg = now,
        }        
        if t then
            t:interval(next[3])
        end
        self.curr = curr
        if not next[4] then
            table.insert(self.q, next)
        end
    end

    local succ, str, pos, done, buf = pcall(curr.func, self, curr, diff)
    if not succ then
        print("CLOCK: iERR:", str)
        str = "iERR"
    end
    if done then
        self.curr = nil
    end

    if str then
        buf = self.display:makeBuffer()
        self:printText(buf, pos or 1, str)
    end
    
    return buf
end

function clock:refresh(t)
    node.setcpufreq(node.CPU160MHZ)
    local s = tmr.now()
    
    local buf = self:makeBuffer(t)   
    self.display:writeColumns(buf)

    local e = tmr.now()
    node.setcpufreq(node.CPU80MHZ)
    if hw.debug then
        print(string.format("refresh done in %f ms", (e-s) / 1000))
    end
end

function clock:flush()
    self.curr = nil
end

clock.q = { 
    { function(self,c,d) return "Node" end,                           2, 3000, true, },
    { function(self,c,d) return "MCU",32-17+1 end,                    2, 2000, true, },
    { function(self,c,d) return self:textSwing(c,d, "Welcome") end,  0,  100, true, },
    { clock.printTime,            30, 1000, },
    { clock.printDate,             5, 1000, },
}

M = {}

function M.Init()
    clock.font = loadScript("font-5x7")
    clock.display = loadScript("drv-max7219").setup()
    clock.display.bcastData = nil
    clock.display.setIntensity = nil
    clock.display.shutdown = nil
    tmr.create():alarm(1000, tmr.ALARM_AUTO, function(t) clock:refresh(t) end)
    _G.clock = clock
end

return M
