local loader_class = require "fairy_node/loader-class"

-------------------------------------------------------------------------------------

local RuleHandler = {}
RuleHandler.__name = "RuleHandler"
RuleHandler.__type = "class"
RuleHandler.__deps = {
}

-------------------------------------------------------------------------------------

function RuleHandler:Init(opt)
    RuleHandler.super.Init(self, opt)

    self.id = opt.id
    assert(self.id)

    self.details = opt.details

    self.local_device = opt.local_device
    assert(self.local_device)

    self:AddTask("rule", 10, self.RuleTick)

    self:Reset()

    if opt.script then
        self:SetScript(opt.script)
    end
end

function RuleHandler:Shutdown()
    if self.local_component then
        self.local_component:DeleteAllProperties()
        self.local_device:DeleteComponent(self.local_component:GetId())
        self.local_component = nil
    end
    self:Reset()
    RuleHandler.super.Shutdown(self)
end

-------------------------------------------------------------------------------------

function RuleHandler:GetId()
    return self.id
end

function RuleHandler:GetDetails()
    return self.details
end

-------------------------------------------------------------------------------------

function RuleHandler:Reset()
    print(self, "Resetting state rule environment")

    self.errors = { }
    self.states = { }
    self.states_to_tick = { }
    self.states_not_ready = { }
    self.states_owned = { }
end


function RuleHandler:SetScript(script, validate_only)
    local init_config = {
        handler = self
    }
    local environment = loader_class:CreateObject("rule-state/rule-runtime", init_config)
    local result = environment:ExecuteScript(script, self:GetId())

    if result then
        if not validate_only then
            self.script = script
            self:Reset()

            for k,v in pairs(environment:GetStates()) do
                self:AddState(v)
            end

            self:ResetComponent()
            self:RuleTick(nil)
        end
        return true
    else
        return false, environment.errors
    end
end

-------------------------------------------------------------------------------------

function RuleHandler:AddError(err_info)
    -- local err_info = {
    --     trace = trace,
    --     trace_level = trace_level,
    --     rule_object = rule_object,
    --     continue_execution = continue_execution,
    --     timestamp = os.timestamp()
    -- }
    table.insert(self.errors, err_info)
    print(self, "Rule error:", err_info.message, "\n", err_info.trace)
end

function RuleHandler:AddState(state)
    table.insert(self.states, state)

    if not state:IsProxy() then
        table.insert(self.states_owned, state)
    end

    if state:IsReady() then
        if state:WantsTick() then
            table.insert(self.states_to_tick, state)
        end
    else
        self.states_not_ready = self.states_not_ready or {}
        table.insert(self.states_not_ready, state)
    end
end

-------------------------------------------------------------------------------------

function RuleHandler:ResetComponent()
    local has_owned_states = #self.states_owned > 0

    if has_owned_states then
        if not self.local_component then
            self.local_component = self.local_device:AddComponent({
                class = "rule-state/rule-handler-component",
                id = self:GetId(),

                rule_handler = self,

                name = self:GetId(), --todo
            })
        end

        self.local_component:ResetProperties(self.states_owned)
    else
        if self.local_component then
            self.local_device:DeleteComponent(self.local_component:GetId())
            self.local_component = nil
        end
    end
end

-------------------------------------------------------------------------------------

function RuleHandler:IsReady()
    return self.states_not_ready == nil
end

function RuleHandler:RuleTick(task)
    for _,state in ipairs(self.states_to_tick) do
        state:Tick()
    end

    if self.states_not_ready then
        local not_ready = { }
        for _,state in ipairs(self.states_not_ready) do
            state:Update()
            if not state:IsReady() then
                table.insert(not_ready, state)
                print(self, "State is not yet ready:",  state:GetId())
            else
                if state:WantsTick() then
                    table.insert(self.states_to_tick, state)
                end
            end
        end
        if #not_ready == 0 then
            if self.local_component then
                self.local_component:SetReady(true)
            end
            not_ready = nil
        end
        self.states_not_ready = not_ready
    end
end

-------------------------------------------------------------------------------------

