local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local StateMovingAvg = {}
StateMovingAvg.__name = "StateMovingAvg"
StateMovingAvg.__base = "state/state-base"
StateMovingAvg.__type = "class"
StateMovingAvg.__deps = {
    server_storage = "base/server-storage",
}

-------------------------------------------------------------------------------------

function StateMovingAvg:Init(config)
    self.super.Init(self, config)

    self.samples =  {}
    local cache = self.server_storage:GetFromCache(self:CacheId())
    if cache then
        self.samples = cache.samples or { }
    end

    self.period = config.period
end

function StateMovingAvg:CacheId()
    if not self.cache_id then
        self.cache_id = string.format("%s-%s", self.__name, self.global_id)
    end
    return self.cache_id
end

function StateMovingAvg:IsReady()
    return true
end

-------------------------------------------------------------------------------------

function StateMovingAvg:LocallyOwned()
    return true
end

function StateMovingAvg:GetDatatype()
    return "float"
end

function StateMovingAvg:GetDescription()
    local r = self.super.GetDescription(self)
    table.insert(r, "Samples: " .. tostring(#self.samples))
    if self.period then
        if #self.samples > 0 then
            local first = self.samples[1]
            local last = self.samples[#self.samples]
            local time_diff = last.timestamp - first.timestamp
            if time_diff ~= self.period then
                table.insert(r, "Period: " .. string.format_seconds(time_diff))
            end
        end
        table.insert(r, "Target period: " .. string.format_seconds(self.period))
    end
    return r
end

function StateMovingAvg:PushSample(sample)
    local add = true
    if #self.samples > 0 then
        local last = self.samples[#self.samples]
        if last.timestamp == sample.timestamp then
            add = false
        end
    end
    if add then
        table.insert(self.samples, {
            timestamp = sample.timestamp,
            value = sample.value,
        })
    end

    local any_change = add
    if self.period ~= nil then
        local current = os.gettime()
        while #self.samples > 0 and current - self.samples[1].timestamp > self.period do
            table.remove(self.samples, 1)
            any_change = true
        end
    end

    return any_change
end

function StateMovingAvg:SourceChanged(source, source_value)
    if self:PushSample(source_value) then
        self:RetireValue()
        self:SaveCache()
        self:Update()
    end
end

function StateMovingAvg:CalculateValue(dependant_values)
    if dependant_values then
        self:PushSample(dependant_values[1])
    end

    local sum = 0
    for _,v in pairs(self.samples) do
        sum = sum + v.value
    end

    local count = #self.samples
    if count == 0 then
        return 0
    end

    return self:WrapCurrentValue(sum / count, self.samples[count].timestamp)
end

function StateMovingAvg:SaveCache()
    local cache = { samples = self.samples }
    self.server_storage:UpdateCache(self:CacheId(), cache)
end

-------------------------------------------------------------------------------------

function StateMovingAvg.RegisterStateClass()
    -- local state_prototypes = { }
    -- for k,v in pairs(StateMovingAvg.OperatorFunctors) do
    --     state_prototypes[k] = {
    --         remotely_owned = false,
    --         config = {
    --             operator = k
    --         },
    --         args = {
    --             min = v.arg_min or 1,
    --             max = v.arg_max or 10,
    --         },
    --     }
    -- end

    -- state_prototype.MovingAvg = MakeMovingAvg(env)
    -- local function MakeMovingAvg(env)
    --     return function(data)
    --         if not IsState(env, data[1]) then
    --             env.error("MovingAvg operator state as first argument")
    --             return
    --         end
    --         if type(data.period) ~= "number" then
    --             env.error("MovingAvg operator requires numeric 'period' argument")
    --             return
    --         end
    --         return MakeStateRule {
    --             source_dependencies = {data[1]},
    --             class = StateClassMapping.StateMovingAvg,
    --             period = data.period
    --         }
    --     end
    -- end

    -- return {
    --     meta_operators = { },
    --     state_prototypes = state_prototypes,
    --     state_accesors = { }
    -- }
end


-------------------------------------------------------------------------------------

return StateMovingAvg
