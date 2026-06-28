-- MUI_MinimapPin: generic pin class for the minimap.
--
-- Each pin tracks a world position (uiMapId + normalised coords) and
-- projects itself onto the Minimap every tick relative to the player's
-- current position + minimap rotation + zoom. Pins hide automatically when
-- the player is on a different continent or outside the minimap's radius.
--
-- Designed for reuse/inheritance: subclass MinimapPin for quest-giver
-- markers, objective markers, herb/ore nodes, etc. Override OnEnter /
-- OnLeave / OnClick for interactivity.
--
-- Icon registry: hardcoded table MUI_MinimapPinIcons maps a short type name
-- to a 7-tuple of arguments for Texture:SetTextureRegion:
--     { texturePath, fileWidth, fileHeight, regionX, regionY, regionW, regionH }
-- Adjust coords here as the atlas evolves; pin code stays untouched.

local OBJECTS_ATLAS = "Interface\\AddOns\\ModernUI\\assets\\textures\\objecticonsatlas"

-- Pins fade in/out through this many pixels of minimap-edge band. A pin at
-- the exact circle boundary has alpha 0.5; it reaches full opacity half a
-- band inside the edge, fully transparent half a band outside.
local PIN_FADE_PX = 5

-- Frame level pins (and MinimapEdgeArrow) sit at, always above every
-- MinimapQuestObjectiveArea frame. Areas increment from 1 per instance, so this
-- leaves 9999 area slots before collision.
MUI_MINIMAP_PIN_FRAME_LEVEL = 10000

-- Classic Era minimap yard-radius per zoom level, split indoor vs outdoor.
-- Indoor maps (houses, inns, dungeon lobbies) display a zoomed-in view at
-- the same zoom level, so the yard radius they cover is smaller. Values
-- are halved diameters from HereBeDragons' measured table.
local MINIMAP_RADIUS_OUTDOOR = {
    [0] = 466.66 / 2,
    [1] = 400.00 / 2,
    [2] = 333.33 / 2,
    [3] = 266.66 / 2,
    [4] = 200.00 / 2,
    [5] = 133.33 / 2,
}

local MINIMAP_RADIUS_INDOOR = {
    [0] = 300 / 2,
    [1] = 240 / 2,
    [2] = 180 / 2,
    [3] = 120 / 2,
    [4] = 80  / 2,
    [5] = 50  / 2,
}

-- Indoor/outdoor tracking + yards-per-radius live as methods on the ticker
-- below so MinimapEdgeArrow (and any future minimap widget) can share them.

-- Icon type registry. Entries: { path, fileW, fileH, x, y, w, h }.
-- Coordinates are placeholders — update once the real icon atlas positions
-- are finalised.  Any pin asks for an icon by its type name here.
MUI_MinimapPinIcons = {
	["QuestArrow"]         = { OBJECTS_ATLAS, 1024, 1024, 458, 898, 21, 21 },
	["QuestAvailable"]     = { OBJECTS_ATLAS, 1024, 1024, 863, 131, 64, 64 },
	["QuestLowLevel"]      = { OBJECTS_ATLAS, 1024, 1024, 828, 621, 32, 32 },
	["Waypoint"]           = { OBJECTS_ATLAS, 1024, 1024, 902, 729, 19, 20 },
	["WaypointFocused"]    = { OBJECTS_ATLAS, 1024, 1024, 868, 729, 19, 20 },
    ["QuestCompletable"]   = { OBJECTS_ATLAS, 1024, 1024, 759, 790, 32, 32 },
    ["QuestTurnIn"]        = { OBJECTS_ATLAS, 1024, 1024, 556, 791, 32, 32 },
    ["QuestRepeatable"]    = { OBJECTS_ATLAS, 1024, 1024, 556, 689, 32, 32 },
	["ObjectiveGeneric"]   = { OBJECTS_ATLAS, 1024, 1024, 419, 417, 32, 32 },
    ["ObjectiveSlay"]      = { OBJECTS_ATLAS, 1024, 1024, 759, 757, 32, 32 },
    ["ObjectiveLoot"]      = { OBJECTS_ATLAS, 1024, 1024, 792, 757, 32, 32 },
    ["ObjectiveEvent"]     = { OBJECTS_ATLAS, 1024, 1024, 895, 451, 32, 32 },
    ["ObjectiveTalk"]      = { OBJECTS_ATLAS, 1024, 1024, 692, 519, 32, 32 },
    ["ObjectiveObject"]    = { OBJECTS_ATLAS, 1024, 1024, 453, 825, 32, 32 },
    ["ObjectiveInteract"]  = { OBJECTS_ATLAS, 1024, 1024, 862, 723, 32, 32 },
    ["NodeHerb"]           = { OBJECTS_ATLAS, 1024, 1024, 963, 520, 32, 32 },
    ["NodeOre"]            = { OBJECTS_ATLAS, 1024, 1024, 520, 552, 32, 32 },
    ["NodeFish"]           = { OBJECTS_ATLAS, 1024, 1024, 929, 519, 32, 32 },
    ["NodeTreasure"]       = { OBJECTS_ATLAS, 1024, 1024, 656, 756, 32, 32 },
    ["Repair"]             = { OBJECTS_ATLAS, 1024, 1024, 555, 927, 32, 32 },
    ["Innkeeper"]          = { OBJECTS_ATLAS, 1024, 1024, 521, 451, 32, 32 },
	["Stablemaster"]	   = { OBJECTS_ATLAS, 1024, 1024, 963, 588, 32, 32 },
    ["FlightMaster"]       = { OBJECTS_ATLAS, 1024, 1024, 419, 451, 32, 32 },
    ["Mailbox"]            = { OBJECTS_ATLAS, 1024, 1024, 453, 519, 32, 32 },
    ["Banker"]             = { OBJECTS_ATLAS, 1024, 1024, 385, 859, 32, 32 },
    ["Auctioneer"]         = { OBJECTS_ATLAS, 1024, 1024, 385, 757, 32, 32 },
    ["ClassTrainer"]       = { OBJECTS_ATLAS, 1024, 1024, 487, 416, 32, 32 },
    ["ProfessionTrainer"]  = { OBJECTS_ATLAS, 1024, 1024, 862, 519, 32, 32 },
}

