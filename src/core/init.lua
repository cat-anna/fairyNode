uart.setup(0, 115200, 8, uart.PARITY_NONE, uart.STOPBITS_1, 1)
wifi.setmode(wifi.NULLMODE)

function loadScript(name)
  for _,v in ipairs({"lc", "lua"}) do
    local s = tmr.now()
    local r, mod = pcall(dofile, name .. ".lc")    
    if r then 
      print(string.format("LOADED: %s.%s [done in %f ms]", name, v, (tmr.now()-s)/1000))
      return mod
    end
  end  
  return nil
end

pcall(loadScript, "init-hw")

print "INIT: Waiting before entering bootstrap..."
tmr.create():alarm(1000, tmr.ALARM_SINGLE, function(t)
    if abort then
      print "Bootstrap aborted!"
      abort = nil
      return
    end

    print "INIT: Entering bootstrap..."
    loadScript "init-bootstrap"
    t:unregister() 
  end)
