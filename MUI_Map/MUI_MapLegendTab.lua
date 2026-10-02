-- MUI_MapLegendTab: the world map's legend, after retail's Map Legend tab —
-- a categorised two-column grid of every mark our map draws. Hovering a row glows the
-- matching pins on the map.
--
-- Also holds MapSideTab, the retail side tab button the map module hangs
-- off the panel's right edge to switch between the quest log and the legend.
--
-- Construction:
--   MapLegendTab(parent)   parent — the map module's tab holder

local LOG_TEX    = MUI.TEX_SKIN .. "worldmap\\questlog"
local LOG_BG_TEX = MUI.TEX_SKIN .. "worldmap\\questlog-bg"

local ROW_H     = 32
local SIDE_PAD  = 4       -- left / right of the grid
local HEADER_H  = 24
local ICON_SLOT = 24      -- box an icon is fitted into
local CAT_GAP   = 8

-- Row specs. `pin` is a MUI_MapPinIcons type: the row's icon, and the pins
-- it stands for (those whose type starts with `pinPrefix` when given).
-- `poi` is a quest POI kind (QuestPoiButton:GetLegendKind).
local function LegendCategories()
    local faction = UnitFactionGroup("player")
    if faction ~= "Horde" and faction ~= "Alliance" then faction = "Neutral" end
    return {
        { title = "Quests", rows = {
            { pin = "Quest",                 label = "Available Quest" },
            { pin = "QuestPvP",              label = "Available PvP" },
            { pin = "QuestRepeatable",       label = "Repeatable" },
            { pin = "QuestRepeatableTurnIn", label = "Repeat. Turn-in" },
            { pin = "Hub",                   label = "Quest Hub" },
            { poi = "inprogress",            label = "In Progress" },
            { poi = "turnin",                label = "Turn-in" },
            { poi = "kill",                  label = "Kill Quest" },
            { poi = "loot",                  label = "Collect Quest" },
            { poi = "elite",                 label = "Elite Quest" },
            { poi = "dungeon",               label = "Dungeon Quest" },
            { poi = "raid",                  label = "Raid Quest" },
            { poi = "pvp",                   label = "PvP Quest" },
        } },
        { title = "Activities", rows = {
            { pin = "Dungeon", label = "Dungeon" },
            { pin = "Raid",    label = "Raid" },
        } },
        { title = "Movement", rows = {
            { pin = "FlightMaster" .. faction, pinPrefix = "FlightMaster", label = "Flight Point" },
            { pin = "Transport" .. faction,    pinPrefix = "Transport",    label = "Transport" },
            { pin = "Waypoint",                pinPrefix = "Waypoint",     label = "Waypoint" },
        } },
    }
end

-- ---------------------------------------------------------------------
-- MapSideTab: retail's side tab (plate + icon, glow when hovered /
-- selected). iconX/Y and inactiveX/Y are the 58px icon cells on LOG_TEX.
-- ---------------------------------------------------------------------
class "MapSideTab" : extends "Frame" {
    __init = function(self, parent, name, iconX, iconY, inactiveX, inactiveY)
        Frame.__init(self, "Frame", parent, name)
        self:SetSize(43, 55)
        self:EnableMouse(true)

        self._iconPos = { iconX, iconY, inactiveX, inactiveY }
        self._selected = false

        local plate = Texture(self, nil, "BACKGROUND")
        plate:SetTextureRegion(LOG_TEX, 1024, 1024, 617, 0, 102, 122)
        plate:SetSize(51, 61)
        plate:CenterInParent()

        self._icon = Texture(self, nil, "ARTWORK")
        self._icon:SetSize(29, 29)
        self._icon:CenterInParent(-2, 0)

        self._select = Texture(self, nil, "OVERLAY")
        self._select:SetTextureRegion(LOG_TEX, 1024, 1024, 823, 0, 102, 122)
        self._select:SetSize(51, 61)
        self._select:CenterInParent()
        self._select:Hide()

        self._hover = Texture(self, nil, "OVERLAY")
        self._hover:SetTextureRegion(LOG_TEX, 1024, 1024, 719, 0, 102, 122)
        self._hover:SetSize(51, 61)
        self._hover:CenterInParent()
        self._hover:SetBlendMode("ADD")
        self._hover:Hide()

        self:SetScript("OnEnter", function() self._hover:Show() end)
        self:SetScript("OnLeave", function() self._hover:Hide() end)
        self:SetScript("OnMouseUp", function()
            if self:IsMouseOver() and self.OnClick then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                self:OnClick()
            end
        end)

