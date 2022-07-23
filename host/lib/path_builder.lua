
-------------------------------------------------------------------------------

local function MakeBuilderMetatable(data)
    local builder_mt = {
        name = data.name,
        index = 0,

        path = { },

        full_path_text = { data.name },
        full_path_nodes = { data.host, },

        path_getters = data.path_getters,
        result_callback = data.result_callback,
        host = data.host,
    }

    function builder_mt.__newindex(mock, name, v)
        error("Attempt to add value to path builder")
    end

    function builder_mt.__index(mock, name)
        local idx = builder_mt.index + 1
        builder_mt.index = idx
        table.insert(builder_mt.path, name)
        table.insert(builder_mt.full_path_text, name)

        local getter = builder_mt.path_getters[idx]
        local next = getter(name, builder_mt.full_path_nodes[#builder_mt.full_path_nodes])

        if not next then
            local path = table.concat(builder_mt.full_path_text, ".")
            error("Path " .. path .. " does not exist")
        end

        table.insert(builder_mt.full_path_nodes, next)

        if idx < #builder_mt.path_getters then
            return mock
        else
            return builder_mt.result_callback({
                path = table.concat(builder_mt.path, "."),

                full_path = table.concat(builder_mt.full_path_text, "."),
                full_path_nodes = builder_mt.full_path_nodes,

                name = builder_mt.name,
                host = builder_mt.host,
            })
        end
    end

    return builder_mt
end

-------------------------------------------------------------------------------

local function CreatePathBuilder(data)
    return setmetatable({}, MakeBuilderMetatable(data))
end

local function PathBuilderWrapper(data)
    return setmetatable({}, {
        __index = function (self, name) return CreatePathBuilder(data)[name] end
    })
end

-------------------------------------------------------------------------------

local M = { }

M.CreatePathBuilder = CreatePathBuilder
M.PathBuilderWrapper = PathBuilderWrapper

return M
