
local tablex = require "pl.tablex"
local pretty = require "pl.pretty"

-------------------------------------------------------------------------------------

local StateFunction = {}
StateFunction.__index = StateFunction
StateFunction.__name = "StateFunction"
StateFunction.__base = "state/state-base"
StateFunction.__type = "class"

-------------------------------------------------------------------------------------

function StateFunction:Init(config)
    self.super.Init(self, config)

    self.errors = {}
    if config.setup_errors then
        config.setup_errors(function() return self:Tag() end, self.errors)
    end

    self.func = config.func
    self.funcG = config.funcG
    self.object = config.object
    self.info_func = config.info_func
    self.result_type = config.result_type
end

-------------------------------------------------------------------------------------

function StateFunction:LocallyOwned()
    return true
end

function StateFunction:GetDatatype()
    return self.result_type
end

function StateFunction:GetDescription()
    local r = self.super.GetDescription(self)

    if self.info_func then
        local call_result = { pcall(self.info_func, self.object) }
        if call_result[1] then
            for _, v in ipairs(call_result[2] or {}) do
                table.insert(r, v)
            end
        end
    end

    return r
end

function StateFunction:CalculateValue(dependant_values)
    local input = { }
    local call_args = { self.object, input }
    for _, v in ipairs(dependant_values) do
        if v.source_id then
            input[v.source_id] = v.value
        else
            table.insert(call_args, v.value)
        end
    end

    local result = {
        pcall(self.func, table.unpack(call_args))
    }
    if not result[1] then
        self:SetError("Execution failed: %s", result[2])
        return
    end

    return self:WrapCurrentValue(result[2])
end

function StateFunction:OnTimer()
    self:Update()
end

-------------------------------------------------------------------------------------

return StateFunction
