
local function require_alternative(wanted, alternatives)
    local got_it, module = pcall(require, wanted)
    if got_it then
        return module
    end

    assert(alternatives)
    while #alternatives > 0 do
        local to_test = table.remove(alternatives)
        local got_it, module = pcall(require, to_test)
        if got_it then
            package.loaded[wanted] = module
            print(string.format("Using alternative %s for %s", to_test, wanted))
            return module
        end
    end
    error(string.format("No vialbe alternative for %s", wanted))
end

require_alternative("json", {"cjson"})
require_alternative("dkjson", {"json", "cjson"})
