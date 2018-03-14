--------------------------------------------------------------------------------
-- MAX7229 module for NodeMCU
-- SOURCE: https://github.com/marcelstoer/nodemcu-max7219
-- AUTHOR: marcel at frightanic dot com
-- LICENSE: http://opensource.org/licenses/MIT
-- modiffied by pgrabas
--------------------------------------------------------------------------------

local MAX7219_REG_DECODEMODE = 0x09
local MAX7219_REG_INTENSITY = 0x0A
local MAX7219_REG_SCANLIMIT = 0x0B
local MAX7219_REG_SHUTDOWN = 0x0C
local MAX7219_REG_DISPLAYTEST = 0x0F

local function rotate(columns, start)
  local band = bit.band
  local bor = bit.bor
  local lshift = bit.lshift

  local o = { 0,0,0,0, 0,0,0,0, }
    
  for i=0,7 do
    local pos = lshift(1, i)
    local c = columns[start + (7 - i)] or 0
    for n=0,7 do
      local mask = lshift(1, n)
      if band(mask, c) > 0 then o[n+1] = bor(o[n+1], pos) end
    end
  end

  for n=0,7 do
    columns[start + n] = o[n+1]
  end
end

local dev = { }

function dev:makeBuffer(v)
  local str = string.rep(string.char(v or 0), self.modules * 8)
  return { str:byte(1, -1) }
end

function dev:bcastData(register, data)
  local ss = self.ss
  gpio.write(ss, gpio.LOW)
  for i = 1, self.modules do
    spi.send(1, register * 256 + data)
  end
  gpio.write(ss, gpio.HIGH)
end

function dev:clear()
  self:commit(self:makeBuffer())
end

function dev:commit(bytes)
  local lines = 8
  local num = self.modules
  local ss = self.ss
  
  for i=1,lines do 
    gpio.write(ss, gpio.LOW)
    for d=1,num do
      local c = (d-1)*lines + i
      spi.send(1, i*256 + bytes[c]) 
    end
    gpio.write(ss, gpio.HIGH)
  end  
end

-- intensity: 0x00 - 0x0F (0 - 15)
function dev:setIntensity(intensity)
  self:bcastData(MAX7219_REG_INTENSITY, intensity)
end

-- shutdown: true=turn off, false=turn on
function dev:shutdown(shutdown)
  local shutdownReg = shutdown and 0 or 1
  self:bcastData(MAX7219_REG_SHUTDOWN, shutdownReg)
end  

function dev:writeColumns(columns)
  for i = 1, self.modules do
    rotate(columns, (i - 1) * 8 +1)
  end
  self:commit(columns)
end

return dev
