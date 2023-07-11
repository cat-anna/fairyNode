
-------------------------------------------------------------------------------

local function MakeBuilderMetatable(data)
    local builder_mt = {
        name = data.name,
        index = 0,

        full_path_text = { data.name },
        full_path_nodes = { data.host, },

        path_getters = data.path_getters,
        host = data.host,
        context = data.context,

        result_callback = data.result_callback,
        error_callback = data.error_callback,
    }

    function builder_mt.__newindex(mock, name, v)
        error("Attempt to add value to path builder")
    end

    function builder_mt.__index(mock, name)
        local idx = builder_mt.index + 1
        builder_mt.index = idx
        table.insert(builder_mt.full_path_text, name)

        local getter = builder_mt.path_getters[idx]
        local next = getter(
            builder_mt.full_path_nodes[idx],
            name
        )

        if not next then
            local path = table.concat(builder_mt.full_path_text, ".")
            if builder_mt.error_callback then
                builder_mt.error_callback(
                    builder_mt.context,
                    "Path " .. path .. " does not exist"
                )
            end
            error("Path " .. path .. " does not exist")
        end

        table.insert(builder_mt.full_path_nodes, next)

        if idx < #builder_mt.path_getters then
            return mock
        else
            return builder_mt.result_callback({
                full_path = table.concat(builder_mt.full_path_text, "."),

                full_path_text = builder_mt.full_path_text,
                full_path_nodes = builder_mt.full_path_nodes,

                name = builder_mt.name,
                host = builder_mt.host,
                context = builder_mt.context,
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
