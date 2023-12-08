
-------------------------------------------------------------------------------------

local StateTime = {}
StateTime.__index = StateTime
StateTime.__name = "StateTime"
StateTime.__type = "class"
StateTime.__base = "state/state-base"

-------------------------------------------------------------------------------------

function StateTime:Init(config)
    self.super.Init(self, config)
end

-------------------------------------------------------------------------------------

function StateTime:LocallyOwned()
    return true
end

function StateTime:GetDatatype()
    return "boolean"
end

function StateTime:GetName()
    local r = self:DescribeSourceValues()
    if #r ~= 2 then
        self:SetError("Invalid argument count for Time rule")
        return "<error>"
    end

    local function fmt(x)
        if type(x) == "number" then
            return string.format("%02d:%02d", math.floor(x / 100), math.floor(x % 100))
        else
            return tostring(x)
        end
    end

    local from = fmt(r[1])
    local to = fmt(r[2])

    return string.format("Time between\\n%s and %s", from, to)
end

function StateTime:CalculateValue(dependant_values)
    if #dependant_values ~= 2 then
        self:SetError("Invalid argument count")
        return "<error>"
    end

    local from = dependant_values[1].value
    local to = dependant_values[2].value

    local current_time = os.date("*t", os.time())
    local time = (current_time.hour * 100) + current_time.min

    local result
    if from < to then
        result = (from <= time) and (time < to)
    else
        result = (time < from) or (to >= time)
    end
    return self:WrapCurrentValue(result)
end

-------------------------------------------------------------------------------------

function StateTime.RegisterStateClass()
    return {
        meta_operators = {},
        state_prototypes = {
            TimeSchedule = {
                remotely_owned = false,
                config = { },
                args = {
                    min = 2,
                    max = 2,
                },
            },
        },
        state_accesors = { }
    }
end

-------------------------------------------------------------------------------------

return StateTime
