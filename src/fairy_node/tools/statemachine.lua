-- Based on https://github.com/kyleconroy/lua-state-machine (MIT license)

local machine = {}
machine.__index = machine

local NONE = "none"
local ASYNC = "async"

local function firstToUpper(str)
  return (str:gsub("^%l", string.upper))
end

local function call_handler(handler, params)
  if handler then
    return handler(table.unpack(params))
  end
end

local function create_transition(name)
  local can, to, from, params

  local function transition(self, ...)
    if self.async_state == NONE then
      can, to = self:Can(name)
      from = self.current
      params = { self, name, from, to, ...}

      if not can then return false end
      self.current_transitioning_event = name

      local beforeReturn = call_handler(self["OnBefore" .. firstToUpper(name)], params)
      local leaveReturn = call_handler(self["OnLeave" .. firstToUpper(from)], params)

      if beforeReturn == false or leaveReturn == false then
        return false
      end

      self.async_state = name .. "WaitingOnLeave"

      if leaveReturn ~= ASYNC then
        transition(self, ...)
      end

      return true
    elseif self.async_state == name .. "WaitingOnLeave" then
      self.current = to

      local enterReturn = call_handler(self["OnEnter" .. firstToUpper(to)], params)

      self.async_state = name .. "WaitingOnEnter"

      if enterReturn ~= ASYNC then
        transition(self, ...)
      end

      return true
    elseif self.async_state == name .. "WaitingOnEnter" then
      call_handler(self["OnAfter" .. firstToUpper(name)], params)
      call_handler(self["OnStateChange"], params)
      self.async_state = NONE
      self.current_transitioning_event = nil
      return true
    else
    	if string.find(self.async_state, "WaitingOnLeave") or string.find(self.async_state, "WaitingOnEnter") then
    		self.async_state = NONE
    		transition(self, ...)
    		return true
    	end
    end

    self.current_transitioning_event = nil
    return false
  end

  return transition
end

local function add_to_map(map, event)
  if type(event.from) == 'string' then
    map[event.from] = event.to
  else
    for _, from in ipairs(event.from) do
      map[from] = event.to
    end
  end
end

function machine.Create(options)
  assert(options.events)

  local fsm = {}
  setmetatable(fsm, machine)

  fsm.options = options
  fsm.current = options.initial or 'none'
  fsm.async_state = NONE
  fsm.events = {}

  for _, event in ipairs(options.events or {}) do
    local name = event.name
    fsm[name] = fsm[name] or create_transition(name)
    fsm.events[name] = fsm.events[name] or { map = {} }
    add_to_map(fsm.events[name].map, event)
  end

  for name, callback in pairs(options.callbacks or {}) do
    fsm[name] = callback
  end

  return fsm
end

function machine:Is(state)
  return self.current == state
end

function machine:Can(e)
  local event = self.events[e]
  local to = event and event.map[self.current] or event.map['*']
  return to ~= nil, to
end

function machine:Cannot(e)
  return not self:can(e)
end

function machine:Process(...)
  return call_handler(self["Process" .. firstToUpper(self.current)], { self, ... })
end

function machine:ToDot(filename)
  local dotfile = io.open(filename,'w')
  dotfile:write('digraph {\n')
  local transition = function(event,from,to)
    dotfile:write(string.format('%s -> %s [label=%s];\n',from,to,event))
  end
  for _, event in pairs(self.options.events) do
    if type(event.from) == 'table' then
      for _, from in ipairs(event.from) do
        transition(event.name,from,event.to)
      end
    else
      transition(event.name,event.from,event.to)
    end
  end
  dotfile:write('}\n')
  dotfile:close()
end

function machine:Transition(event)
  if self.current_transitioning_event == event then
    return self[self.current_transitioning_event](self)
  end
end

function machine:CancelTransition(event)
  if self.current_transitioning_event == event then
    self.async_state = NONE
    self.current_transitioning_event = nil
  end
end

machine.NONE = NONE
machine.ASYNC = ASYNC

return machine
