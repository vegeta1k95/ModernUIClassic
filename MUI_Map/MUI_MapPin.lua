-- MUI_MapPin: generic static pin class for the WorldMap canvas.
--
-- Pins anchor to WorldMapFrame:GetCanvas() at a normalised (uiMap-local)
-- position. They DON'T project per-frame — pin lifecycle is driven by
-- MapStaticPinManager (and any future world-map pin manager), which
-- rebuilds the pin set whenever the displayed uiMap changes.
--
-- Icon registry MUI_MapPinIcons mirrors the minimap one in shape (a 7-tuple
-- of arguments for Texture:SetTextureRegion) but lives separately so map
-- pins can use different art / coords / sizes from minimap pins.

local OBJECTS_ATLAS = MUI.TEX_BASE .. "objecticonsatlas"

-- Frame level pins sit at on the WorldMap canvas. Classic Era's
-- MapCanvas_PinFrameLevelsManager allocates native pin layers from a
-- base of 2000 (fog-of-war, AreaPOI, group members, etc. all live at
-- 2000+something). Our pins must sit ABOVE that or the explored-area
-- overlay obscures them. 3000 leaves headroom for any new Blizzard
-- pin types and stays well below the 9000 frame-level cap.
MUI_MAP_PIN_FRAME_LEVEL = 3000

-- Click-vs-drag threshold (squared screen pixels). Mouse-up within this
-- distance of the mouse-down counts as a click; further is a drag attempt
-- and the click handler doesn't fire. 3px absorbs hand jitter without
-- swallowing intentional clicks.
local MAP_PIN_CLICK_THRESHOLD_SQ = 9

-- Cached Frame wrapper around WorldMapFrame:GetCanvas(). Lazily built so we
-- never call GetCanvas before WorldMapFrame is loaded.
local _canvasWrapper
local function _Canvas()
    if _canvasWrapper then return _canvasWrapper end
    if not WorldMapFrame or not WorldMapFrame.GetCanvas then return nil end
    local native = WorldMapFrame:GetCanvas()
    if not native then return nil end
    _canvasWrapper = Frame(native)
    return _canvasWrapper
end

-- Singleton: keeps every registered map pin / POI button at a constant
-- on-screen size as the user mouse-wheel zooms the WorldMap canvas.
--
-- Both SetIgnoreParentScale(true) and SetScale(1/canvasScale) tested as
-- ways to fight the canvas's zoom — both broke positioning (offsets stop
-- being interpreted in canvas coord space, so pins drift). Counter-sizing
-- via SetSize works: as canvasScale grows N, pin's logical size shrinks
-- to (origSize / N), and the canvas zoom multiplies it back to origSize
-- in screen pixels. Position is unaffected because SetPoint offsets
-- aren't re-interpreted by SetSize.
--
-- Stores each pin's original size at register time and reapplies on zoom.
object "MapPinScaleTracker" {
    __init = function(self)
        self._pins   = {}    -- [pin] = originalLogicalSize
        self._hooked = false
    end;

    Register = function(self, pin)
        self:_EnsureHook()
        self._pins[pin] = pin:GetWidth()
        self:_ApplySize(pin)
    end;

    Unregister = function(self, pin)
        self._pins[pin] = nil
    end;

    _CurrentScale = function(self)
        local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
        if sc and sc.GetCanvasScale then return sc:GetCanvasScale() end
        return nil
    end;

    _ApplySize = function(self, pin)
        local s = self:_CurrentScale()
        if not s or s <= 0 then return end
        local orig = self._pins[pin]
        if not orig or orig <= 0 then return end
        local size = orig / s
        pin:SetSize(size, size)
    end;

    _EnsureHook = function(self)
        if self._hooked then return end
        if not WorldMapFrame or not WorldMapFrame.ScrollContainer then return end
        self._hooked = true
        hooksecurefunc(WorldMapFrame.ScrollContainer, "InstantPanAndZoom", function()
            for pin in pairs(self._pins) do
                self:_ApplySize(pin)
            end
        end)
    end;
}

