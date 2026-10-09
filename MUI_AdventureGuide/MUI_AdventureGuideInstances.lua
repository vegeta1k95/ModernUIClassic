-- MUI_AdventureGuideInstances: the guide's first page — the dungeons or the
-- raids as a grid of pictures (retail's instanceSelect), four to a row.
--
-- Retail's dropdown at the top right picks the expansion; Era has one, so
-- (as in NewEra) it filters instead: the dungeons by continent, the raids by
-- size.
--
--   AdventureGuideInstances(parent, window)
--     :SetRaids(raids)     list the raids (true) or the dungeons (false)
--     :Ordered(raids)      all of them, in the grid's order

local Style = MUI_AdventureGuideStyle

local COLUMNS       = 4
local BUTTON_W, BUTTON_H = 174, 96
local SPACING       = 15
local TOP_PAD       = 5
local VIEW_W, VIEW_H = 748, 367

local EASTERN_KINGDOMS, KALIMDOR = 1415, 1414       -- world map ids

-- The filter's choices: label, then the instance field and the value it
-- must have (none: everything).
local DUNGEON_FILTERS = {
    { ALL },
    { C_Map.GetMapInfo(EASTERN_KINGDOMS).name, "continent", EASTERN_KINGDOMS },
    { C_Map.GetMapInfo(KALIMDOR).name,         "continent", KALIMDOR },
}
local RAID_FILTERS = {
    { ALL },
    { RAID_DIFFICULTY_20PLAYER, "players", 20 },
    { RAID_DIFFICULTY_40PLAYER, "players", 40 },
}

-- ---------------------------------------------------------------------
-- AdventureGuideInstanceButton: an instance's picture in the journal's
-- frame, its name across the top (EncounterInstanceButtonTemplate) and, for
-- a dungeon, its level range in the corner the template keeps for it.
-- ---------------------------------------------------------------------
class "AdventureGuideInstanceButton" : extends "Button" {
    __init = function(self, parent, window)
        Button.__init(self, parent)
        self:SetSize(BUTTON_W, BUTTON_H)
        self:SetClickSound(SOUNDKIT.IG_SPELLBOOK_OPEN)

        self._picture = Texture(self, nil, "BACKGROUND")
        self._picture:FillParent()

        Style:SetPiece(self:SetNormalTexture(Style.ART .. "journal"), "DungeonButton-Up", true)
        Style:SetPiece(self:SetPushedTexture(Style.ART .. "journal"), "DungeonButton-Down", true)
        Style:SetPiece(self:SetHighlightTexture(Style.ART .. "journal"), "DungeonButton-Highlight", true)

        self._name = Style:Title(self, 18)
        self._name:SetWidth(150)
        self._name:AlignParentTop(15)

        self._range = Style:Label(self, 12, 1, 0.82, 0)
        self._range:SetJustifyH("LEFT")
        self._range:AlignParentBottomLeft(7, 7)

        self.OnClick = function() window:ShowInstance(self.instance) end
    end;

    SetInstance = function(self, instance)
        self.instance = instance
        self._picture:SetTexture(Style:InstanceArt("buttons", instance.button))
        self._picture:SetTexCoord(0, 0.68359375, 0, 0.7421875)
        self._name:SetText(instance.name)
        self._range:SetText(Style:LevelRange(instance) or "")
    end;
}


class "AdventureGuideInstances" : extends "Frame" {
    __init = function(self, parent, window)
        Frame.__init(self, "Frame", parent)
        self.window = window
        self._raids = false
        self._filter = { [false] = 1, [true] = 1 }      -- by raids: index of the filter in use
        self._buttons = {}

        -- Retail's tier background for Classic: a 786x425 cut of the sheet.
        local background = Texture(self, nil, "BACKGROUND")
        background:SetTextureRegion(Style.ART .. "instances-bg", 1024, 1024, 1, 428, 786, 425)
        background:SetSize(786, 425)
        background:AlignParentTopLeft(1, 3)

        self._title = Style:Label(self, 18, 1, 0.82, 0)
        self._title:SetJustifyH("LEFT")
        self._title:AlignParentTopLeft(15, 20)

        self:_BuildFilter()

        self._scroll = AdventureGuideScroll(self, VIEW_W, VIEW_H, BUTTON_H + SPACING)
        self._scroll:AlignParentTopLeft(50, 14)
        self._scroll:PlaceBar(12, 6, -4)
    end;

    -- The menu is not on the canvas: its width is the dropdown's as drawn.
    _BuildFilter = function(self)
        self._dropdown = DropdownSimple(self, "MUI_AdventureGuideFilter")
        self._dropdown:SetSize(160, 24)
        self._dropdown:AlignParentTopRight(10, 24)
        self._menu = DropdownMenu(self._dropdown, "MUI_AdventureGuideFilterMenu", self._dropdown)
        self._menu:SetMenuWidth(160 * Style.S)
        self._dropdown.OnClick = function() self._menu:Toggle() end
    end;

    _Filters = function(self)
        return self._raids and RAID_FILTERS or DUNGEON_FILTERS
    end;

    SetRaids = function(self, raids)
        local changed = raids ~= self._raids or not self._offered
        self._raids = raids
        self._title:SetText(raids and RAIDS or DUNGEONS)

        -- A menu's rows are made anew each time it is given items.
        if changed then
            self._offered = true
            local items = {}
            for index, filter in ipairs(self:_Filters()) do
                items[index] = {
                    label = filter[1],
                    OnClick = function()
                        self._filter[self._raids] = index
                        self:_Refresh()
                    end,
                }
            end
            self._menu:SetItems(items)
        end
        self:_Refresh()
    end;

    -- The dungeons climb in level; the raids keep the order they are
    -- progressed in.
    Ordered = function(self, raids)
        local ordered = MUI_EncounterJournalDB:GetInstances(raids)
        if not raids then
            local level = {}
            for _, instance in ipairs(ordered) do
                local dungeon = MUI_DungeonDB:GetDungeonEntrance(instance.area)
                level[instance] = dungeon.minLevel * 100 + dungeon.maxLevel
            end
            table.sort(ordered, function(a, b)
                if level[a] ~= level[b] then return level[a] < level[b] end
                return a.name < b.name
            end)
        end
        return ordered
    end;

    _Listed = function(self)
        local filter = self:_Filters()[self._filter[self._raids]]
        local listed = {}
        for _, instance in ipairs(self:Ordered(self._raids)) do
            if not filter[2] or instance[filter[2]] == filter[3] then
                listed[#listed + 1] = instance
            end
        end
        return listed
    end;

    _Refresh = function(self)
        self._dropdown:SetText(self:_Filters()[self._filter[self._raids]][1])

        local listed = self:_Listed()
        for i, instance in ipairs(listed) do
            local button = self._buttons[i]
            if not button then
                button = AdventureGuideInstanceButton(self._scroll.content, self.window)
                local column, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
                button:AlignParentTopLeft(TOP_PAD + row * (BUTTON_H + SPACING), column * (BUTTON_W + SPACING))
                self._buttons[i] = button
            end
            button:SetInstance(instance)
            button:Show()
        end
        for i = #listed + 1, #self._buttons do
            self._buttons[i]:Hide()
        end

        local rows = math.ceil(#listed / COLUMNS)
        self._scroll:SetContentHeight(TOP_PAD + rows * BUTTON_H + math.max(rows - 1, 0) * SPACING)
        self._scroll:ScrollTo(0)
    end;
}
