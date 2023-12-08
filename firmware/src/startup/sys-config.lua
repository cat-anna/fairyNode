
local mod = {}

function mod.Read(fname)
  if not file.exists(fname) then
    print("Config.JSON error:", fname, b)
    return nil
  end
  
  local fd = file.open(fname, "r")
  local data = fd:read()
  fd:close()

  return data
end

function mod.JSON(fname)
  local data = mod.Read(fname)
  if not data then
    return nil
  end
  
  local succ, b = pcall(sjson.decode,data)
  if succ then
    return b
  else
    print("Config.JSON error:", fname, b)
    return nil
  end
end

return mod