-- Shared ticker: a single invisible frame whose OnUpdate fires every frame
-- (30–60Hz) and re-projects every registered pin. Per-pin work is trivial
-- (UnitPosition + subtract + SetPoint), so refreshing at full frame rate
-- keeps pin motion smooth as the player walks. HBD does the same.
-- Wrapped as a Frame so it participates in the usual widget hierarchy.
object "MinimapPinTicker" : extends "Frame" {
    __init = function(self)
        Frame.__init(self, "Frame", nil, "MUI_MinimapPinTicker")
        self.pins = {}
        -- Indoor cache refreshed on zoom events. See :RefreshIndoors() — uses
        -- HBD's cvar-swap trick to cover the edge case where the player's
        -- outdoor-zoom and indoor-zoom preferences are identical (e.g. both
        -- at max). In that case the naive "cvar == current zoom?" test
        -- can't distinguish.
        self._indoors = false
        self:SetScript("OnUpdate", function() self:Tick() end)
        self:RegisterEventHandler("MINIMAP_UPDATE_ZOOM",    function() self:RefreshIndoors() end)
        self:RegisterEventHandler("PLAYER_ENTERING_WORLD",  function() self:RefreshIndoors() end)
    end;

    Register = function(self, pin)   self.pins[pin] = true end;
    Unregister = function(self, pin) self.pins[pin] = nil  end;

    Tick = function(self)
        for pin in pairs(self.pins) do
            if pin.Refresh then pin:Refresh() end
        end
    end;

    RefreshIndoors = function(self)
        if C_Minimap and C_Minimap.GetViewRadius then
            -- Radius API is authoritative; indoor flag becomes irrelevant.
            return
        end
        local zoom = MUI_Minimap:GetZoom()
        -- When both zoom preferences are the same, SetZoom(currentZoom)
        -- doesn't visibly change anything, but SetZoom(different) writes to
        -- whichever cvar matches the current location (minimapZoom outside,
        -- minimapInsideZoom inside). Reading back then reveals which.
        if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
            MUI_Minimap:SetZoom(zoom < 2 and zoom + 1 or zoom - 1)
        end
        self._indoors = tonumber(GetCVar("minimapZoom")) ~= MUI_Minimap:GetZoom()
        MUI_Minimap:SetZoom(zoom)
    end;

    YardsPerRadius = function(self)
        if C_Minimap and C_Minimap.GetViewRadius then
            return C_Minimap.GetViewRadius()
        end
        local zoom = MUI_Minimap:GetZoom()
        local tbl = self._indoors and MINIMAP_RADIUS_INDOOR or MINIMAP_RADIUS_OUTDOOR
        return tbl[zoom] or 150
    end;
}

class "MinimapPin" : extends "Frame" {
    __init = function(self, name, size)
        Frame.__init(self, "Frame", Frame(Minimap), name)
        size = size or 12
        self:SetSize(size, size)
        self:SetFrameStrata("MEDIUM")
        self:SetFrameLevel(MUI_MINIMAP_PIN_FRAME_LEVEL)
        self:EnableMouse(true)

        self.icon = Texture(self, nil, "OVERLAY")
        self.icon:FillParent()
        -- Pin position is re-set every frame at fractional-pixel precision;
        -- disable the default pixel-grid snapping so motion looks smooth.
        self.icon:SetSubpixelRendering(true)

        self.uiMapId = nil
        self.normX = 0
        self.normY = 0

        self:Hide()
        MUI_MinimapPinTicker:Register(self)
    end;

    -- ---- configuration ---------------------------------------------------

