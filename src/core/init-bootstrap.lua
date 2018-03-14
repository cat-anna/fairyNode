
if loadScript("init-compile", true) then
  print("INIT: Restart is pending. System bootstrap cancelled.")
  return
end

local majorVer, minorVer, devVer, chipid, flashid, flashsize, flashmode, flashspeed = node.info()
print("INIT: NodeMCU version: " .. majorVer .. "." .. minorVer .. "." .. devVer)
print("INIT: Chip id: ", string.format("%06x", chipid))
print("INIT: Flash id: ", string.format("%x", flashid))
print("INIT: Flash size: ", flashsize)
print("INIT: Flash mode: ", flashmode)
print("INIT: Flash speed: ",flashspeed)
print("INIT: bootreason: ", node.bootreason())

loadScript("init-event")
loadScript("init-network")
loadScript("init-log")

local timeout = 1
local function bootstrap(t)
  if abort then
    print "INIT: Initialization aborted!"
    abort = nil
    t:unregister()
    return
  end

  timeout = timeout - 1

  if not wifi.sta.getip() and timeout > 0 then
    return
  end
  
  node.task.post(function() 
    loadScript "init-service"
  end)
  t:unregister()
end

if wifi.getmode() == wifi.STATION then
  print "INIT: Waiting for network connection..."
  tmr.create():alarm(1000, tmr.ALARM_AUTO, bootstrap)
else
  node.task.post(bootstrap)
end
