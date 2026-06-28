-- MapWaypointManager: user-placed waypoint marker. Mirrors retail's
-- WorldMapTrackingPin behaviour adapted to Classic Era.
--
-- Single global slot — placing a new one replaces the old.
--
-- Activation paths:
--   * Toggle the corner Pin button → enter "place mode". A Waypoint icon
--     follows the cursor while it's over the world-map canvas. LMB
--     (click, not drag) or RMB on the canvas places the marker.
--   * Ctrl + LMB (click, not drag) on the canvas places the marker
--     directly without entering place mode. Convenience shortcut.
--
-- Removal: Ctrl + click on the placed world-map pin clears it.
--
-- Visibility: a MapPin on the world-map canvas (whenever the projection
-- onto the displayed map is in [0..1]^2) and a MinimapPin in the
-- standard ticker pool. The MapPin is focusable as kind "waypoint";
-- focused state swaps the central glyph from "Waypoint" to
-- "WaypointFocused" and lights the standard MapPin focus halo / badge.
--
-- Pin-button glow follows `placeMode OR hasWaypoint` so the corner
-- button shows "armed" while the player is placing AND while a
-- waypoint sits on the map.

local PIN_FRAME_NAME    = "MUI_MapWaypointPin"
local FOCUS_KEY         = "user"

class "MapWaypointManager" : extends "Frame" {
    __init = function(self, onModeChanged)
        Frame.__init(self, "Frame", nil, "MUI_MapWaypointManagerDriver")
        -- Manager frame must be shown so OnUpdate (cursor-follower
        -- positioning) fires.
        self:Show()

        self._waypoint   = nil    -- {wx, wy, continent, uiMapId, normX, normY}
        self._mapPin     = nil
        self._minimapPin = nil
        self._placeMode  = false
        self._onModeChanged = onModeChanged

