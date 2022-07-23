local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local StateMovingAvg = {}
StateMovingAvg.__index = StateMovingAvg
StateMovingAvg.__class_name = "StateMovingAvg"
StateMovingAvg.__base = "rule/state-base"
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
        self.cache_id = string.format("%s-%s", self.__class_name, self.global_id)
    end
    return self.cache_id
end

function StateMovingAvg:IsReady()
    return true
end

-------------------------------------------------------------------------------------

function StateMovingAvg:LocallyOwned()
    return true, "float"
end

function StateMovingAvg:GetDescription()
    local r = self.super.GetDescription(self)
    table.insert(r, "Samples: " .. tostring(#self.samples))
    if self.period then
        table.insert(r, "Avg period: " .. string.format_seconds(self.period))
        if #self.samples > 0 then
            local first = self.samples[1]
            local last = self.samples[#self.samples]
            local time_diff = last.timestamp - first.timestamp
            if time_diff ~= self.period then
                table.insert(r, "Current period: " .. string.format_seconds(time_diff))
            end
        end
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

return StateMovingAvg