        self:SetSelected(false)
    end;

    SetSelected = function(self, selected)
        self._selected = selected
        local p = self._iconPos
        self._icon:SetTextureRegion(LOG_TEX, 1024, 1024,
            selected and p[1] or p[3], selected and p[2] or p[4], 58, 58)
        self._icon:SetSize(29, 29)
        if selected then self._select:Show() else self._select:Hide() end
    end;
}

-- ---------------------------------------------------------------------
-- MapLegendRow: icon + label; hover glows the pins it stands for.
-- ---------------------------------------------------------------------
class "MapLegendRow" : extends "Frame" {
    __init = function(self, parent, data)
        Frame.__init(self, "Frame", parent)
        self:SetHeight(ROW_H)
        self:EnableMouse(true)
        self.data = data

        self._hover = Texture(self, nil, "BACKGROUND")
        self._hover:SetTextureRegion(LOG_TEX, 1024, 1024, 0, 692, 616, 105)
        self._hover:FillParent()
        self._hover:Hide()

        local slot = Frame("Frame", self)
        slot:SetSize(ICON_SLOT, ICON_SLOT)
        slot:AlignParentLeft(4)

        if data.poi then
            -- The real POI button, so the row shows exactly what the map does.
            local poi = QuestPoiButton(slot, nil, ICON_SLOT + 4)
            poi:EnableMouse(false)
            poi:ClearAllPoints()
            poi:CenterInParent()
            if data.poi == "turnin" then
                poi:SetComplete(true)
            elseif data.poi ~= "inprogress" then
                poi:SetGlyph(data.poi)
            end
        else
            local spec = MUI_MapPinIcons[data.pin]
            local icon = Texture(slot, nil, "ARTWORK")
            icon:SetTextureRegion(spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], spec[7])
            local fit = ICON_SLOT / math.max(spec[6], spec[7])
            icon:SetSize(spec[6] * fit, spec[7] * fit)
            icon:CenterInParent()
            if spec.tint then icon:SetVertexColor(spec.tint[1], spec.tint[2], spec.tint[3]) end
        end

        local label = FontString(self, nil, "ARTWORK")
        label:SetFont(MUI.FONT, 11.5)
        label:SetShadowOffset(1, -1)
        label:SetTextColor(1, 0.82, 0, 1)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        label:RightOf(slot, 5)
        label:SetText(data.label)
        self._label = label

        self:SetScript("OnEnter", function()
            self._hover:Show()
            self:_SetPinGlow(true)
        end)
        self:SetScript("OnLeave", function()
            self._hover:Hide()
            self:_SetPinGlow(false)
        end)
        self:SetScript("OnHide", function()
            self._hover:Hide()
            self:_SetPinGlow(false)
        end)
    end;

    -- One line; the explicit width makes an overlong label end in "...".
    SetColumnWidth = function(self, width)
        self:SetWidth(width)
        self._label:SetWidth(math.max(width - ICON_SLOT - 11, 0.1))
    end;

    _SetPinGlow = function(self, on)
        local data = self.data
        if data.poi then
            -- The tab is built before the POI manager (rows can hide first).
            local manager = MUI_ModuleMap.questPoiManager
            if not manager then return end
            manager:ForEachButton(function(poi)
                poi:SetLegendGlow(on and poi:GetLegendKind() == data.poi)
            end)
            return
        end
        MUI_MapPinScaleTracker:ForEachPin(function(pin)
            local iconType = pin.iconType
            local match = iconType ~= nil and (iconType == data.pin
                or (data.pinPrefix ~= nil and string.find(iconType, data.pinPrefix, 1, true) == 1))
            pin:SetLegendGlow(on and match)
        end)
    end;
}

-- ---------------------------------------------------------------------
-- MapLegendTab
-- ---------------------------------------------------------------------
class "MapLegendTab" : extends "Frame" {
    __init = function(self, parent)
        Frame.__init(self, "Frame", parent, "MUI_MapLegendTab")
        self:FillParent()

        self:_BuildChrome()
        self:_BuildContent()

        self.slider:SetMinMax(0, 0)
        self.slider.OnScroll = function(_, value)
            self.scroll:SetVerticalScroll(value)
        end
        self.scroll:EnableMouseWheel(true)
        self.scroll:SetScript("OnMouseWheel", function(_, delta)
            self.slider:SetValue(self.slider:GetValue() - delta * 20)
        end)

