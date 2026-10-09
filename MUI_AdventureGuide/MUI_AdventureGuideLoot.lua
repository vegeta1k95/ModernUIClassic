-- MUI_AdventureGuideLoot: what a boss drops, or everything an instance
-- drops with the boss named under each item (retail's LootContainer and
-- EncounterItemTemplate), and the slot filter over it.
--
-- Not retail's: the drop chance at a row's right (AtlasLoot's figures, as in
-- NewEra). Not carried over: the class filter, which Era's API has nothing
-- for.
--
-- An item's icon, slot and type come from the client at once; its name and
-- quality are the client's when it has the item cached and the journal
-- data's (English) until GET_ITEM_INFO_RECEIVED brings them.
--
--   AdventureGuideLoot(parent, page)
--     :SetSource(instance, encounter)     encounter nil: the whole instance

local Style = MUI_AdventureGuideStyle

local VIEW_W, VIEW_H = 345, 382
local ROW_W          = 321
local ROW_H, ROW_H_INSTANCE = 45, 64
local POOL           = math.ceil(VIEW_H / ROW_H) + 1

-- Retail's slot filters, in its order; an equip location not listed is OTHER.
local SLOT_NAMES = {
    INVTYPE_HEAD, INVTYPE_NECK, INVTYPE_SHOULDER, INVTYPE_CLOAK, INVTYPE_CHEST, INVTYPE_WRIST,
    INVTYPE_HAND, INVTYPE_WAIST, INVTYPE_LEGS, INVTYPE_FEET, INVTYPE_WEAPONMAINHAND,
    INVTYPE_WEAPONOFFHAND, INVTYPE_FINGER, INVTYPE_TRINKET, OTHER,
}
local SLOT_OTHER = #SLOT_NAMES
local SLOT_OF = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CLOAK = 4,
    INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_WRIST = 6, INVTYPE_HAND = 7,
    INVTYPE_WAIST = 8, INVTYPE_LEGS = 9, INVTYPE_FEET = 10,
    INVTYPE_WEAPONMAINHAND = 11, INVTYPE_2HWEAPON = 11, INVTYPE_WEAPON = 11,
    INVTYPE_RANGED = 11, INVTYPE_RANGEDRIGHT = 11, INVTYPE_THROWN = 11,
    INVTYPE_WEAPONOFFHAND = 12, INVTYPE_SHIELD = 12, INVTYPE_HOLDABLE = 12,
    INVTYPE_FINGER = 13, INVTYPE_TRINKET = 14,
}

local ARMOR_CLASS, ARMOR_MISCELLANEOUS = 4, 0

local function SlotOf(itemId)
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemId)
    return SLOT_OF[equipLoc] or SLOT_OTHER
end

-- ---------------------------------------------------------------------
-- AdventureGuideLootRow: an item — icon in its quality's border, name, slot
-- and type on the journal's plate; in an instance's list a line taller, for
-- the boss.
-- ---------------------------------------------------------------------
class "AdventureGuideLootRow" : extends "Button" {
    __init = function(self, parent, owner)
        Button.__init(self, parent)
        self:SetSize(ROW_W, ROW_H)
        self:SetClickSound(nil)
        self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        self.owner = owner
        self.entry = nil

        self._icon = ItemIcon(self, nil, "BACKGROUND")
        self._icon:SetSize(42, 42)
        self._icon:AlignParentTopLeft(2, 2)

        self._plate = Texture(self, nil, "BORDER")
        self._plate:AlignParentLeft()

        self._name = Style:Label(self, 14, 1, 1, 1)
        self._name:SetJustifyH("LEFT")
        self._name:SetWordWrap(false)
        self._name:SetSize(208, 12)
        self._name:RightOf(self._icon, 7, 8)

        self._chance = Style:Ink(self)
        self._chance:SetJustifyH("RIGHT")
        self._chance:AlignParentTopRight(9, 6)

        self._type = Style:Ink(self)
        self._type:SetJustifyH("RIGHT")
        self._type:SetHeight(12)
        self._type:AlignParentTopRight(27, 6)

        self._slot = Style:Ink(self)
        self._slot:SetHeight(12)
        self._slot:RightOf(self._icon, 7, -10)

        self._boss = Style:Ink(self)
        self._boss:SetHeight(12)
        self._boss:AlignParentTopLeft(47, 2)

        self.OnEnter = function()
            MUI_Tooltip:ShowFor(self, "ANCHOR_RIGHT", function(tip)
                tip:SetHyperlink("item:" .. self.entry.id)
            end)
            MUI_Tooltip:ShowCompareItem()
        end
        self.OnLeave = function() MUI_Tooltip:Hide() end
        self.OnClick = function()
            local _, link = C_Item.GetItemInfo(self.entry.id)
            if link and HandleModifiedItemClick(link) then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
            else
                owner:OnRowClicked(self.entry)
            end
        end
    end;

    -- entry = { id, chance, encounter }; `whole` for an instance's list.
    Set = function(self, entry, whole)
        self.entry = entry
        self:SetHeight(whole and ROW_H_INSTANCE or ROW_H)
        Style:SetPiece(self._plate, whole and "DungeonLootFrame" or "LootFrame")

        local _, _, subType, equipLoc, icon, classId, subClassId = C_Item.GetItemInfoInstant(entry.id)
        self._icon:SetTexture(icon)
        self._slot:SetText(getglobal(equipLoc) or "")
        if classId == ARMOR_CLASS and subClassId == ARMOR_MISCELLANEOUS then
            self._type:SetText("")
        else
            self._type:SetText(subType)
        end

