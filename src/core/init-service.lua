
local function loadService(name)
  local success = false
  local begheap = node.heap()
  local m = loadScript(name, true)
  if m then
    m.Init()
  end 
  collectgarbage()
  local endheap = node.heap()
  if not m then
    print("SRV: Failed to load: ", name)
  else
    success = true
  end
  m = nil
  print(string.format([[SRV: MODULE: %-20s Loaded:%s MemoryUsed:%d (%d->%d)]], 
    name, (success and "Y" or "N"), begheap-endheap, begheap, endheap))
end

local function moduleList(modtype)
  local ret = { }
  for k,_ in pairs(file.list()) do
    local ftype, name = k:match("(%w+)%-(%w+)%.l..?")

    if ftype and name and ftype == modtype then
      ret[#ret + 1] = ftype .. "-" .. name
    end
  end
  return ret
end

local function InitService()
  if abort then
    print "SRV: Service initialization aborted!"
    return
  end
  
  print "SRV: Loading services"
  for _,v in ipairs(moduleList("srv")) do
    loadService(v)
  end

  node.task.post(function()
    loadScript("init-user")
  end)

  print "INIT: Ready"
  print "Welcome to fairyNode"
end

print "SRV: Waiting before services initialization..."
tmr.create():alarm(1000, tmr.ALARM_SINGLE, InitService)
