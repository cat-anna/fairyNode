local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local StateChangeGenerator = {}
StateChangeGenerator.__name = "StateChangeGenerator"
StateChangeGenerator.__base = "state/state-base"
StateChangeGenerator.__type = "class"

-------------------------------------------------------------------------------------

function StateChangeGenerator:Init(config)
    StateChangeGenerator.super.Init(self, config)

    self.datatype = "boolean"

    self.last_value = false
    self.interval = config.interval or 30
    self.update_task = self:AddTask("Update task", self.interval, self.Toggle)
    self:Toggle()
end

-------------------------------------------------------------------------------------

function StateChangeGenerator:Toggle()
    self.last_toggle = os.timestamp()
    self.last_value = not self.last_value
    self:SetCurrentValue(self:WrapCurrentValue(self.last_value, self.last_toggle))
end

function StateChangeGenerator:LocallyOwned()
    return true
end

function StateChangeGenerator:GetDescription()
    local r = StateChangeGenerator.super.GetDescription(self)
    table.insert(r, string.format("Interval: %ds", self.interval))
    table.insert(r, string.format("Remain: %.1fs", self.interval - (os.timestamp() - self.last_toggle)))
    return r
end

function StateChangeGenerator:CalculateValue()
end

function StateChangeGenerator:Update()
end

-------------------------------------------------------------------------------------

function StateChangeGenerator.RegisterStateClass()
    return {
        meta_operators = { },
        state_prototypes = {
            ChangeGenerator = {
                remotely_owned = false,
                config = { },
                args = { min = 0, max = 0, },
            },
        },
        state_accesors = { }
    }
end

-------------------------------------------------------------------------------------

return StateChangeGenerator
