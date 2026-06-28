-- MapCornerButton: prototype of retail's WorldMap top-right corner
-- buttons (Map Filters + Map Pin / waypoint).
--
-- Shared chrome — all four exist on Era and match retail visually:
--   * Round disc       Interface\Minimap\UI-Minimap-Background    (25x25)
--   * Border ring      Interface\Minimap\MiniMap-TrackingBorder   (54x54)
--   * Hover highlight  Interface\Minimap\UI-Minimap-ZoomButton-Highlight (ADD)
--   * Active glow      Interface\Minimap\UI-Minimap-ZoomButton-Toggle    (ADD, 37x37)
--
-- Retail uses two atlas regions for the central glyphs that don't ship
-- on Era:
--   * Map-Filter-Button       — funnel/filter glyph for the filter btn
--   * Waypoint-MapPin-Untracked — pin glyph for the pin btn
-- Until the textures are imported, callers can pass any Blizzard icon
-- via SetIconPath as a placeholder; PLACEHOLDER_FILTER_ICON /
-- PLACEHOLDER_PIN_ICON below are reasonable temporary stand-ins.
--
-- Per-button extras:
--   * Map Pin button uses SetActive(true/false) to flash the toggle
--     glow whenever a waypoint is placed (retail behaviour).
--   * Filter button doesn't toggle the glow (its retail extras are a
--     filter-counter banner under the chrome — also retail-only atlas,
--     left as TODO).

-- Visible placeholders. Caller swaps in retail atlas regions when those
-- land via :SetIconPath(path) or a future :SetIconAtlas helper.
PLACEHOLDER_MAP_FILTER_ICON = "Interface\\Icons\\Trade_Engineering"
PLACEHOLDER_MAP_PIN_ICON    = "Interface\\Icons\\INV_Misc_Map_01"

class "MapCornerButton" : extends "Button" {
    __init = function(self, parent, name)
        Button.__init(self, parent, name)
        self:SetSize(20, 20)
        self:SetFrameStrata("HIGH")

        -- Background disc (BACKGROUND, default sub-level).
        self.bg = Texture(self, nil, "BACKGROUND")
        self.bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        self.bg:SetSize(16, 16)
        self.bg:CenterInParent()

        -- Center icon (ARTWORK).
        self.icon = Texture(self, nil, "ARTWORK")
        self.icon:SetSize(13, 13)
        self.icon:CenterInParent()

        -- Mouse-down dim over the icon (OVERLAY sub-0). Retail uses a
        -- plain colored rect at α=0.3 black that sits above the icon
        -- but below the border ring.
        self.iconDim = Texture(self, nil, "OVERLAY")
        self.iconDim:SetColorTexture(0, 0, 0, 0.3)
        self.iconDim:SetAllPoints(self.icon)
        self.iconDim:Hide()

        -- Border ring (OVERLAY sub-1, on top of iconDim).
        self.border = Texture(self, nil, "OVERLAY")
        self.border:SetDrawLayer("OVERLAY", 1)
        self.border:SetTextureRegion(MUI.TEX_SKIN .. "worldmap\\button-border", 64, 64, 14, 13, 36, 37)
        self.border:SetSize(20, 20)
        self.border:CenterInParent()

        -- Active toggle glow (OVERLAY sub-2, additive). Retail anchors
        -- this slightly outside the border at (-2, 1) for a visible
        -- bloom around the ring.
        self.activeGlow = Texture(self, nil, "OVERLAY")
        self.activeGlow:SetDrawLayer("OVERLAY", 2)
        self.activeGlow:SetTexture(MUI.TEX_SKIN .. "worldmap\\button-toggle")
        self.activeGlow:SetBlendMode("ADD")
        self.activeGlow:SetSize(23, 23)
        self.activeGlow:CenterInParent(0, 0)
        self.activeGlow:Hide()

        -- Hover highlight (additive, full-button overlay). Sized by the
        -- frame so the chrome highlight covers icon + ring evenly.
        self:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        local hl = self:GetHighlightTexture()
        if hl then 
            hl:SetBlendMode("ADD")
            hl:ClearAllPoints()
            hl:CenterAt(self.icon)
            hl:SetSize(18, 18)
        end

        -- Press feedback: shift icon 1 px down-right + show the dim
        -- overlay. Mirrors WorldMapTrackingPinButtonMixin:OnMouseDown.
        self:SetScript("OnMouseDown", function(_, btn)
            if btn ~= "LeftButton" then return end
            self.icon:ClearAllPoints()
            self.icon:CenterInParent(1, -1)
            self.iconDim:Show()
        end)
        self:SetScript("OnMouseUp", function(_, btn)
            if btn ~= "LeftButton" then return end
            self.icon:ClearAllPoints()
            self.icon:CenterInParent()
            self.iconDim:Hide()
        end)

        self._active = false
    end;

    -- Set the central glyph texture (placeholder until the retail
    -- atlas regions are imported). Pass a full texture path.
    SetIcon = function(self, path)
        self.icon:SetTexture(path)
    end;

    -- Toggle the additive "this button is on" bloom. Used by the pin
    -- button when a waypoint is placed; the filter button currently
    -- doesn't use it but inheriting it costs nothing.
    SetActive = function(self, active)
        active = active and true or false
        if self._active == active then return end
        self._active = active
        if active then self.activeGlow:Show() else self.activeGlow:Hide() end
    end;

    IsActive = function(self) return self._active end;
}
