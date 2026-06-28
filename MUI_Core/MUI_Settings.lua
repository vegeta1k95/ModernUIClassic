-- MUI_Settings: Inject options into Blizzard's native Settings panel.
--
-- Usage:
--   MUI.InjectOption({
--       categoryId = "INTERFACE_CATEGORY_ID",         -- string key on Settings.* (deferred resolve)
--                     -- or Settings.INTERFACE_CATEGORY_ID directly
--       variable   = "MUI_Nameplate_ShowLevel",       -- unique string id
--       type       = "checkbox",                       -- "checkbox" | "slider" | "dropdown"
--       label      = "Show level",
--       tooltip    = "Display the unit's level.",     -- optional
--       default    = true,                             -- default if tbl[key] is nil
--       tbl        = MUI_DB.settings.nameplates,      -- persistence target
--       key        = "showLevel",                      -- key in tbl
--       after      = NAMEPLATES_LABEL,                -- optional: place right AFTER this name
--       before     = SHOW_ALL_ENEMIES,                -- optional: place right BEFORE this name
--       onChange   = function(value) ... end,         -- optional callback
--       -- slider-only:
--       min = 0, max = 100, step = 1,
--       formatter = function(value) return tostring(value) end,  -- label next to slider
--       -- dropdown-only:
--       options = optionsGenerator,                   -- or {{val, text}, ...}
--   })
--
-- `after` / `before` match any initializer by its display name (section header OR
-- setting label). Use Blizzard globals (e.g. NAMEPLATES_LABEL) or exact strings.
--
-- On first login the Blizzard settings definitions may finish registering slightly
-- after our OnEnable fires — if the target category isn't there yet we retry once.

MUI = MUI or {}

-- Accept either a function (already a menu-data builder) or a list of {value, label} pairs
-- and return the function form that Settings.CreateDropdownInitializer expects.
local function normalizeDropdownOptions(options)
    if type(options) == "function" then return options end
    if type(options) == "table" then
        return function()
            local c = Settings.CreateControlTextContainer()
            for _, entry in ipairs(options) do
                c:Add(entry[1], entry[2])
            end
            return c:GetData()
        end
    end
    return options
end

local function resolveVarType(t)
    local vt = Settings and Settings.VarType
    if t == "slider" then
        return (vt and vt.Number) or "number"
    elseif t == "dropdown" then
        return (vt and vt.Number) or "number"
    end
    return (vt and vt.Boolean) or "boolean"
end

-- Reposition `init` relative to another initializer identified by its display name.
-- `where` = "after" or "before".
local function moveRelativeTo(category, init, anchorName, where)
    local layout = SettingsPanel and SettingsPanel:GetLayout(category)
    if not layout then return end

    local inits = (layout.GetInitializers and layout:GetInitializers()) or layout.initializers
    if type(inits) ~= "table" then return end

    local anchorIdx, ourIdx
    for i, v in ipairs(inits) do
        if v == init then
            ourIdx = i
        else
            local name = (v.GetName and v:GetName()) or (v.data and v.data.name)
            if name == anchorName then
                anchorIdx = i
            end
        end
    end
    if not (anchorIdx and ourIdx) then return end

    table.remove(inits, ourIdx)
    local targetIdx = (where == "before") and anchorIdx or (anchorIdx + 1)
    if ourIdx < targetIdx then targetIdx = targetIdx - 1 end
    table.insert(inits, targetIdx, init)
end

local function resolveCategoryId(v)
    if type(v) == "string" then return Settings and Settings[v] end
    return v
end

-- Retry budget in seconds. On a fresh-character first login Blizzard's settings
-- definitions sometimes register slightly after our OnEnable; poll briefly.
local RETRY_INTERVAL = 0.25
local RETRY_BUDGET   = 10

local function tryInject(spec, elapsed)
    if not Settings then return end

    -- Idempotent: OnEnable fires on every PLAYER_ENTERING_WORLD, so callers may re-call.
    if Settings.GetSetting and Settings.GetSetting(spec.variable) then return end

    local categoryId = resolveCategoryId(spec.categoryId)
    local category = categoryId and Settings.GetCategory(categoryId) or nil
    if not category then
        elapsed = elapsed or 0
        if elapsed >= RETRY_BUDGET then return end
        if C_Timer and C_Timer.After then
            C_Timer.After(RETRY_INTERVAL, function()
                tryInject(spec, elapsed + RETRY_INTERVAL)
            end)
        end
        return
    end

    local setting = Settings.RegisterAddOnSetting(
        category,
        spec.variable,
        spec.key,
        spec.tbl,
        resolveVarType(spec.type),
        spec.label or spec.variable,
        spec.default
    )
    if not setting then return end

    local init
    if spec.type == "slider" then
        local options = Settings.CreateSliderOptions(spec.min or 0, spec.max or 100, spec.step or 1)
        if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
            local formatter = spec.formatter or function(value) return tostring(value) end
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
        end
        init = Settings.CreateSliderInitializer(setting, options, spec.tooltip)
    elseif spec.type == "dropdown" then
        init = Settings.CreateDropdownInitializer(setting, normalizeDropdownOptions(spec.options), spec.tooltip)
    else
        init = Settings.CreateCheckboxInitializer(setting, nil, spec.tooltip)
    end
    if not init then return end

    Settings.RegisterInitializer(category, init)

    if spec.after then
        moveRelativeTo(category, init, spec.after, "after")
    elseif spec.before then
        moveRelativeTo(category, init, spec.before, "before")
    end

    if spec.onChange then
        Settings.SetOnValueChangedCallback(spec.variable, function(_, _, value)
            spec.onChange(value)
        end)
    end
end

function MUI.InjectOption(spec)
    if not spec then return end
    if not spec.variable or not spec.tbl or not spec.key then return end
    tryInject(spec, 0)
end
