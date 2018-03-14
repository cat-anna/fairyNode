
print("COMPILE: Looking for scripts to compile...")
local sthCompiled
for fn,s in pairs(file.list()) do
    tmr.wdclr()
    local rawname = fn:match("(.+)%.lua")
    if rawname and rawname ~= "init" then
        print("COMPILE: Compiling " .. rawname)
        local compiled = rawname .. ".lc"
        node.compile(fn)        
        local stat = file.stat(compiled)
        if not stat then
            print("COMPILE: Failure during compilation of " .. rawname)
        else
            sthCompiled = true
            local diff = stat.size - s
            file.remove(fn)
            print(string.format("COMPILE: Compiled: %s size: %s%d bytes", rawname, (diff > 0) and "+" or "", diff)) 
        end
    end
end

if sthCompiled then
    print("COMPILE: Compilation is done")
    -- print("COMPILE: Removing compilation script")
    -- file.remove("init-compile.lua")
    print("COMPILE: Restarting...")
    node.restart()
else
    print("COMPILE: Nothing to compile. Continuing boot")
end

return sthCompiled