        self:SetScript("OnSizeChanged", function() self:_RefreshScroll() end)
        self:SetScript("OnShow", function() self:_RefreshScroll() end)
    end;

    -- Same chrome as the quest log tab: slider, list bg, border, top art.
    _BuildChrome = function(self)
        self.slider = MinimalScrollBar(self, nil, 8, 8)
        self.slider:AlignParentRight(7)
        self.slider.upBtn:SetScale(1.1)
        self.slider.downBtn:SetScale(1.1)
        self.slider:AlignParentBottom(6)
        self.slider:AlignTop(self, 29)
        self.slider:SetScale(0.6)

        local container = Frame("Frame", self)
        container:LeftOf(self.slider, 6)
        container:AlignParentLeft()
        container:AlignParentBottom(5)
        container:AlignParentTop(17)

        local bg = Texture(container, nil, "BACKGROUND")
        bg:FillParentPadding(0, 0, 0, 0)
        bg:SetTextureRegion(LOG_BG_TEX, 2048, 1024, 616, 0, 616, 1022)

        local overlay = Frame("Frame", container)
        overlay:FillParent()
        overlay:SetFrameLevel(container:GetFrameLevel() + 50)

        local border = NineSlice(overlay)
        border:SetFromTextureRegion("skin\\worldmap\\questlog", 1024, 1024, 2, 801, 212, 212, 54, 54, 54, 54, 0.32)
        border:FillParent(-2)

        local topArt = Texture(border, nil, "OVERLAY")
        topArt:SetTextureRegion(LOG_TEX, 1024, 1024, 621, 126, 86, 32)
        topArt:AlignParentTop(-1)
        topArt:SetSize(86, 32)
        topArt:SetScale(0.32)

        local title = FontString(self, nil, "ARTWORK")
        title:SetFont(MUI.FONT, 9)
        title:SetShadowOffset(1, -1)
        title:SetTextColor(1, 0.82, 0, 1)
        title:AlignParentTop(4)
        title:SetText("Map Legend")

        self.scroll = ScrollFrame(container)
        self.scroll:FillParentPadding(2, 4, 2, 4)
    end;

    _BuildContent = function(self)
        self.scrollChild = Frame("Frame", self.scroll)
        self.scrollChild:SetSize(1, 1)
        self.scrollChild:SetScale(0.7)
        self.scroll:SetScrollChild(self.scrollChild)

        self._rows = {}
        local y = 6
        for _, category in ipairs(LegendCategories()) do
            local header = FontString(self.scrollChild, nil, "ARTWORK")
            header:SetFont(MUI.FONT, 14)
            header:SetShadowOffset(1, -1)
            header:SetTextColor(1, 1, 1, 1)
            header:SetJustifyH("LEFT")
            header:AlignParentTopLeft(y + 4, 8)
            header:SetText(category.title)
            y = y + HEADER_H

            -- Two-column grid; the columns are placed in _RefreshScroll,
            -- once the viewport width is known.
            for i, data in ipairs(category.rows) do
                local row = MapLegendRow(self.scrollChild, data)
                row.column = (i - 1) % 2
                row.top = y + math.floor((i - 1) / 2) * ROW_H
                self._rows[#self._rows + 1] = row
            end
            y = y + math.ceil(#category.rows / 2) * ROW_H + CAT_GAP
        end
        self._contentHeight = y
    end;

    _RefreshScroll = function(self)
        local s         = self.scrollChild:GetScale()
        local viewportH = self.scroll:GetHeight() / s
        local viewportW = self.scroll:GetWidth() / s
        local childH    = math.max(self._contentHeight, viewportH)

        self.scrollChild:SetWidth(viewportW)
        self.scrollChild:SetHeight(childH)

        local columnW = (viewportW - SIDE_PAD * 2) / 2
        for _, row in ipairs(self._rows) do
            row:SetColumnWidth(math.max(columnW, 0.1))
            row:ClearAllPoints()
            row:AlignParentTopLeft(row.top, SIDE_PAD + row.column * columnW)
        end
        self.scroll:UpdateScrollChildRect()

        local maxScroll = math.max(0, childH - viewportH)
        self.slider:SetMinMax(0, maxScroll)
        self.slider:SetContentSize(viewportH, childH)
        if self.slider:GetValue() > maxScroll then
            self.slider:SetValue(maxScroll)
        end
    end;
}
