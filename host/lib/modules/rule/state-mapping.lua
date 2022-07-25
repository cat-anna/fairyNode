-- local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local StateMapping = {}
StateMapping.__index = StateMapping
StateMapping.__base = "rule/state-base"
StateMapping.__class_name = "StateMapping"
StateMapping.__type = "class"

-------------------------------------------------------------------------------------

function StateMapping:Init(config)
    self.super.Init(self, config)
    self.mapping = config.mapping
    self.result_type = config.result_type
    self.mapping_mode = config.mapping_mode
end

-------------------------------------------------------------------------------------

function StateMapping:LocallyOwned()
    return true, self.result_type
end

function StateMapping:CalculateValue(dependant_values)
    if #dependant_values ~= 1 then
        print(self:Tag(),
              "Mapping requires exactly single dependency, but got " ..
                  tostring(#dependant_values))
        return
    end

    local foreign_value = dependant_values[1]
    if foreign_value == nil then
        print(self:Tag(), "Mapping does not have value")
        return
    end

    return self:WrapCurrentValue(
        self.mapping[foreign_value.value],
        foreign_value.timestamp
    )
end

-------------------------------------------------------------------------------------

return StateMapping
