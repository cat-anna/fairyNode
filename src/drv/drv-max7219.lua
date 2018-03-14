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

local function makeDevClass(useproxy)
  local d = { }

  function d:makeBuffer(v)
    local str = string.rep(string.char(v or 0), self.modules * 8)
    return { str:byte(1, -1) }
  end

  if useproxy then
    function d:bcastData(register, data)
      return loadScript("dev-max7219").bcastData(self, register, data)
    end

    function d:clear()
      return loadScript("dev-max7219").clear(self)
    end

    function d:commit()
      return loadScript("dev-max7219").commit(self)
    end

    -- intensity: 0x00 - 0x0F (0 - 15)
    function d:setIntensity(intensity)
      return loadScript("dev-max7219").setIntensity(self, intensity)
    end

    -- shutdown: true=turn off, false=turn on
    function d:shutdown(shutdown)
      return loadScript("dev-max7219").shutdown(self, shutdown)
    end  

    function d:writeColumns(columns)
      return loadScript("dev-max7219").writeColumns(self, columns)
    end
  end

  return d
end

local drv = { }

-- Configures both the SoC and the MAX7219 modules.
-- @param config table with the following keys (* = mandatory)
--               - numberOfModules*
--               - slaveSelectPin*, ESP8266 pin which is connected to CS of the MAX7219
--               - debug
--               - intensitiy, 0x00 - 0x0F (0 - 15)
function drv.setup(config)
  if not config and hw and hw.max7219 then
    config = hw.max7219
    hw.max7219 = nil
  end
  local config = config or {}
  local device = makeDevClass(config.lightClient)

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

  local dimpl = loadScript("dev-max7219")
  dimpl.bcastData(device, MAX7219_REG_SCANLIMIT, 7)
  dimpl.bcastData(device, MAX7219_REG_DECODEMODE, 0x00)
  dimpl.bcastData(device, MAX7219_REG_DISPLAYTEST, 0)
  dimpl.bcastData(device, MAX7219_REG_INTENSITY, config.intensity)
  dimpl.bcastData(device, MAX7219_REG_SHUTDOWN, 1)
  
  if not config.lightClient then
    device.commit = dimpl.commit
    device.clear = dimpl.clear
    device.writeColumns = dimpl.writeColumns
    device.bcastData = dimpl.bcastData
    device.setIntensity = dimpl.setIntensity
    device.shutdown = dimpl.shutdown
  end

  dimpl.clear(device)
  
  return device
end

return drv