        if entry.chance > 0 then
            self._chance:SetText(string.format("%.1f%%", entry.chance))
        else
            self._chance:SetText("")
        end
        self._boss:SetText(whole and string.format(BOSS_INFO_STRING, entry.encounter.name) or "")
        self:Refresh()
    end;

    -- The name and the quality: the client's, once it has them.
    Refresh = function(self)
        local name, _, quality = C_Item.GetItemInfo(self.entry.id)
        if not name then
            name, quality = MUI_EncounterJournalDB:GetItem(self.entry.id)
        end
        local color = ITEM_QUALITY_COLORS[quality]
        self._name:SetText(name)
        self._name:SetTextColor(color.r, color.g, color.b, 1)
        self._icon:SetQuality(quality)
    end;
}


class "AdventureGuideLoot" : extends "Frame" {
    __init = function(self, parent, page)
        Frame.__init(self, "Frame", parent)
        self:SetSize(VIEW_W + 20, VIEW_H + 30)
        self.page = page
        self._whole = false
        self._slot = nil              -- the slot filter; nil: every slot
        self._all = {}                -- the source's loot
        self._listed = {}             -- what passes the filter
        self._rows = {}

        self._scroll = AdventureGuideScroll(self, VIEW_W, VIEW_H, ROW_H)
        self._scroll:AlignParentBottomRight(1, 20)
        self._scroll:PlaceBar(5, 5, 5)
        self._scroll.OnScroll = function() self:_ShowRows() end
        for i = 1, POOL do
            self._rows[i] = AdventureGuideLootRow(self._scroll.content, self)
            self._rows[i]:Hide()
        end

        -- The menu is not on the canvas: its width is the dropdown's as drawn.
        self._dropdown = DropdownSimple(self, "MUI_AdventureGuideSlotFilter")
        self._dropdown:SetSize(140, 24)
        self._dropdown:AlignParentTopLeft(1, 22)
        self._menu = DropdownMenu(self._dropdown, "MUI_AdventureGuideSlotFilterMenu", self._dropdown)
        self._menu:SetMenuWidth(140 * Style.S)
        self._dropdown.OnClick = function() self._menu:Toggle() end

        self:RegisterEventHandler("GET_ITEM_INFO_RECEIVED", function(_, _, itemId)
            if not self:IsVisible() then return end
            for _, row in ipairs(self._rows) do
                if row:IsShown() and row.entry.id == itemId then row:Refresh() end
            end
        end)
    end;

    SetSource = function(self, instance, encounter)
        self._whole = encounter == nil
        self._all = {}
        local present = {}
        for _, boss in ipairs(encounter and { encounter } or instance.encounters) do
            local loot = boss.loot or {}
            for i = 1, #loot, 2 do
                local entry = { id = loot[i], chance = loot[i + 1], encounter = boss, slot = SlotOf(loot[i]) }
                self._all[#self._all + 1] = entry
                present[entry.slot] = true
            end
        end
        if self._slot and not present[self._slot] then self._slot = nil end
        self:_OfferSlots(present)
        self:_List()
    end;

    -- The filter offers the slots the list has something for. A menu's rows
    -- are made anew each time it is given items, so only for another set.
    _OfferSlots = function(self, present)
        local offered = ""
        for slot in ipairs(SLOT_NAMES) do
            if present[slot] then offered = offered .. slot .. " " end
        end
        if offered == self._offered then return end
        self._offered = offered

        local items = { { label = ALL_INVENTORY_SLOTS, OnClick = function() self:_SetSlot(nil) end } }
        for slot, name in ipairs(SLOT_NAMES) do
            if present[slot] then
                items[#items + 1] = { label = name, OnClick = function() self:_SetSlot(slot) end }
            end
        end
        self._menu:SetItems(items)
    end;

    _SetSlot = function(self, slot)
        self._slot = slot
        self:_List()
    end;

    _List = function(self)
        self._dropdown:SetText(self._slot and SLOT_NAMES[self._slot] or ALL_INVENTORY_SLOTS)
        self._listed = {}
        for _, entry in ipairs(self._all) do
            if not self._slot or entry.slot == self._slot then
                self._listed[#self._listed + 1] = entry
            end
        end
        self._scroll:SetContentHeight(#self._listed * self:_RowHeight())
        self._scroll:ScrollTo(0)
        self:_ShowRows()
    end;

    _RowHeight = function(self)
        return self._whole and ROW_H_INSTANCE or ROW_H
    end;

    -- The list can run to hundreds of items: only the rows in view exist,
    -- and they move down the content as it scrolls.
    _ShowRows = function(self)
        local height = self:_RowHeight()
        local first = math.floor(self._scroll:GetScroll() / height)
        for i, row in ipairs(self._rows) do
            local entry = self._listed[first + i]
            if entry then
                row:Set(entry, self._whole)
                row:ClearAllPoints()
                row:AlignParentTopLeft((first + i - 1) * height, 0)
            end
            row:SetVisible(entry ~= nil)
        end
    end;

    -- A plain click on an item of an instance's list opens its boss.
    OnRowClicked = function(self, entry)
        if self._whole then
            PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
            self.page:ShowEncounter(entry.encounter)
        end
    end;
}
