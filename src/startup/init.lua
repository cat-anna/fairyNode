uart.setup(0, 115200, 8, uart.PARITY_NONE, uart.STOPBITS_1, 1)
wifi.setmode(wifi.NULLMODE)

print "===Starting fairyNode==="

node.setcpufreq(node.CPU160MHZ)

local pcall_x = pcall
function pcall(f, ...)
  local succ, r, r1, r2, r3 = pcall_x(f, ...)
  if not succ then
    print("ERROR:", r)
    if SetError then
      SetError("pcall", r)
    end
  end
  return succ, r, r1, r2, r3
end

if file.exists("debug.cfg") then
  debugMode = true
  print("INIT: Debug mode is enabled")
end

if file.exists("ota.ready") then
  print "OTA: New package is ready for installation"
  local ota_installer = require("ota-installer")
  ota_installer.Install()
  return
end


local function CheckRebootCounter()
  if not rtcmem then
    return true
  end

  local value = rtcmem.read32(120)
  if value < 0 or value > 10 then
    rtcmem.write32(120, 1)
    return true
  end
  value = value + 1
  print("INIT: Current reboot counter:", value)


  if value > 8 then
    print("INIT: Reboot threshoold exceeded.")
    print("INIT: Starting in failsafe mode.")
    failsafe = true

    local state = false
    tmr.create():alarm(500, tmr.ALARM_AUTO, function()
      state = not state
      require("sys-led").Set("err", state)
      if tmr.time() > 10 * 60 then
        print("INIT: Failsafe timeout! Resuming normal operation.")
        rtcmem.write32(120, 0)
        node.restart()
      end
    end)
  
    return false
  end
  
  rtcmem.write32(120, value)

  tmr.create():alarm(10 * 60 * 1000, tmr.ALARM_SINGLE, function()
    print("INIT: System is stable for 10min. Clearing reboot counter.")
    rtcmem.write32(120, 0)
  end)

  return true
end

if CheckRebootCounter() then
  pcall(node.flashindex("init-lfs"))
end
pcall(require, "init-hw")

print "INIT: Waiting before entering bootstrap..."
tmr.create():alarm(
  1000,
  tmr.ALARM_SINGLE,
  function(t)
    if abort then
      print "INIT: Bootstrap aborted!"
      abort = nil
      return
    end

    print "INIT: Entering bootstrap..."
    require "init-bootstrap"
    t:unregister()
  end
)
