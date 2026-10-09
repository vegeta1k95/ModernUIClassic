-- MUI_AdventureGuideEncounter: an instance's two pages (retail's encounter
-- frame). Left: the round button back to the instance's own page, its name
-- and its bosses. Right: with no boss picked, the instance's lore under its
-- picture and the way to its map; with one, the boss's lore and abilities.
-- The tabs on the right edge swap the right page for the loot (the boss's,
-- or the whole instance's) and for the boss in 3D.
--
-- Retail has a fourth tab for its role overviews (what a tank, a healer, a
-- damage dealer should know); this data has none, and retail itself drops
-- that tab for an instance without them.
--
--   AdventureGuideEncounter(parent, window)
--     :ShowInstance(instance)
--     :ShowEncounter(encounter[, display])   a boss of the instance on show,
--                                            on the model page at `display`
--     :ShowSection(chain)                    the boss's abilities, at one
--     :ShowLoot()                            the loot page
--     .instance .encounter                   what is on show

local Style = MUI_AdventureGuideStyle

local TITLE = { 0.902, 0.788, 0.671 }
local TAB_ABILITIES, TAB_LOOT, TAB_MODEL = 1, 2, 3
local BOSS_W, BOSS_H = 325, 55
local BOSS_TOP, BOSS_GAP = 10, 15
local MAX_CREATURES = 9

-- ---------------------------------------------------------------------
-- AdventureGuideBossButton: a boss in the list (EncounterBossButtonTemplate)
-- — its plate standing out over the bar's left end, its name beside.
-- ---------------------------------------------------------------------
class "AdventureGuideBossButton" : extends "Button" {
    __init = function(self, parent, page)
        Button.__init(self, parent)
        self:SetSize(BOSS_W, BOSS_H)
        self:SetClickSound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
        self.encounter = nil

        Style:SetPiece(self:SetNormalTexture(Style.ART .. "journal"), "BossButton-Up", true)
        Style:SetPiece(self:SetPushedTexture(Style.ART .. "journal"), "BossButton-Down", true)
        Style:SetPiece(self:SetHighlightTexture(Style.ART .. "journal"), "BossButton-Highlight", true)

        -- On a frame of its own: over the button's highlight, not under it.
        local holder = Frame("Frame", self)
        holder:SetSize(128, 64)
        holder:AlignParentTopLeft(-13, -4)
        self._plate = Texture(holder, nil, "OVERLAY")
        self._plate:FillParent()

        self._name = Style:Label(self, 14, 0.827, 0.659, 0.463)
        self._name:SetJustifyH("LEFT")
        self._name:SetJustifyV("MIDDLE")
        self._name:SetSize(160, 40)
        self._name:AlignParentLeft(105, -3)

        self.OnClick = function() page:ShowEncounter(self.encounter) end
    end;

    SetEncounter = function(self, encounter, selected)
        self.encounter = encounter
        self._plate:SetTexture(Style:BossArt(encounter))
        self._name:SetText(encounter.name)
        if selected then self:LockHighlight() else self:UnlockHighlight() end
    end;
}


-- ---------------------------------------------------------------------
-- AdventureGuideLore: the right page while no boss is picked — the
-- instance's picture with its name on a plate, the Show Map button, the
-- instance's story.
-- ---------------------------------------------------------------------
class "AdventureGuideLore" : extends "Frame" {
    __init = function(self, parent, page)
        Frame.__init(self, "Frame", parent)
        self:SetSize(390, 425)

        self._picture = Texture(self, nil, "BACKGROUND")
        self._picture:SetSize(390, 330)
        self._picture:AlignParentTop(9, 3)

        self._plate = Style:Piece(self, "ARTWORK", "DungeonNameBg")
        self._plate:AlignTop(self._picture, 38)

        self._name = Style:Title(self, 24)
        self._name:SetJustifyV("BOTTOM")
        self._name:SetSize(320, 35)
        self._name:AlignParentTop(48)

        self:_BuildMapButton(page)

        self._scroll = AdventureGuideScroll(self, 315, 95, 24)
        self._scroll:AlignParentBottomLeft(5, 35)
        self._scroll:PlaceBar(9, 0, 0)
        self._story = Style:Label(self._scroll.content, 12, 0.13, 0.07, 0.01, "ARTWORK", false)
        self._story:SetJustifyH("LEFT")
        self._story:SetWidth(315)
        self._story:AlignParentTopLeft()
    end;

    _BuildMapButton = function(self, page)
        local button = Button(self)
        button:SetSize(48, 32)
        button:AlignParentBottomLeft(126, 33)
        button:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION)

        local shadow = Style:Piece(button, "BACKGROUND", "ShowMapBG")
        shadow:AlignParentLeft(-3, 5)

        local icon = Texture(button, nil, "ARTWORK")
        icon:SetTexture("Interface\\QuestFrame\\UI-QuestMap_Button")
        icon:SetTexCoord(0.125, 0.875, 0, 0.5)
        icon:FillParent()

        local glow = button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        glow:SetBlendMode("ADD")
        glow:ClearAllPoints()
        glow:SetSize(36, 25)
        glow:AlignParentRight(7)

        local label = Style:Label(button, 12, 1, 0.82, 0, "ARTWORK")
        label:SetJustifyH("LEFT")
        label:SetText(ENCOUNTER_JOURNAL_SHOW_MAP)
        label:RightOf(button, 2)

        button:SetScript("OnMouseDown", function() icon:SetTexCoord(0.125, 0.875, 0.5, 1) end)
        button:SetScript("OnMouseUp", function() icon:SetTexCoord(0.125, 0.875, 0, 0.5) end)
        button.OnClick = function() page:ShowMap() end
    end;

    SetInstance = function(self, instance)
        self._picture:SetTexture(Style:InstanceArt("lore", instance.lore))
        self._picture:SetTexCoord(0, 0.7617187, 0, 0.65625)
        self._name:SetText(instance.name)
        self._plate:SetWidth(self._name:GetStringWidth() + 80)
        self._story:SetText(instance.desc)
        self._scroll:SetContentHeight(self._story:GetStringHeight())
        self._scroll:ScrollTo(0)
    end;
}


