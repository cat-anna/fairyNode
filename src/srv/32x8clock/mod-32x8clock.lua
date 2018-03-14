local M = { }

function M.addScreen(self, data)
    local l = {
        data.func, 
        data.duration, 
        data.refresh or data.duration * 1000, 
        data.singleTime,
    }
    if data.front then
        table.insert(self.q, 1, l)
    else
        table.insert(self.q, l)
    end
end

return M
