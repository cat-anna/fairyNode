
local M = { }

function M.Init()
    if hw and hw.telnet then
        loadScript("mod-telnet").Start(hw.telnet)
        hw.telnet = nil
    end
end

return M