class "AdventureGuideEncounter" : extends "Frame" {
    __init = function(self, parent, window)
        Frame.__init(self, "Frame", parent)
        self.window = window
        self.instance = nil
        self.encounter = nil
        self._tab = TAB_ABILITIES
        self._hasLoot = false
        self._creatures = {}          -- by encounter: what its model page lists

        -- The open journal.
        local info = Frame("Frame", self)
        info:SetSize(785, 425)
        info:AlignParentBottomRight(2, 1)
        self._info = info

        local paper = Texture(info, nil, "BACKGROUND")
        paper:SetTexture(Style.ART .. "journal-bg")
        paper:SetTexCoord(0, 0.766601562, 0, 0.830078125)
        paper:FillParent()

        local leftHeader = Style:Piece(info, "BACKGROUND", "LeftPageHeader", 3)
        leftHeader:AlignParentTopLeft(11, 0)
        self._rightHeader = Style:Piece(info, "BACKGROUND", "RightPageHeader", 3)
        self._rightHeader:AlignParentTopRight(11, 0)

        self._instanceTitle = Style:Label(info, 16, TITLE[1], TITLE[2], TITLE[3])
        self._instanceTitle:SetJustifyH("LEFT")
        self._instanceTitle:SetWordWrap(false)
        self._instanceTitle:SetSize(290, 12)
        self._instanceTitle:AlignParentTopLeft(20, 65)

        self._encounterTitle = Style:Label(info, 16, TITLE[1], TITLE[2], TITLE[3])
        self._encounterTitle:SetJustifyH("LEFT")
        self._encounterTitle:SetWordWrap(false)
        self._encounterTitle:SetSize(220, 12)
        self._encounterTitle:AlignParentTopRight(24, 130)

        self:_BuildBackButton()
        self:_BuildBosses()
        self:_BuildTabs()

        self._lore = AdventureGuideLore(info, self)
        self._lore:AlignParentBottomRight()
        self._abilities = AdventureGuideAbilities(info, self)
        self._abilities:AlignParentBottomRight(1, 5)
        self._loot = AdventureGuideLoot(info, self)
        self._loot:AlignParentBottomRight(1, 5)
        self._model = AdventureGuideModel(info)
        self._model:AlignParentBottomRight(1, 3)

