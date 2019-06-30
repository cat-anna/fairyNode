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


if file.exists("lfs.img.pending") then
  print "OTA: Load new lfs..."
  file.remove("lfs.img")
  file.rename("lfs.img.pending", "lfs.img")
  node.flashreload("lfs.img")
  -- in case of error
  file.remove("lfs.img")
  node.restart()
  return
end

pcall(node.flashindex("init-lfs"))
pcall(require, "init-hw")

print "INIT: Waiting before entering bootstrap..."
tmr.create():alarm(
  1000,
  tmr.ALARM_SINGLE,
  function(t)
    if abort then
      print "Bootstrap aborted!"
      abort = nil
      return
    end

    print "INIT: Entering bootstrap..."
    require "init-bootstrap"
    t:unregister()
  end
)