-- Icon registry. Entries: { path, fileW, fileH, x, y, w, h }.
-- Coordinates are the same source atlas the minimap uses; pin size is set
-- per-instance so map and minimap can render the same icon at different
-- sizes without duplicating coords here.
MUI_MapPinIcons = {

    -- Custom waypoint
    ["Waypoint"]              = { OBJECTS_ATLAS, 1024, 1024, 901, 729, 21, 21 },
    ["WaypointFocused"]       = { OBJECTS_ATLAS, 1024, 1024, 867, 729, 21, 21 },

    -- Quests
    ["Quest"]                 = { OBJECTS_ATLAS, 1024, 1024, 863, 133, 64, 60},
    ["QuestRepeatable"]       = { OBJECTS_ATLAS, 1024, 1024, 623, 554, 32, 32},
    ["QuestRepeatableTurnIn"] = { OBJECTS_ATLAS, 1024, 1024, 691, 553, 32, 32},
    ["QuestMeta"]             = { OBJECTS_ATLAS, 1024, 1024, 725, 554, 32, 32},
    ["QuestLegendary"]        = { OBJECTS_ATLAS, 1024, 1024, 521, 962, 32, 32},
    ["QuestImportant"]        = { OBJECTS_ATLAS, 1024, 1024, 521, 859, 32, 32},
    ["QuestCampaign"]         = { OBJECTS_ATLAS, 1024, 1024, 520, 689, 32, 32},
    ["Hub"]                   = { OBJECTS_ATLAS, 1024, 1024, 534, 132, 64, 64},

    -- Dungeons
    ["Dungeon"]              = { OBJECTS_ATLAS, 1024, 1024, 208, 457, 40, 40},
    ["Raid"]                 = { OBJECTS_ATLAS, 1024, 1024, 208, 508, 40, 40},

    -- Transport
    ["TransportHorde"]       = { OBJECTS_ATLAS, 1024, 1024, 137, 330, 64, 64 },
    ["TransportAlliance"]    = { OBJECTS_ATLAS, 1024, 1024, 137, 198, 64, 64 },
    ["TransportNeutral"]     = { OBJECTS_ATLAS, 1024, 1024, 137, 462, 64, 64 },

    -- Flightmasters
    ["FlightMasterHorde"]    = { OBJECTS_ATLAS, 1024, 1024, 589, 723, 32, 32 },
    ["FlightMasterAlliance"] = { OBJECTS_ATLAS, 1024, 1024, 589, 689, 32, 32 },
    ["FlightMasterUnknown"]  = { OBJECTS_ATLAS, 1024, 1024, 589, 791, 32, 32 },
    ["FlightMasterNeutral"]  = { OBJECTS_ATLAS, 1024, 1024, 589, 757, 32, 32 },

    -- Misc
    ["Focused"]              = { OBJECTS_ATLAS, 1024, 1024, 868, 729, 19, 20 },
}

class "MapPin" : extends "Frame" {
    __init = function(self, name, size)
        Frame.__init(self, "Frame", _Canvas(), name)
        size = size or 32
        self:SetSize(size, size)
        self:SetFrameStrata("MEDIUM")
        self:SetFrameLevel(MUI_MAP_PIN_FRAME_LEVEL)
        self:EnableMouse(true)
        -- Constant on-screen size regardless of map zoom — the scale
        -- tracker counter-scales every registered pin to (1/canvasScale)
        -- so size stays pixel-constant while SetPoint offsets continue
        -- to scale with the canvas (so position tracks the map).
        MUI_MapPinScaleTracker:Register(self)

        self.icon = Texture(self, nil, "OVERLAY")
        self.icon:SetSubpixelRendering(true)

        self.highlight = Texture(self, nil, "HIGHLIGHT")
        self.highlight:SetSubpixelRendering(true)
        self.highlight:SetBlendMode("ADD")
        self.highlight:SetAlpha(0.4)
        