        self:_Refresh()
    end;

    -- The instance's picture in the round frame at the page's top left:
    -- back from a boss to the instance's own page.
    _BuildBackButton = function(self)
        local button = Button(self._info)
        button:SetSize(64, 61)
        button:AlignParentTopLeft(3, 0)
        button:SetClickSound(SOUNDKIT.IG_SPELLBOOK_OPEN)

        self._backIcon = Texture(button, nil, "BACKGROUND")
        self._backIcon:SetDrawLayer("BACKGROUND", 6)
        self._backIcon:SetSize(40, 40)
        self._backIcon:CenterInParent()

        Style:SetPiece(button:SetNormalTexture(Style.ART .. "journal"), "BossModelButton", true)
        local glow = button:SetHighlightTexture(Style.ART .. "journal")
        Style:SetPiece(glow, "BossModelButton", true)
        glow:SetBlendMode("ADD")

        button.OnClick = function() self:ShowInstance(self.instance) end
    end;

    _BuildBosses = function(self)
        self._bossButtons = {}
        self._bosses = AdventureGuideScroll(self._info, 338, 382, BOSS_H + BOSS_GAP)
        self._bosses:AlignParentBottomLeft(1, 25)
        self._bosses:PlaceBar(5, 5, 5)
    end;

    -- The tabs hang off the page's right edge, past the window's: they
    -- stand above its border.
    _BuildTabs = function(self)
        local specs = {
            { "BossIcon",  ABILITIES },
            { "LootIcon",  LOOT_NOUN },
            { "ModelIcon", MODEL },
        }
        self._tabs = {}
        for index, spec in ipairs(specs) do
            local tab = AdventureGuideSideTab(self._info, spec[1], spec[2])
            tab:SetFrameLevel(self._info:GetFrameLevel() + 500)
            if index == 1 then
                tab:AlignParentTopRight(35, -51)
            else
                tab:Below(self._tabs[index - 1], -2)
            end
            tab.OnClick = function()
                self._tab = index
                self:_Refresh()
            end
            self._tabs[index] = tab
        end
    end;

    -- ---- what shows -----------------------------------------------------

    ShowInstance = function(self, instance)
        local changed = instance ~= self.instance
        self.instance, self.encounter = instance, nil

        self._instanceTitle:SetText(instance.name)
        -- The picture's middle: the art fills the top left of its file.
        self._backIcon:SetPortrait(Style:InstanceArt("buttons", instance.button))
        self._backIcon:SetTexCoord(0.15625, 0.52734375, 0, 0.7421875)

        self._lore:SetInstance(instance)
        self._model:SetBackdrop(instance)

        self._hasLoot = false
        for _, encounter in ipairs(instance.encounters) do
            if encounter.loot then self._hasLoot = true end
        end
        self._loot:SetSource(instance, nil)

        self:_ListBosses()
        if changed then self._bosses:ScrollTo(0) end
        self:_Refresh()
        self.window:OnPageChanged()
    end;

    ShowEncounter = function(self, encounter, display)
        self.encounter = encounter
        self._encounterTitle:SetText(encounter.name)
        self._abilities:SetEncounter(encounter)
        self._loot:SetSource(self.instance, encounter)

        local creatures = self:_Creatures(encounter)
        local shown
        for _, creature in ipairs(creatures) do
            if creature.display == display then shown = creature end
        end
        self._model:SetCreatures(creatures, shown)
        if shown then self._tab = TAB_MODEL end

        self:_ListBosses()
        self:_RevealBoss(encounter)
        self:_Refresh()
        self.window:OnPageChanged()
    end;

    -- A creature of the boss on show, on the model page (a click on the
    -- portrait of a header among its abilities).
    ShowCreature = function(self, display, name)
        local shown = { name = name, display = display }
        for _, creature in ipairs(self:_Creatures(self.encounter)) do
            if creature.display == display then shown = creature end
        end
        self._model:ShowCreature(shown)
        self._tab = TAB_MODEL
        self:_Refresh()
    end;

