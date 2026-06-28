-- Frame: Wraps a WoW frame — either creates new or wraps existing
-- Create: Frame("Frame", parent, "MyFrame")
-- Wrap:   Frame(existingNativeFrame)

function IsNativeObject(obj, ofType)
    local isNative = type(obj) == "table"
                 and obj.GetObjectType ~= nil
                 and obj.__class == nil
    if not isNative then return false end
    if not ofType then return true end
    return obj:GetObjectType() == ofType
end

-- Raw C frame methods captured once. Used to drive a frame whose own positioning
-- methods we've neutralised (NeutralizeLayout) — calling these directly bypasses
-- the Lua-level overrides, the way MinimapButtonButton tames foreign minimap
-- buttons that re-anchor themselves every frame.
local rawSetPoint       = UIParent.SetPoint
local rawClearAllPoints = UIParent.ClearAllPoints
local rawSetFrameStrata = UIParent.SetFrameStrata
local rawSetFrameLevel  = UIParent.SetFrameLevel
local function doNothing () end

class "Frame" : extends {"Widget", "ScriptObject"} {

    __init = function(self, typeOrNative, parent, name, template)

        if self._native == nil then
            -- Assign frame if not already
            if IsNativeObject(typeOrNative) then
                self._native = typeOrNative
            else
                local frameType = typeOrNative or "Frame"
                local frameName = name
                local frameParent = parent and parent._native or MUI_Root._native
                self._native = CreateFrame(frameType, frameName, frameParent, template)
            end
        end

        -- Wire up event dispatch (only for new frames, not wrapped ones)
        self._eventHandlers = {}
        self._eventObserverAdded = false

        self._tooltipHooked = false
        self._tooltipBuilder = nil

    end;

    -- Foreign-frame taming (used to bin third-party minimap buttons): blank the
    -- position/parent/scale/strata/level setters the owning addon spams — some
    -- re-anchor or re-strata their button every frame — so it stays exactly where
    -- and how we put it, and drop its drag handlers. Set the desired values BEFORE
    -- calling this; drive position afterwards via RawSetPoint (the C method, which
    -- ignores the blanking).
    NeutralizeLayout = function(self)
        local n = self._native
        n.SetPoint       = doNothing
        n.ClearAllPoints = doNothing
        n.SetParent      = doNothing
        n.SetScale       = doNothing
        n.SetFrameStrata = doNothing
        n.SetFrameLevel  = doNothing
        n:SetScript("OnDragStart", nil)
        n:SetScript("OnDragStop", nil)
    end;

    RawSetPoint = function(self, point, relativeTo, relativePoint, x, y)
        if relativeTo and type(relativeTo) == "table" and relativeTo._native then
            relativeTo = relativeTo._native
        end
        rawClearAllPoints(self._native)
        rawSetPoint(self._native, point, relativeTo, relativePoint, x or 0, y or 0)
    end;

    RawSetDrawOrder = function(self, strata, level)
        rawSetFrameStrata(self._native, strata)
        rawSetFrameLevel(self._native, level)
    end;

    SetFrameStrata = function(self, strata)
        self._native:SetFrameStrata(strata)
    end;

    SetFrameLevel = function(self, level)
        self._native:SetFrameLevel(level)
    end;

	GetFrameLevel = function(self)
		return self._native:GetFrameLevel()
	end;

    GetFrameStrata = function(self)
        return self._native:GetFrameStrata()
    end;

    -- When false, the frame no longer auto-raises to the top of its strata on
    -- click (the XML `toplevel` behaviour).
    SetToplevel = function(self, enable)
        self._native:SetToplevel(enable and true or false)
    end;

    PutInfront = function(self, other, level)
        self._native:SetFrameLevel(other:GetFrameLevel() + (level or 1))
    end;

    -- When true, frame's pixel size is independent of UIParent's scale
    -- (the global UI Scale option). XML attribute `ignoreParentScale`
    -- on a frame definition has the same effect; this lets you flip it
    -- at runtime.
    SetIgnoreParentScale = function(self, ignore)
        self._native:SetIgnoreParentScale(ignore and true or false)
    end;

    StartMoving = function(self)
        self._native:StartMoving()
    end;

    StopMovingOrSizing = function(self)
        self._native:StopMovingOrSizing()
    end;

    UnregisterAllEvents = function(self)
        self._native:UnregisterAllEvents()
    end;

    EnableMouse = function(self, enable)
        self._native:EnableMouse(enable)
    end;

    EnableMouseWheel = function(self, enable)
        self._native:EnableMouseWheel(enable)
    end;

    SetPropagateMouseClicks = function(self, propagate)
        self._native:SetPropagateMouseClicks(propagate)
    end;

    SetPropagateMouseMotion = function(self, propagate)
        self._native:SetPropagateMouseMotion(propagate)
    end;

    SetMovable = function(self, movable)
        self._native:SetMovable(movable)
    end;

    RegisterForDrag = function(self, button)
        self._native:RegisterForDrag(button)
    end;

    MakeDraggable = function(self)
        self._native:SetMovable(true)
        self._native:EnableMouse(true)
        self._native:RegisterForDrag("LeftButton")
        self._native:SetScript("OnDragStart", function()
            self._native:StartMoving()
        end)
        self._native:SetScript("OnDragStop", function()
            self._native:StopMovingOrSizing()
        end)
    end;

