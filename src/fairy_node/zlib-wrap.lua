local zlib = require "zlib"

local zlib_wrap = { }

function zlib_wrap.compress(data)
    if zlib.compress then
        return zlib.compress(data)
    end

    local compress = zlib.deflate()
    return compress(data, "finish")
end

return zlib_wrap