    -- The abilities of the boss on show, unfolded down to one of them
    -- (`chain`: its headers, outermost first, itself last).
    ShowSection = function(self, chain)
        self._tab = TAB_ABILITIES
        self:_Refresh()
        self._abilities:Reveal(chain)
    end;

    ShowLoot = function(self)
        self._tab = TAB_LOOT
        self:_Refresh()
    end;

    -- The instance's map, on the world map; the guide makes way for it.
    -- Opening the world map is not for addon code in combat.
    ShowMap = function(self)
        if not WorldMapFrame:IsShown() then
            if InCombatLockdown() then return end
            ToggleWorldMap()
        end
        MUI_ModuleMap.dungeonView:Browse(self.instance.map, self.instance.floor)
        self.window:Hide()
    end;

    -- ---- internals ------------------------------------------------------

    -- What the model page lists for a boss: its own creatures, then those
    -- its abilities have headers for.
    _Creatures = function(self, encounter)
        local list = self._creatures[encounter]
        if list then return list end

        list = {}
        local seen = {}
        for _, creature in ipairs(encounter.creatures) do
            list[#list + 1] = creature
            seen[creature.display] = true
        end
        self:_CollectCreatures(encounter.sections or {}, list, seen)
        self._creatures[encounter] = list
        return list
    end;

    _CollectCreatures = function(self, sections, list, seen)
        for _, section in ipairs(sections) do
            if section.display and not seen[section.display] and #list < MAX_CREATURES then
                seen[section.display] = true
                list[#list + 1] = { name = section.title, display = section.display,
                                    dist = section.dist, eye = section.eye }
            end
            if section.sub then self:_CollectCreatures(section.sub, list, seen) end
        end
    end;

    _ListBosses = function(self)
        local encounters = self.instance.encounters
        for i, encounter in ipairs(encounters) do
            local button = self._bossButtons[i]
            if not button then
                button = AdventureGuideBossButton(self._bosses.content, self)
                button:AlignParentTopLeft(BOSS_TOP + (i - 1) * (BOSS_H + BOSS_GAP), 0)
                self._bossButtons[i] = button
            end
            button:SetEncounter(encounter, encounter == self.encounter)
            button:Show()
        end
        for i = #encounters + 1, #self._bossButtons do
            self._bossButtons[i]:Hide()
        end
        self._bosses:SetContentHeight(BOSS_TOP + #encounters * (BOSS_H + BOSS_GAP))
    end;

    -- Scroll the list to a boss picked from elsewhere (the bar's dropdown,
    -- a search) that is out of view.
    _RevealBoss = function(self, encounter)
        for i, listed in ipairs(self.instance.encounters) do
            if listed == encounter then
                local top = (i - 1) * (BOSS_H + BOSS_GAP)
                local scroll = self._bosses:GetScroll()
                if top < scroll or top + BOSS_TOP + BOSS_H > scroll + self._bosses:GetHeight() then
                    self._bosses:ScrollTo(top)
                end
            end
        end
    end;

    -- Bring the tabs and the right page in line with what is on show. A tab
    -- with nothing behind it gives way to the first that has something.
    _Refresh = function(self)
        local boss = self.encounter
        local usable = {
            [TAB_ABILITIES] = boss == nil or boss.sections ~= nil or boss.desc ~= nil,
            [TAB_LOOT]      = self._hasLoot,
            [TAB_MODEL]     = boss ~= nil,
        }
        if not usable[self._tab] then
            for index = TAB_ABILITIES, TAB_MODEL do
                if usable[index] then
                    self._tab = index
                    break
                end
            end
        end
        for index, tab in ipairs(self._tabs) do
            tab:SetEnabled(usable[index])
            tab:SetSelected(index == self._tab)
        end

        local reading = self._tab == TAB_ABILITIES and boss ~= nil
        self._lore:SetVisible(self._tab == TAB_ABILITIES and boss == nil)
        self._abilities:SetVisible(reading)
        self._loot:SetVisible(self._tab == TAB_LOOT)
        self._model:SetVisible(self._tab == TAB_MODEL)
        self._rightHeader:SetVisible(reading or self._tab == TAB_LOOT)
        self._encounterTitle:SetVisible(reading)
    end;
}