        self:_BuildCursorFollower()
        self:_WireCanvasClicks()
        self:_RegisterFocusKind()

        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            self:_RefreshMapPin()
        end)
        
        MUI_FocusManager:RegisterChangeListener(function()
            self:_RefreshFocusVisuals()
        end)

        -- OnUpdate drives the cursor follower while in place mode.
        -- Polling cursor pos + IsMouseOver each frame is cheap; we
        -- bail immediately when not in place mode so the idle case
        -- pays nothing.
        self:SetScript("OnUpdate", function() self:_TickFollower() end)
    end;

    -- ===== public API =====

    TogglePlaceMode = function(self)
        if self._placeMode then
            self:ExitPlaceMode()
        else
            self:EnterPlaceMode()
        end
    end;

    EnterPlaceMode = function(self)
        if self._placeMode then return end
        self._placeMode = true
        if self._onModeChanged then
            self._onModeChanged(self._placeMode)
        end
    end;

    ExitPlaceMode = function(self)
        if not self._placeMode then return end
        self._placeMode = false
        self._cursorFollower:Hide()
        if self._onModeChanged then
            self._onModeChanged(self._placeMode)
        end
    end;

    -- Drop a waypoint at the current cursor position on the world map.
    -- Replaces any existing waypoint. Exits place mode on success.
    PlaceAtCursor = function(self)
        local nx, ny = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
        if not nx or nx < 0 or nx > 1 or ny < 0 or ny > 1 then return end
        local uiMapId = WorldMapFrame:GetMapID()
        if not uiMapId then return end
        local wx, wy, cont = MUI_MapMath:MapToWorld(uiMapId, nx, ny)
        if not wx then return end

        -- Resolve the underlying ZONE the waypoint sits in for the
        -- tooltip's "Map coordinates: x.x, y.y (Zone Name)" line. When
        -- the player places on a continent / world map, uiMapId is NOT
        -- a zone, so we ask MUI_MapMath:GetBestMapForWorld to find the
        -- best containing zone for these world coords.
        local zoneUiMap = MUI_MapMath:GetBestMapForWorld(cont, wx, wy)
        local zoneName, zoneNX, zoneNY
        if zoneUiMap then
            local info = C_Map.GetMapInfo(zoneUiMap)
            zoneName = info and info.name
            zoneNX, zoneNY = MUI_MapMath:WorldToMap(zoneUiMap, wx, wy, cont)
        end

        self._waypoint = {
            wx = wx, wy = wy, continent = cont,
            uiMapId = uiMapId, normX = nx, normY = ny,
            zoneUiMap = zoneUiMap, zoneName = zoneName,
            zoneNormX = zoneNX, zoneNormY = zoneNY,
        }
        self:ExitPlaceMode()
        self:_RefreshMapPin()
        self:_RefreshMinimapPin()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end;

    ClearWaypoint = function(self)
        if not self._waypoint then return end
        self._waypoint = nil
        if self._mapPin then
            self._mapPin:Destroy()
            self._mapPin = nil
        end
        if self._minimapPin then
            self._minimapPin:Destroy()
            self._minimapPin = nil
        end
        if MUI_FocusManager:IsFocused("waypoint", FOCUS_KEY) then
            MUI_FocusManager:SetFocus(nil)
        end
    end;

    HasWaypoint   = function(self) return self._waypoint ~= nil end;
    IsInPlaceMode = function(self) return self._placeMode end;

    -- ===== internals =====

    _BuildCursorFollower = function(self)
        local f = Frame("Frame", UIParent, "MUI_WaypointCursorFollower")
        f:SetSize(15, 15)
        f:SetFrameStrata("TOOLTIP")
        f:Hide()

        local icon = Texture(f, nil, "OVERLAY")
        local spec = MUI_MapPinIcons["Waypoint"]
        if spec then
            icon:SetTextureRegion(spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], spec[7])
        end
        icon:SetAllPoints(f)

        local pointer = Texture(f)
        pointer:SetTexture(MUI.TEX_BASE .. "cursor-pointer")
        pointer:SetSize(7)
        pointer:AlignParentTopLeft(-1, -1)

        self._cursorFollower = f
    end;

    _StickToCursor = function(self)
        local x, y = GetCursorPosition()
        if not x then return end
        local s = self._cursorFollower:GetEffectiveScale()
        if not s or s == 0 then return end
        self._cursorFollower:ClearAllPoints()
        self._cursorFollower:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
        if not self._cursorFollower:IsShown() then self._cursorFollower:Show() end
    end;

    _TickFollower = function(self)

        local sc = WorldMapFrame.ScrollContainer
        if not sc or not sc:IsMouseOver() or not WorldMapFrame:IsShown() then
            if self._cursorFollower:IsShown() then self._cursorFollower:Hide() end
            return
        end

        if IsControlKeyDown() or self._placeMode then
            self:_StickToCursor()
        else
            if self._cursorFollower:IsShown() then self._cursorFollower:Hide() end
        end
    end;

    _WireCanvasClicks = function(self)
        if not WorldMapFrame or not WorldMapFrame.AddCanvasClickHandler then return end

        -- Native MapCanvas click pipeline: ProcessCanvasClickHandlers
        -- runs BEFORE NavigateToCursor / TryPanOrZoomOnClick. Returning
        -- true from a handler consumes the click and suppresses the
        -- native zone-navigation + zoom-in. The ScrollContainer's
        -- click-vs-drag detection has already gated us by this point,
        -- so no manual threshold needed.
        --
        -- Signature (Blizzard MapCanvasMixin): (map, button, cursorX, cursorY)
        -- where cursorX/Y are 0..1 normalized onto the displayed map.
        WorldMapFrame:AddCanvasClickHandler(function(_, button, _cx, _cy)
            -- Pin click landed on the waypoint pin itself — let the
            -- pin's own click handler run and don't consume here. The
            -- pin handles toggle-focus / Ctrl-click clear.
            if self._mapPin and self._mapPin:IsMouseOver() then
                return false
            end

            local ctrl   = IsControlKeyDown()
            local active = self._placeMode or ctrl
            if not active then return false end

            -- Both LMB and RMB place. Returning true consumes the
            -- click → no zone navigation, no zoom-in.
            self:PlaceAtCursor()
            return true
        end, 100)
    end;

    _RegisterFocusKind = function(self)
        if not MUI_FocusManager then return end
        MUI_FocusManager:RegisterKind("waypoint", {
            GetTargetPoints = function()
                if not self._waypoint then return nil end
                return {
                    {
                        points    = { { self._waypoint.wx, self._waypoint.wy } },
                        continent = self._waypoint.continent,
                    },
                }
            end,
            FillTooltip = function()
                MUI_Tooltip:AddTitle("Waypoint")
            end,
        })
    end;

    _RefreshMapPin = function(self)
        if self._mapPin then
            self._mapPin:Destroy()
            self._mapPin = nil
        end
        if not self._waypoint then return end
        local uiMapId = WorldMapFrame and WorldMapFrame:GetMapID()
        if not uiMapId then return end
        local nx, ny = MUI_MapMath:WorldToMap(
            uiMapId,
            self._waypoint.wx, self._waypoint.wy,
            self._waypoint.continent)
        if not nx or not ny then return end
        if nx < 0 or nx > 1 or ny < 0 or ny > 1 then return end

        local pin = MapPin(PIN_FRAME_NAME, 15)
        pin._focusKind = "waypoint"
        pin._focusKey  = FOCUS_KEY
        local focused = MUI_FocusManager:IsFocused("waypoint", FOCUS_KEY)
        pin.focusedBadge:SetVertexColor(0, 0, 0, 0)
        pin.focusedHalo:SetVertexColor(0, 0, 0, 0)
        pin:SetIconType(focused and "WaypointFocused" or "Waypoint")
        pin:SetMapPosition(uiMapId, nx, ny)
        pin:SetFocused(focused)
        pin:SetOnClick(
            function()
                if IsControlKeyDown() then
                    self:ClearWaypoint()
                    return
                end
                if MUI_FocusManager:IsFocused("waypoint", FOCUS_KEY) then
                    MUI_FocusManager:SetFocus(nil)
                else
                    MUI_FocusManager:SetFocus("waypoint", FOCUS_KEY)
                end
                self:_RefreshMinimapPin()
            end,
            function() return MUI_FocusManager:IsFocused("waypoint", FOCUS_KEY) end
        )
        pin:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            tooltip:AddLine("Waypoint", 1, 1, 1, false, 13)
            local wp = self._waypoint
            local coordLine
            if wp and wp.zoneName and wp.zoneNormX and wp.zoneNormY then
                coordLine = string.format(
                    "Map coordinates: %.1f, %.1f (%s)",
                    wp.zoneNormX * 100, wp.zoneNormY * 100, wp.zoneName)
            else
                coordLine = "Map coordinates: ?"
            end
            tooltip:AddLine(coordLine, 1, 0.82, 0, true)
            tooltip:AddBlank()
            tooltip:AddLine("<Shift-click to share coordinates in chat>", 0, 1, 0, true)
            tooltip:AddLine("<Ctrl-Left Click to remove pin>", 0, 1, 0, true)
        end)
        self._mapPin = pin
    end;

    _RefreshMinimapPin = function(self)
        if self._minimapPin then
            self._minimapPin:Destroy()
            self._minimapPin = nil
        end
        if not self._waypoint then return end
        local pin = MinimapPin("MUI_MinimapWaypointPin", 14)

        local focused = MUI_FocusManager:IsFocused("waypoint", FOCUS_KEY)

        pin:SetIconType(focused and "WaypointFocused" or "Waypoint")
        pin:SetWorldPosition(
            self._waypoint.uiMapId,
            self._waypoint.normX,
            self._waypoint.normY)
        pin:Show()
        self._minimapPin = pin
    end;

    -- Sync icon variants when focus state flips. World-map pin swaps
    -- main glyph; minimap pin always uses the plain Waypoint variant
    -- (mirrors the "minimap pins are non-interactive" rule — no need
    -- to differentiate focus state there).
    _RefreshFocusVisuals = function(self)
        if not self._mapPin then return end
        local focused = MUI_FocusManager:IsFocused("waypoint", FOCUS_KEY)
        self._mapPin:SetFocused(focused)
        self._mapPin:SetIconType(focused and "WaypointFocused" or "Waypoint")
    end;
}
