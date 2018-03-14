local impl = { }

function impl.Connected(client)
  print ("MQTT: connected")

  MQTTPublish("/state", "online", 0, 0)
  MQTTPublish("/state/bootreason", sjson.encode({node.bootreason()}))
  MQTTPublish("/chipid", string.format("%X", node.chipid()), 0, 1)

  node.task.post(function()
    impl.RestoreSubscriptions(client)
  end)
end

function impl.Disconnected(client)
  print ("MQTT: offline")
  impl.HandleError(client, "?")
end

function impl.HandleError(client, error)
  print("MQTT: connection error, code:", error)
  tmr.create():alarm(10 * 1000, tmr.ALARM_SINGLE, 
    function(t) 
      loadScript("srv-mqtt").Init()
      t:unregister() 
  end)
end

function impl.Publish(topic, payload, qos, retain)
  local t = "/" .. wifi.sta.gethostname() .. topic
  print("MQTT: ", t .. " <- " .. (payload or "<NIL>") )
  local r = mqttClient:publish(t, payload, qos or 0, retain and 1 or 0)
  if not r then
    print("MQTT: publish failed")
  end
  return r
end

local function findHandlers()
  local h = {}
  for k,v in pairs(file.list()) do
    local match = k:match("^(mqtt%-%w+)%.l..?$")
    if match then
      table.insert( h, match )
    end
  end
  return h
end

local function topic2regexp(topic)
  return topic:gsub("+", "%w*"):gsub("#", ".*")
end

function impl.ProcessMessage(client, topic, payload)
  local base = "/" .. wifi.sta.gethostname() 
  print("MQTT:  ", (topic or "<NIL>") .. " -> " .. (payload or "<NIL>") )
  for _,f in ipairs(findHandlers()) do
    local m = loadScript(f, true)
    if not m then
      print("MQTT: cannot load handler ", f)
    else
      local regex = topic2regexp(base .. m.GetTopic())
      if topic:match(regex) and m.Message and m.Message(topic, payload) then
        print("MQTT: topic ".. topic .. " handled by " .. f) 
        return
      end      
    end
  end
  print("MQTT: cannot find handler for ", topic)
end

function impl.RestoreSubscriptions(client)
  local any = false
  local topics = { }
  local base = "/" .. wifi.sta.gethostname() 
  for _,f in ipairs(findHandlers()) do
    print("MQTT: found handler", f)
    local m = loadScript(f, true)
    if not m then
      print("MQTT: cannot load handler ", f)
    else
      if m.OnConnected then
        m.OnConnected()
      end

      local t = base .. m.GetTopic()
      print("MQTT: subscribe " .. t .. " -> " .. f)
      topics[t] = 0
      any = true
    end
  end

  if any then
    client:subscribe(topics, function(client) 
      print("MQTT: Subscriptions restored")
    end)
  else
    print("MQTT: no subscriptions!")
  end
end

return impl
