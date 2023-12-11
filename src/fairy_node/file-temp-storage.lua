

local dir = require "pl.dir"
local path = require "pl.path"
local file = require "pl.file"

local tmp = { }

function tmp:AddFile(name, content)
    if not self.basePath then
        local base = os.tmpname()
        os.remove(base)
        dir.makepath(base)
        self.basePath = base
        self.list = { }
    end

    local full = self.basePath .. "/" .. name
    if content then
        file.write(full, content)
    end

    table.insert(self.list, full)
    return full
end

function tmp:Clear() 
    self.list = nil
    if self.basePath then
        dir.rmtree(self.basePath)
        self.basePath = nil
    end
end

return {
    new = function() 
        return setmetatable({
            list = { },
        }, { __index = tmp })
    end
}
