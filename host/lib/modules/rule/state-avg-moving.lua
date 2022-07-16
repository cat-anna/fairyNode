local tablex = require "pl.tablex"

local StateMovingAvg = {}
StateMovingAvg.__index = StateMovingAvg
StateMovingAvg.__class = "StateMovingAvg"

function StateMovingAvg:LocallyOwned()
    return true, self.result_type
end

-- function StateMovingAvg:GetName()
--     local r = self.range
--     return string.format("Time between %d:%02d and %d:%02d", r.from / 100,
--                          r.from % 100, r.to / 100, r.to % 100)
-- end

function StateMovingAvg:GetDescription()
    local r = self.BaseClass.GetDescription(self)
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

function StateMovingAvg:GetValue()
    if self.cached_value == nil then
        self:Update()
    end
    return self.cached_value
end

function StateMovingAvg:SourceChanged(source, source_value)
    local timestamp = os.time()
    local add_entry = true
    if #self.samples > 0 then
        local last = self.samples[#self.samples]
        if last.timestamp == timestamp then
            last.value = source_value
            add_entry= false
        end
    end
    if add_entry then
        table.insert(self.samples, {
            timestamp = timestamp,
            value = source_value,
        })
    end
    self:RetireValue()
    self:SaveCache()
    self:Update()
end

function StateMovingAvg:RetireValue()
    self.cached_value = nil
end

function StateMovingAvg:SaveCache()
    local cache_id = self.global_id
    self.cache:UpdateCache(self.global_id, {samples=self.samples})
end

function StateMovingAvg:Update()
    if self.period ~= nil then
        local current = os.time()
        while #self.samples > 0 and current - self.samples[1].timestamp > self.period do
            table.remove(self.samples, 1)
        end
    end

    local sum=0
    for _,v in pairs(self.samples) do
        sum = sum + v.value
    end

    local new_value = 0
    if #self.samples > 0 then
        new_value= sum / (#self.samples)
    end
    if new_value ~= self.cached_value then
        self.cached_value = new_value
        self:CallSinkListeners(self.cached_value)
    end
    return true
end

function StateMovingAvg:IsReady()
    return true
end

function StateMovingAvg:Create(config)
    self.samples =  {}
    local cache = self.cache:GetFromCache(self.global_id)
    if cache then
        self.samples = cache.samples or { }
    end

    self.BaseClass.Create(self, config)
    self.period = config.period
    self:RetireValue()
end

return {
    Class = StateMovingAvg,
    BaseClass = "State",

    __deps = {class_reg = "state-class-reg", state = "state-base"},

    AfterReload = function(instance)
        local BaseClass = instance.state.Class
        StateMovingAvg.BaseClass = BaseClass
        setmetatable(StateMovingAvg, {__index = BaseClass})
        instance.class_reg:RegisterStateClass(StateMovingAvg)
    end
}
