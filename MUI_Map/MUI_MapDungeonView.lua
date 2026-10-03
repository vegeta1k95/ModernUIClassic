-- MUI_MapDungeonView: dungeon / raid maps on the world map, after the
-- ClassicDungeonMaps addon (data in MUI_DungeonMapDB).
--
-- Era has no maps for instance interiors, so opening the world map inside
-- one shows the zone outside. While the player is in an instance we have a
-- map for, this view covers the map area with that instance's map: twelve
-- tiles, boss portraits, arrows between floors and to the exit. The floor
-- follows the minimap subzone. Right-click goes a level up, to the world
-- map, as it does between world maps; the dungeon map is back the next time
-- the map is opened.
--
-- No player or group dots: the client doesn't give addons unit positions
-- inside instances.
--
-- Construction:
--   MapDungeonView(mapFrame)   mapFrame — the map module's ScrollContainer wrapper

local TILE_COLS, TILE_ROWS = 4, 3
-- A map fills only 1002x668 of its 1024x768 tile grid; the grid is
-- stretched so that part covers the view, the rest is clipped away.
local GRID_SCALE_X, GRID_SCALE_Y = 1024 / 1002, 768 / 668

local FRAME_LEVEL = 5000      -- over every world-map pin (they start at 3000)
local PIN_SCALE   = 0.5       -- source pin sizes are for a larger map frame
local BOSS_SIZE, PIN_SIZE = 40, 32
local BOSS_SCALE  = 0.8       -- boss portraits, on top of PIN_SCALE
-- How far the round frame stands off a boss portrait, as a fraction of the
-- portrait (left / top, right / bottom: the frame art is slightly off-centre).
local BORDER_PAD_TL, BORDER_PAD_BR = 0.17, 0.15

-- The way out (the source's "poi-door-up" pins): the lit stone archway from
-- our object icons sheet, upright whatever angle the source arrow had.
local EXIT_ATLAS  = "poi-door-up"
local EXIT_REGION = { 8, 334, 53, 62 }

-- Dungeon map code -> MUI_DungeonDB area id, for the zone its entrance is in.
local DUNGEON_AREA = {
    RFC = 2437, SFK = 209, RFK = 491, Stocks = 717, WC = 718, BFD = 719,
    Gnomer = 721, RFD = 722, SM = 796, ZF = 1176, Ulda = 1337, ST = 1477,
    DM = 1581, Mara = 2100, LBRS = 1583, UBRS = 1583, BlackrockMountain = 1583,
    BRD = 1584, Strat = 2017, Scholo = 2057, DM2 = 2557, Onyxia = 2159,
    ZG = 1977, AQ20 = 3429, MC = 2717, BWL = 2677, AQ40 = 3428, Nax = 3456,
}

class "MapDungeonPin" : extends "Frame" {
    __init = function(self, parent, view)
        Frame.__init(self, "Frame", parent)
        self:EnableMouse(true)
        self._view = view

        self.icon = Texture(self, nil, "ARTWORK")
        self.icon:FillParent()
        self.highlight = Texture(self, nil, "HIGHLIGHT")
        self.highlight:FillParent()
        self.highlight:SetBlendMode("ADD")
        self.highlight:SetAlpha(0.4)

        -- Boss portraits: a black disc behind (the gap up to the frame would
        -- show the map otherwise), the round frame of the spellbook's
        -- passive spells around.
        self.backdrop = Texture(self, nil, "BACKGROUND")
        self.backdrop:SetPortrait("Interface\\Buttons\\WHITE8X8")
        self.backdrop:SetVertexColor(0, 0, 0, 1)
        self.backdrop:Hide()
        self.border = Texture(self, nil, "OVERLAY")
        self.border:SetTextureRegion(MUI.TEX_SKIN .. "spellbook\\spellbook-elements", 1024, 1024, 273, 453, 50, 50)
        self.border:Hide()

        self:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            tooltip:AddLine(self.data.text, 1, 0.82, 0, false, 13)
        end)
        self:SetScript("OnMouseUp", function(_, button)
            local data = self.data
            if not self:IsMouseOver() then return end
            if button == "RightButton" then
                self._view:Dismiss()
            elseif data.link then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                self._view:ShowFloor(data.link[1], data.link[2])
            elseif data.exit then
                self._view:Dismiss()
            end
        end)
    end;

    SetData = function(self, data)
        self.data = data
        for _, tex in ipairs({ self.icon, self.highlight }) do
            if data.boss then
                -- A pooled pin may have shown an atlas (cropped, rotated) before.
                tex:SetRotation(0)
                tex:SetTexCoord(0, 1, 0, 1)
                tex:SetPortraitFromCreatureDisplayID(data.boss)
            elseif data.atlas == EXIT_ATLAS then
                tex:SetRotation(0)
                tex:SetTextureRegion(MUI.TEX_BASE .. "objecticonsatlas", 1024, 1024,
                    EXIT_REGION[1], EXIT_REGION[2], EXIT_REGION[3], EXIT_REGION[4])
            else
                tex:SetBlizzardAtlas(data.atlas, false)
                tex:SetRotation(math.rad(-(data.angle or 0)))
            end
        end
        local size = (data.size or (data.boss and BOSS_SIZE or PIN_SIZE)) * PIN_SCALE
        if data.boss then
            size = size * BOSS_SCALE
            self.border:ClearAllPoints()
            self.border:FillParentPadding(-size * BORDER_PAD_TL, -size * BORDER_PAD_TL,
                                          -size * BORDER_PAD_BR, -size * BORDER_PAD_BR)
            self.border:Show()
            self.backdrop:ClearAllPoints()
            self.backdrop:FillParentPadding(-size * BORDER_PAD_TL * 0.85, -size * BORDER_PAD_TL * 0.85,
                                            -size * BORDER_PAD_BR * 0.85, -size * BORDER_PAD_BR * 0.85)
            self.backdrop:Show()
        else
            self.border:Hide()
            self.backdrop:Hide()
        end
        if data.atlas == EXIT_ATLAS then
            self:SetSize(size * EXIT_REGION[3] / EXIT_REGION[4], size)
        else
            self:SetSize(size, size)
        end
    end;
}

