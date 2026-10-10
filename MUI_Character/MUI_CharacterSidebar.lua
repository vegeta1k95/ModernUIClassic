-- MUI_CharacterSidebar: the paper doll's side pane and the tabs over it —
-- retail's PaperDollSidebarTabs. Era has no titles, so there are two: the
-- character's stats and the equipment manager.

local TABS_ART = "Interface\\PaperDollInfoFrame\\PaperDollSidebarTabs"

local TAB_W, TAB_H, TAB_GAP = 33, 35, 4

-- The stat sheet, as CharacterStatSheet takes it.
local SECTIONS = {
    { "General", {
        { "Health" }, { "Power" },
    } },
    { "Attributes", {
        { "Attribute", 1 }, { "Attribute", 2 }, { "Attribute", 3 }, { "Attribute", 4 }, { "Attribute", 5 },
    } },
    { "Melee", {
        { "Damage" }, { "DamagePerSecond" }, { "AttackPower" }, { "AttackSpeed" }, { "Attack" }, { "Hit" }, { "Crit" },
    } },
    { "Ranged", {
        { "RangedDamage" }, { "RangedDamagePerSecond" }, { "RangedAttackPower" }, { "RangedAttackSpeed" },
        { "RangedAttack" }, { "Hit" }, { "RangedCrit" },
    } },
    { "Spell", {
        { "SpellDamage" }, { "SpellHealing" }, { "SpellHit" }, { "SpellCrit" }, { "ManaRegen" },
    } },
    { "Defense", {
        { "Armor" }, { "Defense" }, { "Dodge" }, { "Parry" }, { "Block" },
    } },
    { "Resistances", {
        { "Resistance", 6 }, { "Resistance", 2 }, { "Resistance", 3 }, { "Resistance", 4 }, { "Resistance", 5 },
    } },
}

-- ---------------------------------------------------------------------
-- CharacterSidebarTab: retail's PaperDollSidebarTabTemplate.
-- ---------------------------------------------------------------------
class "CharacterSidebarTab" : extends "Button" {
    __init = function(self, parent, title)
        Button.__init(self, parent)
        self:SetSize(TAB_W, TAB_H)
        self:SetClickSound(SOUNDKIT.IG_CHARACTER_INFO_TAB)

        self._plate = Texture(self, nil, "BACKGROUND")
        self._plate:SetTexture(TABS_ART)
        self._plate:SetSize(50, 43)
        self._plate:AlignParentBottomLeft(-2, -9)

        -- Public: the owner gives it its picture.
        self.icon = Texture(self, nil, "ARTWORK")
        self.icon:SetSize(33, 35)
        self.icon:AlignParentBottom(-2, 1)

        -- An unselected tab's lower half is shaded.
        self._shade = Texture(self, nil, "OVERLAY")
        self._shade:SetTexture(TABS_ART)
        self._shade:SetTexCoord(0.015625, 0.546875, 0.11328125, 0.1875)
        self._shade:SetSize(34, 19)
        self._shade:AlignParentBottom()

        self._glow = Texture(self, nil, "HIGHLIGHT")
        self._glow:SetTexture(TABS_ART)
        self._glow:SetTexCoord(0.015625, 0.5, 0.1953125, 0.31640625)
        self._glow:SetSize(31, 31)
        self._glow:AlignParentTopLeft(3, 2)

        self:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            tooltip:AddLine(title, 1, 1, 1, false, 13)
        end)
        self:SetSelected(false)
    end;

    SetSelected = function(self, selected)
        self._shade:SetVisible(not selected)
        self._glow:SetAlpha(selected and 0 or 1)
        if selected then
            self._plate:SetTexCoord(0.015625, 0.796875, 0.7890625, 0.95703125)
        else
            self._plate:SetTexCoord(0.015625, 0.796875, 0.61328125, 0.78125)
        end
    end;
}

-- ---------------------------------------------------------------------
-- CharacterSidebar
-- ---------------------------------------------------------------------
class "CharacterSidebar" : extends "Frame" {
    __init = function(self, paperDoll, window)
        Frame.__init(self, "Frame", paperDoll)
        self:Fill(window.insetRight, 3, 3, 3, 2)

        -- Paladins, shamans and druids hold a relic where a ranged weapon goes.
        local sections = {}
        for _, section in ipairs(SECTIONS) do
            if section[1] ~= "Ranged" or not UnitHasRelicSlot("player") then
                sections[#sections + 1] = section
            end
        end
        self.stats   = CharacterStatSheet(self, "player", sections, true)
        self.manager = CharacterEquipmentManager(self, paperDoll)
        self._panes  = { self.stats, self.manager }

        -- The strip the tabs stand in, centred on the side inset's top edge,
        -- with retail's flourish at each end.
        local strip = Frame("Frame", self)
        strip:SetSize(2 * TAB_W + TAB_GAP + 61, TAB_H)
        strip:Above(self, 2)
        local flourishLeft = Texture(strip, nil, "ARTWORK")
        flourishLeft:SetTexture(TABS_ART)
        flourishLeft:SetTexCoord(0.015625, 0.453125, 0.00390625, 0.046875)
        flourishLeft:SetSize(28, 11)
        flourishLeft:AlignParentBottomLeft()
        local flourishRight = Texture(strip, nil, "ARTWORK")
        flourishRight:SetTexture(TABS_ART)
        flourishRight:SetTexCoord(0.015625, 0.453125, 0.0546875, 0.10546875)
        flourishRight:SetSize(28, 13)
        flourishRight:AlignParentBottomRight()

        local manager = CharacterSidebarTab(strip, "Equipment Manager")
        manager:AlignParentBottomRight(0, 30)
        manager.icon:SetTexture(TABS_ART)
        manager.icon:SetTexCoord(0.015625, 0.53125, 0.46875, 0.60546875)
        local stats = CharacterSidebarTab(strip, "Character Stats")
        stats:LeftOf(manager, TAB_GAP)
        stats.icon:SetSize(29, 31)
        stats.icon:ClearAllPoints()
        stats.icon:AlignParentBottom(0, 1)
        self._portrait = stats.icon

        self._tabs = { stats, manager }
        for index, tab in ipairs(self._tabs) do
            tab.OnClick = function() self:Select(index) end
        end

        self:HookScript("OnShow", function() self:_UpdatePortrait() end)
        -- Back to the stats for the next time the frame opens, as retail.
        self:HookScript("OnHide", function() self:Select(1) end)
        self:RegisterEventHandler("UNIT_PORTRAIT_UPDATE", function(_, _, unit)
            if unit == "player" and self:IsVisible() then self:_UpdatePortrait() end
        end)
        self:Select(1)
    end;

    -- The stats tab's picture is the character's face.
    _UpdatePortrait = function(self)
        self._portrait:SetPortraitFromUnit("player")
        self._portrait:SetTexCoord(0.109375, 0.890625, 0.09375, 0.90625)
    end;

    Select = function(self, index)
        for i, pane in ipairs(self._panes) do
            pane:SetVisible(i == index)
            self._tabs[i]:SetSelected(i == index)
        end
    end;
}
