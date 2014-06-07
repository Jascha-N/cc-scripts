function load(fileName, descriptor)
    local config = {}
    local configMeta = {
        __index =
            function(tbl, key)
                local value = rawget(tbl, key)
                if value ~= nil then
                    return value
                end
                if descriptor[key] ~= nil then
                    return descriptor[key].default
                end
                return nil
            end,
        __newindex =
            function(tbl, key, value)
                if descriptor[key] == nil then
                    error(key .. ": unknown setting", 2)
                end
                if descriptor[key].check ~= nil then
                    local message = descriptor[key].check(value)
                    if message ~= nil then
                        error(key .. ": " .. message, 2)
                    end
                end
                rawset(tbl, key, value)
            end,
        __metatable = true
    }
    setmetatable(config, configMeta)

    if fileName ~= nil then
        if fs.exists(fileName) then
            local f, message = loadfile(fileName)
            if not f then
                error(message)
            end

            local env = {}
            local envMeta = {
                __index     =
                    function(tbl, key)
                        return config[key] or _G[key]
                    end,
                __newindex  = config,
                __metatable = true
            }
            setmetatable(env, envMeta)

            setfenv(f, env)
            f()
        else
            local f = fs.open(fileName, "w")
            if f == nil then
                error("unable to open file")
            end

            for k, v in pairs(descriptor) do
                if v.description then
                    local lines = v.description
                    if type(v.description) == "table" then
                        for _, line in ipairs(v.description) do
                            f.writeLine("-- " .. line)
                        end
                    else
                        f.writeLine("-- " .. v.description)
                    end
                end

                f.write("-- " .. k .. " = ")
                local success, result = pcall(textutils.serialise, v.default)
                if success then
                    f.writeLine(result)
                else
                    f.writeLine("nil -- (not serializable)")
                end
                f.writeLine()
            end

            f.close()
        end
    end

    return config
end

function checkType(typ)
    return function(value)
        if type(value) ~= typ then
            return "incorrect type; expected " .. typ .. "."
        end
    end
end

function checkEnum(...)
    local args = {...}
    return function(value)
        for _, v in ipairs(args) do
            if value == v then
                return nil
            end
        end
        return "not a valid value; expected: " ..
               table.concat(args, ", ") .. "."
    end
end

function checkRange(min, max, minExcl, maxExcl)
    return function(value)
        if type(value) ~= "number" then
            return "not a number"
        end

        if (min == nil or min < value or not minExcl and min == value) or
           (max == nil or max > value or not maxExcl and max == value)
        then
            return nil
        end

        return "number out of range"
    end
end