class "MapDungeonView" : extends "Frame" {
    __init = function(self, mapFrame)
        Frame.__init(self, "Frame", mapFrame, "MUI_MapDungeonView")
        self:FillParent()
        self:SetFrameStrata("MEDIUM")
        self:SetFrameLevel(FRAME_LEVEL)
        self:SetClipsChildren(true)
        -- Swallow clicks and the wheel: the world map underneath must not
        -- pan, zoom or navigate while it is covered.
        self:EnableMouse(true)
        self:EnableMouseWheel(true)
        self:SetScript("OnMouseWheel", function() end)
        self:SetScript("OnMouseUp", function(_, button)
            if button == "RightButton" and self:IsMouseOver() then self:Dismiss() end
        end)

        local bg = Texture(self, nil, "BACKGROUND")
        bg:SetColorTexture(0, 0, 0, 1)
        bg:FillParent()

        self._tiles = {}
        for i = 1, TILE_COLS * TILE_ROWS do
            self._tiles[i] = Texture(self, nil, "BORDER")
        end
        self._pinHost = Frame("Frame", self)
        self._pinHost:FillParent()
        self._pinHost:SetFrameLevel(FRAME_LEVEL + 1)
        self._pins = {}

        self._code, self._floor = nil, nil   -- map on display
        self._dismissed = false              -- player went back to the world map
        self:Hide()

        -- A dismissed dungeon map comes back with the next map opening.
        mapFrame:HookScript("OnShow", function()
            if self._code and self._dismissed then
                self._dismissed = false
                self:Show()
            end
        end)

        self:SetScript("OnSizeChanged", function() self:_Layout() end)
        self:SetScript("OnShow", function() self:_Layout() end)

        self._driver = Frame("Frame", nil, "MUI_MapDungeonViewDriver")
        for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED",
                                 "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
            self._driver:RegisterEventHandler(event, function() self:_Resolve() end)
        end
        self:_Resolve()
    end;

    -- Which map the player is on: by minimap subzone, else (first time in
    -- this instance) by the instance's name. A subzone we don't know keeps
    -- the floor already shown.
    _Resolve = function(self)
        if not IsInInstance() then
            self._code, self._floor, self._instance = nil, nil, nil
            self._dismissed = false
            self:Hide()
            return
        end
        local instance = GetInstanceInfo()
        local code, floor = MUI_DungeonMapDB:FindBySubzone(GetMinimapZoneText())
        if not code and self._instance ~= instance then
            code, floor = MUI_DungeonMapDB:FindByInstance(instance)
        end
        if self._instance ~= instance then
            self._instance = instance
            self._dismissed = false
            if not code then
                self._code, self._floor = nil, nil
                self:Hide()
            end
        end
        if code and (code ~= self._code or floor ~= self._floor) then
            self:_SetFloor(code, floor)
        end
    end;

    -- Show a floor (floor-arrow pin): also un-dismisses.
    ShowFloor = function(self, code, floor)
        self._dismissed = false
        self:_SetFloor(code, floor)
    end;

    -- Up to the world map, until the map is opened again. Inside an
    -- instance the world map has no "player's zone" and would sit on Azeroth,
    -- so it is pointed at the zone of the dungeon's entrance.
    Dismiss = function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        self._dismissed = true
        self:Hide()
        local entrance = MUI_DungeonDB:GetDungeonEntrance(DUNGEON_AREA[self._code])
        local mapId = entrance and MUI_ZoneDB:GetUiMapForArea(entrance.outerAreaId)
        if mapId then WorldMapFrame:SetMapID(mapId) end
    end;

    _SetFloor = function(self, code, floor)
        local map = MUI_DungeonMapDB:GetFloors(code)[floor]
        self._code, self._floor = code, floor

        for i, tile in ipairs(self._tiles) do
            tile:SetTexture(map.path .. i .. map.ext)
        end

        for i, data in ipairs(map.pins) do
            local pin = self._pins[i]
            if not pin then
                pin = MapDungeonPin(self._pinHost, self)
                self._pins[i] = pin
            end
            pin:SetData(data)
            pin:Show()
        end
        for i = #map.pins + 1, #self._pins do
            self._pins[i]:Hide()
        end

        if self._dismissed then self:Hide() else self:Show() end
        self:_Layout()
    end;

    -- Tiles and pins are placed from the view's own size, known only once
    -- the map frame has been laid out.
    _Layout = function(self)
        local map = self._code and MUI_DungeonMapDB:GetFloors(self._code)[self._floor]
        local w, h = self:GetWidth(), self:GetHeight()
        if not map or not w or w == 0 then return end

        local cellW = w / TILE_COLS * GRID_SCALE_X
        local cellH = h / TILE_ROWS * GRID_SCALE_Y
        for i, tile in ipairs(self._tiles) do
            local col, row = (i - 1) % TILE_COLS, math.floor((i - 1) / TILE_COLS)
            tile:SetSize(cellW, cellH)
            tile:ClearAllPoints()
            tile:AlignParentTopLeft(row * cellH, col * cellW)
        end
        for i, data in ipairs(map.pins) do
            local pin = self._pins[i]
            pin:ClearAllPoints()
            pin:AlignParentTopLeft(data.y * h - pin:GetHeight() / 2, data.x * w - pin:GetWidth() / 2)
        end
    end;
}
