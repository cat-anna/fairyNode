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

function dev:DisplayBuffer(v)
  local str = string.rep(string.char(v or 0), self.modules * 8)
  return { str:byte(1, -1) }
end

function dev:BcastData(register, data)
  local ss = self.ss
  gpio.write(ss, gpio.LOW)
  for i = 1, self.modules do
    spi.send(1, register * 256 + data)
  end
  gpio.write(ss, gpio.HIGH)
end

function dev:Clear()
  self:Commit(self:DisplayBuffer())
end

function dev:Commit(bytes)
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
function dev:SetIntensity(intensity)
  self:BcastData(MAX7219_REG_INTENSITY, intensity)
end

-- shutdown: true=turn off, false=turn on
function dev:Shutdown(shutdown)
  local shutdownReg = shutdown and 0 or 1
  self:BcastData(MAX7219_REG_SHUTDOWN, shutdownReg)
end  

function dev:WriteColumns(columns)
  for i = 1, self.modules do
    rotate(columns, (i - 1) * 8 +1)
  end
  self:Commit(columns)
end

local M = {}

-- Configures both the SoC and the MAX7219 modules.
-- @param config table with the following keys (* = mandatory)
--               - numberOfModules*
--               - slaveSelectPin*, ESP8266 pin which is connected to CS of the MAX7219
--               - intensitiy, 0x00 - 0x0F (0 - 15)
function M.Setup(config)
  if not config and hw and hw.max7219 then
    config = hw.max7219
    hw.max7219 = nil
  end
  local config = config or {}
  local device = dev--setmetatable({}, { __index == dev })

  -- use 0 as default intensity if not configured
  config.intensity = config.intensity and config.intensity or 0

  device.modules = assert(config.modules, "'modules' is a mandatory parameter")
  device.ss = assert(config.ss, "'ss' is a mandatory parameter")

  print("MAX2719: number of modules: " .. device.modules .. ", SS pin: " .. device.ss)

  spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 16, 8)
  -- Must NOT be done _before_ spi.setup() because that function configures all HSPI* pins for SPI. Hence,
  -- if you want to use one of the HSPI* pins for slave select spi.setup() would overwrite that.
  gpio.mode(device.ss, gpio.OUTPUT)
  gpio.write(device.ss, gpio.HIGH)

  device:BcastData( MAX7219_REG_SCANLIMIT, 7)
  device:BcastData( MAX7219_REG_DECODEMODE, 0x00)
  device:BcastData( MAX7219_REG_DISPLAYTEST, 0)
  device:BcastData( MAX7219_REG_INTENSITY, config.intensity)
  device:BcastData( MAX7219_REG_SHUTDOWN, 1)
  device:Clear(device)
  
  return device
end

return M
