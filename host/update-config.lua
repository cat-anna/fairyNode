#!/usr/bin/lua

function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
 end

function string:trim()
    return self:match "^%s*(.-)%s*$"
end

local copas = require "copas"
local lapp = require 'pl.lapp'
local path = require "pl.path"
local dir = require "pl.dir"
local json = require("json")
local baseDir = path.abspath(path.normpath(path.dirname(arg[0]) .. "/.."))
package.path = package.path .. ";" .. baseDir .. "/host/?.lua"

local shell = require "lib/shell"

local node_tool_exec = "nodemcu-tool"

local args = lapp [[
Update device configuration using mqtt
    --device (string)                       device to update
]]

for k,v in pairs(args) do
    print(k .."=" .. tostring(v or "<NIL>"))
end

firmware = {
    baseDir = baseDir .. "/"
}
 
local cfg = {
    baseDir = baseDir .. "/"
}

function LoadScript(name)
    return dofile(cfg.baseDir .. name)
end

local Chip = require("lib/chip")
local chip = Chip.GetChipConfigByName(args.device)
local project = chip:LoadProjectConfig()

-- print(chip.name, chip.id)

local mqtt = require("mqtt")

local client = mqtt.client{
	uri = chip.config.mqtt.host,
	username = chip.config.mqtt.user,
	password = chip.config.mqtt.password,
	clean = true,
}

local mqttloop = mqtt:get_ioloop()
mqttloop:add(client)

copas.addthread(function()
    while true do
        mqttloop:iteration()
        copas.sleep(0.1)
    end 
end)

local deviceStatus = {
    client = client,
    name = chip.name,
    active = 10,
    project = project,
    lastConfigValues = {}
}

copas.addthread(function()
    copas.sleep(5)
    while deviceStatus:IsActive() do
        copas.sleep(1)
    end 
    print("Not active, exiting")
    os.exit()
end)

function deviceStatus:IsActive()
    if self.active > 10 then
        self.active = 10
    end

    if self.active <= 0 then
        return false
    end
    self.active = self.active - 1
    return true
end

function deviceStatus:SafeCall(func)
    local r,msg = pcall(func,self)
    if not r then
        error("SafeCall error: " .. msg)
        os.exit(1)
    end
end

function CompareTableKeys(left, right)
    local left_only = {}
    local both_existing = {}
    local right_only = {}

    for k,_ in pairs(left) do
        if right[k] then
            both_existing[k] = true
        end
    end

    for k,_ in pairs(left) do
        if not both_existing[k] then
            left_only[k] = true
        end
    end   

    for k,_ in pairs(right) do
        if not both_existing[k] then
            right_only[k] = true
        end
    end   

    return left_only, both_existing, right_only
end

function deviceStatus:RemoveConfig(action)
    print("RemoveConfig is not implemented")
    -- os.exit(1)
    return true
end

function deviceStatus:UpdateConfig(action)
    -- print("UpdateConfig is not implemented")
    -- os.exit(1)

    local value = self.lastConfigValues[action.name]
    if  value then
        if value == action.expected then
            print("Config " .. action.name .. " is up to date")
            return true
        else
            print(string.format("Config %s needs update:\n\tExpected: [[%s]]\n\tCurrent: [[%s]]", action.name, action.expected, value))
            action.what = "Write"
            action.pending = false
            return false
        end
    end

    if not action.pending then
        self:Command{"cfg","get",action.name}
        action.pending = true
    end

    return false
end

function deviceStatus:WriteConfig(action)
    if not action.pending then
        self.gotOk = false
        self:Command{"cfg","set",action.name,action.expected}
        self.lastConfigValues[action.name] = nil
        action.pending = true
    end

    local value = self.lastConfigValues[action.name]
    if value then
        if value == action.expected then
            return true
        else
            print("Update failed: " .. action.name)
            os.exit(1)
        end
    end

    return false
end

function deviceStatus:GenerateUpdateCommands(deviceCfg)
    local required_cfg = self.project.config

    local remove,update,write = CompareTableKeys(deviceCfg, required_cfg)
   
    local updateCommands = {}

    for k,_ in pairs(remove) do
        print("Will remove config ", k)
        table.insert(updateCommands, { what = "Remove", name = k, expected = self.project:GetConfigFileContent(k) })
    end
    for k,_ in pairs(update) do
        print("Will update config ", k)
        table.insert(updateCommands, { what = "Update", name = k, expected = self.project:GetConfigFileContent(k) })
    end  
    for k,_ in pairs(write) do
        print("Will write config ", k)
        table.insert(updateCommands, { what = "Write", name = k, expected = self.project:GetConfigFileContent(k) })
    end       

    self.updateCommands = updateCommands

   self:Delay(function()self:BeginUpdate()end)
