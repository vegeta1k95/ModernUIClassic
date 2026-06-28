-- Minimal OOP framework
-- Provides:
--   class  "Name" : extends "Base" { __init = ...; Method = ...; }
--   object "Name" : extends "Base" { __init = ...; Method = ...; }
--
-- `class` defines the type; you instantiate it manually with `Name(...)`.
-- `object` does the same but additionally auto-instantiates a singleton at
-- `_G["MUI_" .. Name]` once the body is applied (Kotlin-style). The class
-- itself stays available, so `Name(...)` still works for extra instances or
-- typeof checks; `MUI_Name` is just the canonical singleton instance.
-- `object` __init must take no args (or accept all-nil) since the singleton
-- is created without any.

local function ClassCreate(name)
    if (_G[name] ~= nil) then
        error("Class " .. name .. " already exists!")
        return
    end

    local class = {}
    class.__index = class
    class.__classname = name
    class.__class = class
    class.__init = function(self) end

    local class_meta = {
        __call = function(class, ...)
            local object = setmetatable({}, class)
            object.__init(object, ...)
            return object
        end
    }

    _G[name] = setmetatable(class, class_meta)
    return class
end

local function ClassAddSuper(class, superclass)
    for name, method in pairs(superclass) do
        if (class[name] == nil) then
            class[name] = method
        end
    end
end

local function ClassDefinition(class)
    local definer = {
        extends = function(self, superclasses)
            if (type(superclasses) == "string") then
                local superclass = _G[superclasses]
                if (superclass) then
                    ClassAddSuper(class, superclass)
                else
                    error("Base class " .. superclasses .. " not found!")
                end
            elseif (type(superclasses) == "table") then
                for _, name in pairs(superclasses) do
                    local superclass = _G[name]
                    if (superclass) then
                        ClassAddSuper(class, superclass)
                    else
                        error("Base class " .. name .. " not found!")
                    end
                end
            end
            return self
        end
    }

    local definer_meta = {
        __call = function(self, definition)
            for name, method in pairs(definition) do
                class[name] = method
            end
        end
    }

    return setmetatable(definer, definer_meta)
end

function class(name)
    return ClassDefinition(ClassCreate(name))
end

function object(name)
    local cls = ClassCreate(name)
    local definer = ClassDefinition(cls)
    -- Replace the body-applying __call with one that also instantiates
    -- the singleton. `extends` lives on the definer table and is preserved.
    setmetatable(definer, {
        __call = function(self, definition)
            for k, v in pairs(definition) do
                cls[k] = v
            end
            _G["MUI_" .. name] = cls()
        end
    })
    return definer
end
