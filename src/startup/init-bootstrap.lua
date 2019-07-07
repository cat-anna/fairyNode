
-- if loadScript("init-compile", true) then
--   print("INIT: Restart is pending. System bootstrap cancelled.")
--   return
-- end

local majorVer, minorVer, devVer, chipid, flashid, flashsize, flashmode, flashspeed = node.info()
print("INIT: NodeMCU version: " .. majorVer .. "." .. minorVer .. "." .. devVer)
print("INIT: Chip id: ", string.format("%06X", chipid))
print("INIT: Flash id: ", string.format("%X", flashid))
print("INIT: Flash size: ", flashsize)
print("INIT: Flash mode: ", flashmode)
print("INIT: Flash speed: ", flashspeed)
print("INIT: bootreason: ", node.bootreason())
local s, t = pcall(require, "lfs-timestamp")
if s then
  print("INIT: lfs-timestamp: ", t)
end

pcall(require, "init-error")
pcall(require, "init-event")
require("init-network")

-- require("init-log")

local timeout = 5
local function bootstrap(t)
  if abort then
    print "INIT: Initialization aborted!"
    abort = nil
    if t then t:unregister() end
    return
  end

  timeout = timeout - 1

  if not wifi.sta.getip() and timeout > 0 then
    return
  end

  if t then 
    t:unregister()
  end 

  node.task.post(function() pcall(require, "init-service") end)
end

if wifi.getmode() == wifi.STATION then
  print "INIT: Waiting for network connection..."
  tmr.create():alarm(10 * 1000, tmr.ALARM_AUTO, bootstrap)
else
  node.task.post(bootstrap)
end