        self.focusedHalo = Texture(self, nil, "BACKGROUND")
        self.focusedHalo:SetAtlas(MUI_AtlasRegistry.QuestPoiDefault, "GlowOuter", true)
        self.focusedHalo:ClearAllPoints()
        self.focusedHalo:SetSubpixelRendering(true)
        self.focusedHalo:FillParent(-25)
        self.focusedHalo:Hide()

        self._overlay = Frame("Frame", self)
        self._overlay:FillParent()

        self.focusedBadge = Texture(self._overlay, nil, "OVERLAY")
        local fSpec = MUI_MapPinIcons["Focused"]
        self.focusedBadge:SetTextureRegion(fSpec[1], fSpec[2], fSpec[3], fSpec[4], fSpec[5], fSpec[6], fSpec[7])
        self.focusedBadge:SetSubpixelRendering(true)
        self.focusedBadge:SetSize(19, 20)
        self.focusedBadge:SetPoint("BOTTOMRIGHT", self.icon, "BOTTOMRIGHT", 4, -3)
        self.focusedBadge:Hide()

        self.indicator = Texture(self._overlay, nil, "OVERLAY")
        self.indicator:SetSubpixelRendering(true)
        self.indicator:SetSize(19, 20)
        self.indicator:SetPoint("BOTTOM", self, "BOTTOM", 0, 0)
        self.indicator:Hide()

        self.uiMapId = nil
        self.normX = 0
        self.normY = 0
        self._pressed = false
        self._focused = false
        self:_RefreshIconAnchor()

        self:Hide()
    end;

    SetSize = function(self, w, h)
        Frame.SetSize(self, w, h)
        if self.focusedBadge then self.focusedBadge:SetSize((w-1)*0.6, h*0.6) end
        if self.indicator then
            self.indicator:SetSize(w * 0.5, h * 0.5)
            self.indicator:ClearAllPoints()
            self.indicator:SetPoint("BOTTOM", self, "BOTTOM", 0, 0)
        end
    end;

    -- Re-anchor icon and highlight inside the pin's rect, applying a
    -- 1px bottom-right offset when pressed (button-like feedback).
    -- Called from __init and on press/release.
    _RefreshIconAnchor = function(self)
        local dx, dy = 0, 0
        if self._pressed then dx, dy = 1, -1 end
        self.icon:ClearAllPoints()
        self.icon:SetPoint("TOPLEFT",     self, "TOPLEFT",     dx, dy)
        self.icon:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", dx, dy)
        self.highlight:ClearAllPoints()
        self.highlight:SetPoint("TOPLEFT",     self, "TOPLEFT",     dx, dy)
        self.highlight:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", dx, dy)
    end;

    _SetPressed = function(self, pressed)
        if self._pressed == pressed then return end
        self._pressed = pressed
        self:_RefreshIconAnchor()
    end;

    -- Anchor the pin to a normalised position (0..1) on the given uiMap.
    -- The manager only calls this when the canvas is currently displaying
    -- the same uiMap (or one we want to project against), so we always
    -- show on call. Re-call to move.
    SetMapPosition = function(self, uiMapId, normX, normY)
        self.uiMapId = uiMapId
        self.normX   = normX
        self.normY   = normY

        local canvas = _Canvas()
        if not canvas then return end
        self:ClearAllPoints()
        self:SetPoint("CENTER", canvas, "TOPLEFT",
                       normX * canvas:GetWidth(),
                      -normY * canvas:GetHeight())
        self:Show()
    end;

