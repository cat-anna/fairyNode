------------------------------------------------------------------------------

local function FilterPropertyValues(values)
    local max_delta = 10*60 -- 10min

    local r = {}

    local start_timestamp = nil
    local end_timestamp = nil
    local value_sum = 0
    local value_count = 0


    for i,v in ipairs(values) do
        if start_timestamp == nil then
            start_timestamp = v.timestamp
            end_timestamp = v.timestamp
            value_sum = v.value
            value_count = 1
        else
            local delta_timestamp = v.timestamp - start_timestamp
            if delta_timestamp > max_delta then
                table.insert(r, {
                    timestamp = start_timestamp + math.floor((end_timestamp - start_timestamp) / 2),
                    value = value_sum / value_count,
                    avg = true,
                })
                start_timestamp = v.timestamp
                end_timestamp = v.timestamp
                value_sum = v.value
                value_count = 1
            else
                end_timestamp = v.timestamp
                value_sum = value_sum + v.value
                value_count = value_count + 1
            end
        end
    end

    return r
end

function HomieRemoteDevice:PushPropertyHistory(node, property, value, timestamp)
    local id = self:GetHistoryId(node, property.id)
    if not self.history[id] then
        self.history[id] =  self.server_storage:GetFromCache(id) or {
            values = {}
        }
    end

    local prop_id = self:GetFullPropertyName(node, property.id)
    local additional_handlers = self.AdditionalHistoryHandlers[prop_id]
    if type(additional_handlers) == "table" then
        for _,handler in ipairs(additional_handlers) do
            SafeCall(function()
                handler(self, node, property, value, timestamp)
            end)
        end
    end

    local history = self.history[id]

    if #history.values > 0 then
        local last_node = history.values[#history.values]
        if last_node.value == value or last_node.timestamp == timestamp then
            return
        end
    end

    table.insert(history.values, {value = value, timestamp = timestamp})

    -- while #history.values > 10000 do
    --     table.remove(history.values, 1)
    -- end

    -- if self.datatype == "float" then
    --     self.history.values_filtered = FilterPropertyValues(history.values)
    -- end

    self.server_storage:UpdateCache(id, history)
end

function HomieRemoteDevice:AppendErrorHistory(node, property, value, timestamp)
    print(self,string.format("error state changed to '%s'", value))
    self.active_errors = self.active_errors or {}

    local device_errors = json.decode(value)

    local add_entry = function(operation, key, value)
        key = key or "<nil>"
        value = json.encode(value or "")
        print(self,string.format("%s error %s=%s", operation, key, value))
    end

    local new_active_errors = {}

    for k,v in pairs(self.active_errors) do
        --remove errors that are still active
        local error_value = device_errors[k]
        if error_value[k] == v then
            device_errors[k] = nil
            new_active_errors[k]=v
        else
            if error_value then
                add_entry("changed", k, error_value)
                new_active_errors[k]=error_value
                device_errors[k] = nil
            else
                add_entry("removed", k)
            end
        end
    end

    for k,v in pairs(device_errors) do
        add_entry("new", k, v)
    end

    self.active_errors = new_active_errors
end

function HomieRemoteDevice:GetHistory(node_name, property_name)
    local id = self:GetHistoryId(node_name, property_name)
    local history = self.history[id]
    if history then
        -- if history.values_filtered then
            -- return history.values_filtered
        -- end
        -- return FilterPropertyValues(history.values)
        return history.values
    end
end

function HomieRemoteDevice:Delete(external)
    if self.deleting then
        return
    end
    printf(self,"Deleting device %s", self.name)

    local sequence = {
        function ()
            self.event_bus:PushEvent({
                event = "homie-host.device.delete.start",
                device = self.name,
            })
        end,
        function ()
            if not external then
                self:Publish("/$state", "lost", true)
            end
        end,
        function () self.mqtt:StopWatching(self) end,
        function ()
            if not external then
                self:Publish("/$homie", "", true)
            end
        end,
        function ()
            for _,n in pairs(self.nodes) do
                for _,p in pairs(n.properties or {}) do
                   p.value = nil
                   p:CallSubscriptions()
                end
            end
        end,
        function ()
            if not external then
                print(self,"Starting topic clear")
                self:WatchRegex("/#", self.HandleTopicClear)
            end
        end,
        function () end,
        function ()
            self.event_bus:PushEvent({
                event = "homie-host.device.delete.finished",
                device = self.name,
            })
        end,
        function ()
            self.deleting = true
            self:ReleaseSubscriptions()
            self.host:FinishDeviceRemoval(self.name)
        end,
    }

    self.deleting = scheduler:CreateTaskSequence(self, "deleting device", 1, sequence)
end

function HomieRemoteDevice:HandleTopicClear(topic, payload)
    payload = payload or ""
    if payload ~= "" then
        print(self,"Clearing: " .. topic .. "=" .. payload)
        self.mqtt:Publish(topic, "", true)
    end
end

