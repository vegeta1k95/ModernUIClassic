-- MinimapEdgeArrow: a chevron at the minimap border that points toward a
-- world position the player can't see yet. Used for off-zone quest
-- objectives: the pin manager creates an arrow for every spec whose areaId
-- differs from the player's current zone, so the player sees an
-- edge-clamped hint instead of the pin being off-screen entirely.
--
-- Registered with MUI_MinimapPinTicker so Refresh() runs every frame along
-- with in-zone pins. Same axis and rotation conventions as MinimapPin.
--
-- Cross-continent targets (different instance from the player) hide — there
-- is no meaningful 2D direction to point in that case.

class "MinimapEdgeArrow" : extends "Frame" {
    __init = function(self, name, size)
        Frame.__init(self, "Frame", Frame(Minimap), name)
        size = size or 14
        self:SetSize(size, size)
        self:SetFrameStrata("MEDIUM")
        self:SetFrameLevel(MUI_MINIMAP_PIN_FRAME_LEVEL)

        self._icon = Texture(self, nil, "OVERLAY")
        self._icon:FillParent()
        self._icon:SetSubpixelRendering(true)

        self._uiMapId = nil
        self._normX   = 0
        self._normY   = 0

        self:Hide()
        MUI_MinimapPinTicker:Register(self)
    end;

    -- Same shape as MinimapPin:SetWorldPosition so the pin manager can
    -- feed resolved specs into either widget type uniformly.
    SetWorldPosition = function(self, uiMapId, normX, normY)
        self._uiMapId = uiMapId
        self._normX   = normX
        self._normY   = normY
        self._worldX, self._worldY, self._worldCont =
            MUI_MapMath:MapToWorld(uiMapId, normX, normY)
    end;

    SetIconType = function(self, typeName)
        local spec = MUI_MinimapPinIcons[typeName]
        if not spec then
            MUI.Print(
                "|cffff4040MUI_MinimapEdgeArrow|r unknown icon type: " .. tostring(typeName))
            return
        end
        self._icon:SetTextureRegion(spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], spec[7])
    end;

    SetIconTint = function(self, r, g, b, a)
        self._icon:SetVertexColor(r, g, b, a or 1)
    end;

    Destroy = function(self)
        MUI_MinimapPinTicker:Unregister(self)
        self:Hide()
        self:ClearAllPoints()
    end;

    -- Called by the shared ticker every frame. Computes the player→target
    -- direction in world yards, clamps to the minimap border, rotates the
    -- chevron to face the target. No distance scaling — the arrow is purely
    -- directional (it's an "it's thataway" hint).
    Refresh = function(self)
        local pinWX, pinWY = self._worldX, self._worldY
        if not pinWX then self:Hide(); return end

        local playerY, playerX, _, playerCont = UnitPosition("player")
        if not playerX or not playerY then self:Hide(); return end

        -- Cross-continent hint has no 2D direction — hide.
        if self._worldCont and playerCont and self._worldCont ~= playerCont then
            self:Hide(); return
        end

        -- Same axis convention as MinimapPin.
        -- Vector2D .x = N-S, +north; .y = E-W, +west.
        local east  = playerX - pinWY
        local north = pinWX  - playerY

        if GetCVar("rotateMinimap") == "1" then
            local facing = GetPlayerFacing() or 0
            local c, s = math.cos(facing), math.sin(facing)
            east, north = east * c + north * s, -east * s + north * c
        end

        local dist = math.sqrt(east * east + north * north)
        if dist < 0.001 then self:Hide(); return end

        local radiusPx  = MUI_Minimap:GetWidth() * 0.5 - 2
        local arrowHalf = self:GetWidth() * 0.5
        local effR      = radiusPx - arrowHalf

        local nx = east  / dist
        local ny = north / dist

        self:ClearAllPoints()
        self:SetPoint("CENTER", Minimap, "CENTER", nx * effR, ny * effR)

        -- Atlas chevron faces +east (right). Rotate CCW by atan2(ny, nx).
        self._icon:SetRotation(math.atan2(ny, nx) - math.pi/2)

        self:SetAlpha(self._dimFactor or 1)
        self:Show()
    end;

    -- Multiplicative alpha applied in Refresh. Used to dim arrows for
    -- unfocused quests; matches MinimapPin:SetDimFactor.
    SetDimFactor = function(self, factor)
        self._dimFactor = factor or 1
    end;
}