    -- Look up and apply an icon by type name from MUI_MapPinIcons.
    SetIconType = function(self, typeName)
        local spec = MUI_MapPinIcons[typeName]
        if not spec then
            MUI.Print("|cffff4040MUI_MapPin|r unknown icon type: " .. tostring(typeName))
            return
        end
        self.icon:SetTextureRegion(spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], spec[7])
        self.highlight:SetTextureRegion(spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], spec[7])
    end;

    -- Arbitrary 7-arg icon override (bypasses the registry).
    SetIcon = function(self, path, fileW, fileH, x, y, w, h)
        self.icon:SetTextureRegion(path, fileW, fileH, x, y, w, h)
        self.highlight:SetTextureRegion(path, fileW, fileH, x, y, w, h)
    end;

    SetIconDesaturated = function(self, desaturated)
        self.icon:SetDesaturated(desaturated)
    end;

    SetIconTint = function(self, r, g, b, a)
        self.icon:SetVertexColor(r, g, b, a or 1)
    end;

    -- Show / hide a small icon overlay at the pin's bottom-center, half
    -- the pin's size. `iconType` is a MUI_MapPinIcons key; pass nil to
    -- hide. `dimmed=true` tints the indicator grey (matches the
    -- trivial-quest pin / tooltip-icon convention).
    SetIndicator = function(self, iconType, dimmed)
        if not iconType then
            self.indicator:Hide()
            return
        end
        local spec = MUI_MapPinIcons[iconType]
        if not spec then
            self.indicator:Hide()
            return
        end
        self.indicator:SetTextureRegion(spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], spec[7])
        if dimmed then
            self.indicator:SetVertexColor(1, 1, 1, 0.6)
        else
            self.indicator:SetVertexColor(1, 1, 1, 1)
        end
        self.indicator:Show()
    end;

    -- Show / hide the small "focused" badge in the icon's bottom-right
    -- corner. Managers call this from their focus-change listener.
    SetFocused = function(self, focused)
        focused = focused and true or false
        if self._focused == focused then return end
        self._focused = focused
        if focused then 
            self.focusedBadge:Show()
            self.focusedHalo:Show()
        else 
            self.focusedBadge:Hide()
            self.focusedHalo:Hide()
        end
    end;

    -- Wire a left-click handler with click-vs-drag detection plus
    -- button-like feedback (1px press shift, toggle click sound). Frames
    -- don't have native OnClick (Buttons do); we record cursor pos on
    -- OnMouseDown and only fire fn(self) if OnMouseUp lands within the
    -- threshold — otherwise treat as drag-attempt. Drag-pan over pins
    -- won't pan the canvas (pin swallows mouse-down) but that's
    -- acceptable; the player drags from empty canvas.
    --
    -- isOnFn (optional): predicate returning true when the pin is in its
    -- "on" state at click time. Picks the toggle sound — CHECKBOX_OFF
    -- when transitioning off, CHECKBOX_ON when transitioning on, matching
    -- QuestPoiButton. Without it, every click plays CHECKBOX_ON.
    SetOnClick = function(self, fn, isOnFn)
        self._onClickFn = fn
        self._isOnFn    = isOnFn
        self:SetScript("OnMouseDown", function(_, button)
            if button ~= "LeftButton" then return end
            self._mouseDownX, self._mouseDownY = GetCursorPosition()
            self:_SetPressed(true)
        end)
        self:SetScript("OnMouseUp", function(_, button)
            if button ~= "LeftButton" then return end
            self:_SetPressed(false)
            local downX, downY = self._mouseDownX, self._mouseDownY
            self._mouseDownX, self._mouseDownY = nil, nil
            if not downX then return end
            local cx, cy = GetCursorPosition()
            local dx, dy = cx - downX, cy - downY
            if dx * dx + dy * dy > MAP_PIN_CLICK_THRESHOLD_SQ then return end
            if not self._onClickFn then return end
            local wasOn = self._isOnFn and self._isOnFn() or false
            PlaySound(wasOn
                and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
                or  SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            self._onClickFn(self)
        end)
    end;

    Destroy = function(self)
        MUI_MapPinScaleTracker:Unregister(self)
        self:Hide()
        self:ClearAllPoints()
    end;
}