end

function deviceStatus:BeginUpdate()
    while #self.updateCommands > 0 do
        copas.sleep(1)
        self:SafeCall(function()
            local top = self.updateCommands[1]
            local fname = top.what .. "Config"
            local func = self[fname]
            if func(self, top) then
                table.remove(self.updateCommands, 1)
            end
        end)
    end
    self:Command{"restart"}
end

function deviceStatus:CheckPreconditions()
    if not self.commands["cfg"] then
        print("Required cfg command is not available")
        return false
    end

    return true
end

function deviceStatus:Delay(func)
    copas.addthread(function()
        copas.sleep(0.1)
        func()
    end)
end

function deviceStatus:Publish(topic, payload)
    copas.addthread(function()
        copas.sleep(0.1)
        topic = "/" .. self.name .. topic
        self.active = self.active + 1
        self.client:publish{
            topic = topic,
            payload = payload,
        }
    end)
end

function deviceStatus:Command(args)
    self:Publish("/cmd", table.concat(args, ","))
end

function deviceStatus:HandleConnect(connack)
    if connack.rc ~= 0 then
        error("connection to broker failed: " .. tostring(connack))
    end
    -- print("connected:", connack) -- successful connection
    assert(client:subscribe{ topic="/" .. self.name .. "/#", qos=0, callback=function(suback)
        -- print("subscribed:", suback)
    end})
end

function deviceStatus:HandleCommandOutput(value)
    local str = value:match("%s-Available commands:%s+(.+)")
    if str then
        print("Commands", str)
        self.commands = {}
        for _,v in ipairs(str:trim():split(",")) do
            self.commands[v] = true
        end
        self:Delay(function()
            if not self:CheckPreconditions() then
                print("Preconditions not correct")
                os.exit(1)
            end
            self:Command{"cfg", "list"}
        end)
        return
    end

    print("Invalid cmd output ", value)
end

function deviceStatus:HandleCfgOutput(value)
    local list = value:match("list=(.+)")
    if list then
        local deviceCfg = {}
        for _,v in ipairs(list:trim():split(",")) do
            deviceCfg[v] = true
        end
        self.deviceCfg = deviceCfg
        self:GenerateUpdateCommands(deviceCfg)
        return
    end

    local group, value = value:match("(%w+)=(.+)")
    if group and value then
        group = group:trim()
        value = value:trim()
        if self.deviceCfg[group] then
            print("Got config " .. group .. " value")
            self.lastConfigValues[group] = value
        end
        return
    end

    print("Invalid cfg output ", value)
end

deviceStatus.outputHandlers = {
    ["CMD"] = deviceStatus.HandleCommandOutput,
    ["CFG"] = deviceStatus.HandleCfgOutput,
    ["RESTART"] = function() os.exit(0) end,
}

function deviceStatus:HandleStatus(topic, payload)
    if payload == "online" then
        print("Device is online, starting...")
        self.online = true 
        self:Command{"help"}
    else
        error("Device is not online")
    end
end

function deviceStatus:HandleOutput(topic, payload)
    local group, message = payload:match("(%w+):%s+(.+)")
    -- print(group, message)
    local handler = self.outputHandlers[group]
    if not handler then
        print("Cannot handle output", topic, payload)
        return
    end
    handler(self, message:trim())
end

deviceStatus.topicHandlers = {
    ["/status"] = deviceStatus.HandleStatus,
    ["/cmd/output"] = deviceStatus.HandleOutput,
    ["/cmd"] = false,
    ["/chipid"] = false,
}

function deviceStatus:HandleMessage(msg)
    self.active = self.active + 1
    local topic = msg.topic
    topic = "/" .. topic:match("/" .. chip.name .. "/(.+)")

    local handler = self.topicHandlers[topic]
    if type(handler) == "boolean" then
        return
    end

    if not handler then
        print("Cannot handle ", topic, msg.payload)
        return
    end

    handler(self, topic, msg.payload)
end

function HandleError(err)
    print("MQTT client error:", err)
end

client:on {
	connect = function(...) deviceStatus:HandleConnect(...) end,
	message = function(...) deviceStatus:HandleMessage(...) end,
	error = HandleError,
}

copas.loop()
