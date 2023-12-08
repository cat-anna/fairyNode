
M = {}

function M.Init()
    local clock = require("32x8clock").StartClock(tmr.create())
    _G.clock = clock
end

return M
