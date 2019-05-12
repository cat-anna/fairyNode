
local m = { }
local file = require "pl.file"

function m.GetFile(fname)
    local fn
    local del 

    if fname == "speach" then
        fn = os.tmpname() 
        os.remove(fn)
        fn = fn .. ".u8"
        del = true
        os.execute([[espeak --stdout "it is 06:10" | sox -t wav - -r 16000 -b 8 -c 1 ]] .. fn)
    else
        fn = "files/" .. fname
    end
    local data = file.read(fn) or ""
    if del then
        os.remove(fn)
    end
    print("FILE: " .. fn .. " size: " .. tostring(#data))
    return data
end

return m