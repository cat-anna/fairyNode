
local StateClassReg = {}
StateClassReg.__index = StateClassReg
StateClassReg.__deps = {
}

function StateClassReg:BeforeReload()
end

function StateClassReg:AfterReload()
    for _,v in pairs(self.created_states or {}) do
        print("Update state " ..  v.global_id .. " with class ".. v.__class)
        local class_type = self.registered_classes[v.__class]
        setmetatable(v, class_type)
        SafeCall(function () v:Update() end)
    end
end

function StateClassReg:Init()
    self.registered_classes = { }
    local states_mt = { __mode = "v" }
    self.created_states = setmetatable({}, states_mt)
end

function StateClassReg:RegisterStateClass(class)
    print("StateClassReg: Registered class " .. class.__class)
    self.registered_classes[class.__class] = class

    for _,v in pairs(self.created_states) do
        if v.__class == class.__class then
            print("StateClassReg: Update class " .. v.global_id)
            setmetatable(v, class)
            SafeCall(function () v:Update() end)
        end
    end
end

function StateClassReg:Create(opt)
    local state = self.created_states[opt.global_id]
    if not state then
        state = {
            global_id=opt.global_id,
        }
        self.created_states[opt.global_id] = state
    end

    state.class_id = opt.class_id

    local class = self.registered_classes[opt.class]
    setmetatable(state, class)
    state:Create(opt)
    return state
end

function StateClassReg:HandleTimer()
    for _,state in pairs(self.created_states) do
        SafeCall(state.OnTimer, state)
    end
end

-------------------------------------------------------------------------------

StateClassReg.EventTable = {
    ["timer.basic.30_second"] = StateClassReg.HandleTimer,
}

return StateClassReg

