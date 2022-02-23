local tablex = require "pl.tablex"

local StateFunction = {}
StateFunction.__index = StateFunction
StateFunction.__class = "StateFunction"

function StateFunction:LocallyOwned() return true, self.result_type end

-- function StateFunction:GetName()
--     local r = self.range
--     return string.format("Time between %d:%02d and %d:%02d", r.from / 100,
--                          r.from % 100, r.to / 100, r.to % 100)
-- end

function StateFunction:GetDescription()
    local r = self.BaseClass.GetDescription(self)
    if self.info_func then
        local call_result = {pcall(self.info_func, self.object)}
        if call_result[1] then
            for _, v in ipairs(call_result[2] or {}) do
                table.insert(r, v)
            end
        end
    end
    -- table.insert(r, "Max change period: " .. string.format_seconds(self.delay))
    return r
end

function StateFunction:GetValue() return self.cached_value end

function StateFunction:SourceChanged(source, source_value) self:Update() end

function StateFunction:RetireValue()
    self.last_update_timestamp = nil
    self.cached_value = nil
end

function StateFunction:Update()
    -- if self.delay == nil then
    -- return
    -- end
    local current = os.time()
    -- if current - (self.last_update_timestamp or 0) < self.delay then
    --     return
    -- end

    local dependant_values = self:GetDependantValues()
    if not dependant_values then return end

    local input = {}
    local call_args = {self.object, input}
    for _, v in ipairs(dependant_values) do
        if v.source_id then
            input[v.source_id] = v.value
        else
            table.insert(call_args, v.value)
        end
    end

    local result = {pcall(self.func, table.unpack(call_args))}

    local call_success = result[1]
    if not call_success then
        self:RetireValue()
        print(self:LogTag(), "Execution failed:", result[2])
        return false
    end

    local new_value = result[2]
    if self.cached_value == nil or self.cached_value ~= new_value then
        self.last_update_timestamp = current
        self.cached_value = new_value
        self.result_type = type(new_value)
        print(self:LogTag(), "Changed to value " .. tostring(new_value))
        self:CallSinkListeners(new_value)
    end

    return true
end

function StateFunction:IsReady()
    return self.ready
end

function StateFunction:Create(config)
    self.BaseClass.Create(self, config)

    self.errors = {}
    config.setup_errors(function() return self:LogTag() end, self.errors)

    self.func = config.func
    self.funcG = config.funcG
    self.object = config.object
    self.dynamic = config.dynamic
    self.info_func = config.info_func
    self.ready = true
end

function StateFunction:OnTimer(config) if self.dynamic then self:Update() end end

return {
    Class = StateFunction,
    BaseClass = "State",

    __deps = {class_reg = "state-class-reg", state = "state-base"},

    AfterReload = function(instance)
        local BaseClass = instance.state.Class
        StateFunction.BaseClass = BaseClass
        setmetatable(StateFunction, {__index = BaseClass})
        instance.class_reg:RegisterStateClass(StateFunction)
    end
}