--[==[
-- function RuleService:GenerateStateDiagramElements()
--     local elements = {
--         groups = { },
--         state = { },
--         transitions_wanted_by_group = { },
--         states_wanted_by_group = { },
--     }

--     for _, state in pairs(self.rule_state:GetStates() or {}) do
--         local group = state:GetGroup()
--         elements.groups[group] = true
--         elements.transitions_wanted_by_group[group] = elements.transitions_wanted_by_group[group] or {}
--         elements.states_wanted_by_group[group] = elements.states_wanted_by_group[group] or {}
--         elements.transitions_wanted_by_group[group][state.global_id]=true
--         elements.states_wanted_by_group[group][state.global_id]=true
--         elements.state[state.global_id] = {
--             transitions = { }
--         }
--     end

--     for _, state in pairs(self.rule_state:GetStates() or {}) do
--         local ready, value = state:Status()
--         value = value or {}
--         local state_style = {
--             SelectColor(value.value, ready),
--         }
--         local state_style_text = "#" .. table.concat(state_style, ";")
--         local desc = {
--             -- print((myString:gsub("\\([nt])", {n="\n", t="\t"})))
--             table.concat(state:GetDescription() or { }, "\\\\\\n")
--         }
--         local group = state:GetGroup()
--         if group and group ~= "" then
--             table.insert(desc, 1, string.format("\ngroup: %s", state:GetGroup()))
--             if #desc > 1 then table.insert(desc, 2, "..") end
--         else
--             if #desc > 0 then table.insert(desc, 1, "\n..") end
--         end
--         local members = table.concat(desc, "\n")
--         local formatted_value = FormatValue(value.value)
--         local mode = StateClassMapping[state.__id] or "entity"
--         local string_timestamp = ""
--         if value.timestamp then
--             string_timestamp = os.timestamp_to_string_short(value.timestamp)
--         end
--         local state_line = string.format([[
-- %s %s as "%s" %s {
-- value: %s
-- timestamp: %s %s
-- ..
-- %s
-- }
-- ]], mode,
--     self.plantuml:idToId(state.global_id),
--     state:Getid(),
--     state_style_text,
--     formatted_value, string_timestamp,
--     members,
--     state.global_id)
--         local state_info = elements.state[state.global_id]
--         state_info.definition = state_line
--         for _, dep in ipairs(state:GetSinkDependencyList() or {}) do
--             local l = FormatDependency(self.plantuml, state.global_id, dep.id, dep.virtual)
--             table.insert(state_info.transitions, l)
--             elements.states_wanted_by_group[group][dep.id] = true
--         end
--         for _, dep in ipairs(state:GetSourceDependencyList() or {}) do
--             if dep.group ~= group then
--                 local l = FormatDependency(self.plantuml, dep.id, state.global_id, dep.virtual)
--                 table.insert(state_info.transitions, l)
--                 elements.states_wanted_by_group[group][dep.id] = true
--             end
--         end
--     end
--     return elements
-- end

-- function RuleService:GenerateStateGroupDiagram(elements, group)
--     local lines = {
--         "skinparam DefaultFontColor black", --
--         "skinparam ArrowColor black", --
--         "skinparam ClassBorderColor black", --
--         "skinparam ranksep 20", --
--     }
--     local transitions = { }
--     for global_id,_ in pairs(elements.states_wanted_by_group[group] or {}) do
--         local s = elements.state[global_id]
--         table.insert(lines, s.definition)
--     end
--     for global_id,_ in pairs(elements.transitions_wanted_by_group[group] or {}) do
--         local s = elements.state[global_id]
--         table.insert(transitions, table.concat(s.transitions, "\n"))
--     end
--     table.insert(lines, "")
--     table.insert(lines,  table.concat(transitions, "\n"))

--     table.insert(lines, "@enduml")

--     return lines
-- end

-- function RuleService:GenerateStateDiagram()
--     local lines = {
--     }

--     table.insert(lines, "")

--     for _, state in pairs(self.rule_state:GetStates() or {}) do
--         for _, dep in ipairs(state:GetSinkDependencyList() or {}) do

--             local arrow = dep.virtual and "..>" or "-->"

--             local l = { self.plantuml:idToId(state.global_id), arrow,  self.plantuml:idToId(dep.id)}
--             table.insert(lines, table.concat(l, " "))
--         end
--     end

--     table.insert(lines, "@enduml")

--     return lines
-- end
--]==]

local DiagramColorLight = {
    not_ready = "#a1a1a1",
    boolean_true = "#FFCE9D",
    boolean_false = "#C0C0CE",
    default = "#FEFECE"
}
local DiagramColorDark = {
    not_ready = "#363636",
    boolean_true = "#360e0e",
    boolean_false = "#000042",
    default = "#0c4d01"
}

local StateClassMapping = {
--     StateHomie = "interface",
--     StateTime = "abstract",
--     StateSensor = "struct",
}

function RuleHandler:GenerateDiagram(graph_builder)
    graph_builder:SetDefaultNodeType(graph_builder.NodeType.class)

    graph_builder:SetColorMapping({
        dark = DiagramColorDark,
        default = DiagramColorLight,
    })

    for _, state in ipairs(self.states) do
        local id = state:GetId()
        local name = state:GetName()
        local current_value = state:GetValue() or {}

        local desc = state:GetDescription() or {}
        if #desc > 0 then
            table.insert(desc, '..')
        end

        table.insert(desc, string.format("type: %s", state.__name or "?"))
        -- table.insert(desc, string.format("group: %s", state:GetGroup() or "default"))
        table.insert(desc, '..')
        table.insert(desc, string.format("value: %s", graph_builder.FormatValue(current_value.value)))
        table.insert(desc, string.format("timestamp: %s", os.timestamp_to_string_short(current_value.timestamp)))

        local color
        if state:IsReady() then
            if type(current_value.value) == "boolean" then
                color = current_value.value and "boolean_true" or "boolean_false"
            else
                color = "default"
            end
        else
            color = "not_ready"
        end

        local line_mode
        if state:IsProxy() then
            line_mode =  "dotted"
        end

        local node_type
        -- type = class_meta.interface and graph.NodeType.interface or graph.NodeType.class

        graph_builder:Node({
            name = name,
            description = desc,

            color = color,
            line_mode = line_mode,
            type = node_type,

            alias = state:GetGlobalId(),

            from = state:GetSourceDependencyIds(),
            -- to = state:GetSinkDependencyIds(),
        })

    end

    return true
end

-------------------------------------------------------------------------------------

return RuleHandler
