-- PCF8591 module for ESP8266 with nodeMCU
-- Written by Sergey Martynov http://martynov.info
-- Based on http://www.nxp.com/documents/data_sheet/PCF8591.pdf
-- modiffied by pgrabas

-- On YL-40 board
-- 0 = photoresistor
-- 1 = 255 - pulled up ??
-- 2 = thermistor ??
-- 3 = variable resistor

local moduleName = ...
_G[moduleName] = nil

-- read data register
-- reg_addr: address of the register
-- lenght: bytes to read
local function read_reg(reg_addr, length, addr)
  i2c.start(0)
  i2c.address(0, addr, i2c.TRANSMITTER)
  i2c.write(0, reg_addr)
  i2c.stop(0)
  i2c.start(0)
  i2c.address(0, addr, i2c.RECEIVER)
  local c = i2c.read(0, length)
  i2c.stop(0)
  return c
end

-- write data register
-- reg_addr: address of the register
-- reg_val: value to write to the register
local function write_reg(reg_addr, reg_val, addr)
  i2c.start(0)
  i2c.address(0, addr, i2c.TRANSMITTER)
  i2c.write(0, reg_addr)
  i2c.write(0, reg_val)
  i2c.stop(0)
end

return {
-- XXX read adc register 0 to 3
  adc = function(reg, addr)
    addr = addr or 0x48
    local data = read_reg(0x00 + reg, 2, addr)
    return string.byte(data, 2)
  end,
-- XXX write dac register
  dac = function(val, addr)
    addr = addr or 0x48
    return write_reg(0x40, val, addr)
  end,
}