    -- Anchor the pin to a world position.  Until this is called the pin is
    -- invisible.  Re-calling moves it.  Computes world yards ONCE and caches
    -- them (HBD pattern) — the game-API map-to-world conversion doesn't need
    -- to run every tick.
    SetWorldPosition = function(self, uiMapId, normX, normY)
        self.uiMapId = uiMapId
        self.normX   = normX
        self.normY   = normY
        self._worldX, self._worldY, self._worldCont =
            MUI_MapMath:MapToWorld(uiMapId, normX, normY)
    end;

    -- Look up and apply an icon by type name from MUI_MinimapPinIcons.
    SetIconType = function(self, typeName)
        local spec = MUI_MinimapPinIcons[typeName]
        if not spec then
            MUI.Print("|cffff4040MUI_MinimapPin|r unknown icon type: " .. tostring(typeName))
            return
        end
        self.icon:SetTextureRegion(spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], spec[7])
    end;

    -- Arbitrary 7-arg icon override (bypasses the registry).
    SetIcon = function(self, path, fileW, fileH, x, y, w, h)
        self.icon:SetTextureRegion(path, fileW, fileH, x, y, w, h)
    end;

    SetIconTint = function(self, r, g, b, a)
        self.icon:SetVertexColor(r, g, b, a or 1)
    end;

    -- ---- lifecycle -------------------------------------------------------

    -- Unregister from the ticker and hide. Call when a pin is permanently
    -- finished with (e.g. quest completed).
    Destroy = function(self)
        MUI_MinimapPinTicker:Unregister(self)
        self:Hide()
        self:ClearAllPoints()
    end;

    -- ---- per-tick projection --------------------------------------------

    -- Called by the shared ticker ~10×/s.  Computes the player-to-pin yard
    -- delta via MUI_MapMath, applies minimap rotation + zoom, and positions
    -- the pin relative to the Minimap center. Hides when off-continent or
    -- outside the minimap radius.
    Refresh = function(self)
        local pinWX, pinWY = self._worldX, self._worldY
        if not pinWX then self:Hide(); return end

        -- Use UnitPosition for the player — precise world yards regardless of
        -- which uiMap the minimap currently displays. Avoids the precision
        -- loss that GetPlayerMapPosition → GetWorldPosFromMapPos suffers at
        -- high zoom levels inside small indoor maps (the indoor map covers a
        -- tiny world region, so sub-yard errors in the normalised player pos
        -- blow up into multi-yard errors after the world transform).
        -- UnitPosition returns (Y, X, Z, instanceID) — Y is the N-S axis.
        local playerY, playerX = UnitPosition("player")
        if not playerX or not playerY then self:Hide(); return end

        -- Classic Era C_Map.GetWorldPosFromMapPos axis convention (empirically
        -- verified by walking):  Vector2D .x = north-south, +north
        --                        Vector2D .y = east-west,   +west
        -- UnitPosition uses the same sign conventions: first return is N-S
        -- (+north), second is E-W (+west).
        -- Screen convention used by SetPoint: +pxX = right (east), +pxY = up (north).
        local east  = playerX - pinWY              -- pin east of player (+east)
        local north = pinWX  - playerY             -- pin north of player (+north)

        if GetCVar("rotateMinimap") == "1" then
            local facing = GetPlayerFacing() or 0
            local c, s = math.cos(facing), math.sin(facing)
            east, north = east * c + north * s, -east * s + north * c
        end

        local zoomYards = MUI_MinimapPinTicker:YardsPerRadius()
        local radiusPx  = MUI_Minimap:GetWidth() * 0.5
        local pxX = (east  / zoomYards) * radiusPx
        local pxY = (north / zoomYards) * radiusPx

        -- Distance from minimap centre. The effective radius shrinks by the
        -- pin's own half-width so the icon's visible *edge* — not its centre —
        -- is what touches the minimap border at alpha 0. Without this offset
        -- the pin drifts past the border before fully disappearing.
        local dist = math.sqrt(pxX * pxX + pxY * pxY)
        local pinHalf = self:GetWidth() * 0.5
        local effectiveR = radiusPx - pinHalf
        if dist > effectiveR then self:Hide(); return end

        local fadeStart = effectiveR - PIN_FADE_PX
        local alpha = 1
        if dist > fadeStart then
            alpha = (effectiveR - dist) / PIN_FADE_PX
            if alpha < 0 then alpha = 0 elseif alpha > 1 then alpha = 1 end
        end

        self:SetAlpha(alpha * (self._dimFactor or 1))
        self:ClearAllPoints()
        self:SetPoint("CENTER", Minimap, "CENTER", pxX, pxY)
        self:Show()
    end;

    -- Multiplicative alpha applied on top of the per-tick edge-fade alpha.
    -- Used by MinimapQuestPinManager to dim unfocused-quest pins to 0.5.
    SetDimFactor = function(self, factor)
        self._dimFactor = factor or 1
    end;
}