    SetBackdrop = function(self, backdrop)
        if self._native.SetBackdrop then
            self._native:SetBackdrop(backdrop)
        end
    end;

    SetBackdropColor = function(self, r, g, b, a)
        self._native:SetBackdropColor(r, g, b, a)
    end;


    -- ====================== Events =================================

    RegisterEvent = function(self, event)
        self._native:RegisterEvent(event)
    end;

    UnregisterEvent = function(self, event)
        self._native:UnregisterEvent(event)
    end;

    RegisterEventHandler = function(self, event, handler)
        self._eventHandlers[event] = handler

        if not self._eventObserverAdded then
            self:SetScript("OnEvent", function(frame, event, ...)
                local handler = self._eventHandlers[event]
                if handler then
                   handler(self, event, ...)
                end
            end)
            self._eventObserverAdded = true
        end
        self._native:RegisterEvent(event)
    end;

    UnregisterEventHandler = function(self, event)
        self._eventHandlers[event] = nil
        self._native:UnregisterEvent(event)
    end;

    SetTooltip = function(self, anchor, buildFunc)
        self._native:EnableMouse(true)
        self._tooltipBuilder = buildFunc

        if not self._tooltipHooked then
            self._tooltipHooked = true
            local onEnter = self:GetScript("OnEnter")
            local onLeave = self:GetScript("OnLeave")
            
            self:SetScript("OnEnter", function()
                if onEnter then onEnter() end
                MUI_Tooltip:ShowFor(self, anchor, self._tooltipBuilder)
            end)
            self:SetScript("OnLeave", function()
                if onLeave then onLeave() end
                MUI_Tooltip:Hide()
            end)
        end
    end;


    GetChildren = function(self)
        local result = {}
        local children = { self._native:GetChildren() }
        for _, child in ipairs(children) do
            table.insert(result, Frame(child))
        end
        return result
    end;

    GetRegions = function(self)
        local result = {}
        local regions = { self._native:GetRegions() }
        for _, region in ipairs(regions) do
            local objType = region:GetObjectType()
            if objType == "Texture" then
                table.insert(result, Texture(region))
            elseif objType == "FontString" then
                table.insert(result, FontString(region))
            end
        end
        return result
    end;

    HideFrame = function(self, allowNativeShow)
        self._origShow = self._native.Show
        self:Hide()
        if not allowNativeShow then
            self._native.Show = function() end
        end
    end;

    ShowFrame = function(self)
        self._native.Show = self._origShow
        self:Show()
        self._origShow = nil
    end;

    HideAllRegions = function(self)
        local regions = { self._native:GetRegions() }
        for _, region in ipairs(regions) do
            region:Hide()
        end
    end;

    HideAllChildren = function(self)
        local children = { self._native:GetChildren() }
        for _, child in ipairs(children) do
            child:Hide()
        end
    end;

    -- Recursive HideAllChildren: walks the entire subtree. Use when one
    -- level of Hide isn't enough — typically because a parent's children
    -- include scroll frames / containers whose own children would still be
    -- visible relative to a different ancestor (rare, but Blizzard frames
    -- with reparenting hijinks need this).
    HideAllDescendants = function(self)
        local function recurse(frame)
            for _, child in ipairs({ frame:GetChildren() }) do
                child:Hide()
                recurse(child)
            end
        end
        recurse(self._native)
    end;

    Kill = function(self)
        self._native:Hide()
        self._native.Show = function() end
        if self._native.UnregisterAllEvents then self._native:UnregisterAllEvents() end
        if self._native.EnableMouse then self._native:EnableMouse(false) end
        self._native:SetAlpha(0)
    end;

    SetScale = function(self, scale)
        self._native:SetScale(scale)
    end;

    SetClampedToScreen = function(self, clamped)
        self._native:SetClampedToScreen(clamped)
    end;

    SetClipsChildren = function(self, clip)
        if self._native.SetClipsChildren then
            self._native:SetClipsChildren(clip)
        end
    end;

    GetID = function(self)
        return self._native:GetID()
    end;

    SetID = function(self, id)
        self._native:SetID(id)
    end;

    GetAttribute = function(self, name)
        return self._native:GetAttribute(name)
    end;

    SetAttribute = function(self, key, value)
        self._native:SetAttribute(key, value)
    end;

    SetOverrideBindingClick = function(self, isPriority, key, buttonName, mouseButton)
        SetOverrideBindingClick(self._native, isPriority, key, buttonName, mouseButton)
    end;

    -- ============ Animations ========== --

    FadeIn = function(self, duration, fromAlpha, toAlpha)
        UIFrameFadeIn(self._native, duration, fromAlpha or 0, toAlpha or 1)
    end;

    FadeOut = function(self, duration, fromAlpha, toAlpha)
        UIFrameFadeOut(self._native, duration, fromAlpha or 1, toAlpha or 0)
    end;

    -- ============ DEBUG ============== --

    ShowDebugBackground = function(self, r, g, b, a)
        local tex = Texture(self, nil, "BACKGROUND")
        tex:FillParent()
        tex:SetColorTexture(r or 1, g or 0, b or 0, a or 0.3)
    end;

}
