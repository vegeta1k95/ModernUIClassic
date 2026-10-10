-- MUI_CharacterEquipment: retail's equipment manager on Era, which has no
-- equipment sets of its own.
--
--   EquipmentSets              the sets, kept per character in MUI_DB:
--                              { name, icon, items = { [slot] = link },
--                                ignored = { [slot] = true } }
--   CharacterEquipmentFlyout   what in the bags could go in a slot, offered
--                              beside it (retail's EquipmentFlyout): under Alt,
--                              or from the slot's arrow while the manager shows
--   CharacterEquipmentManager  the side pane listing the sets

local FLYOUT_ART   = "Interface\\PaperDollInfoFrame\\UI-GearManager-Flyout"
local IGNORE_ART   = "Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Opaque"
local UNIGNORE_ART = "Interface\\PaperDollInfoFrame\\UI-GearManager-Undo"
local INTO_BAG_ART = "Interface\\PaperDollInfoFrame\\UI-GearManager-ItemIntoBag"
local PLUS_ART     = "Interface\\PaperDollInfoFrame\\Character-Plus"
local PARTS        = "Interface\\CharacterFrame\\Char-Paperdoll-Parts"

local FIRST_SLOT, LAST_SLOT = 1, 19
local MAX_SETS = 10

-- The kinds of item each inventory slot takes (0 is the ammo slot).
local SLOT_TYPES = {
    [0]  = { INVTYPE_AMMO = true },
    [1]  = { INVTYPE_HEAD = true },
    [2]  = { INVTYPE_NECK = true },
    [3]  = { INVTYPE_SHOULDER = true },
    [4]  = { INVTYPE_BODY = true },
    [5]  = { INVTYPE_CHEST = true, INVTYPE_ROBE = true },
    [6]  = { INVTYPE_WAIST = true },
    [7]  = { INVTYPE_LEGS = true },
    [8]  = { INVTYPE_FEET = true },
    [9]  = { INVTYPE_WRIST = true },
    [10] = { INVTYPE_HAND = true },
    [11] = { INVTYPE_FINGER = true },
    [12] = { INVTYPE_FINGER = true },
    [13] = { INVTYPE_TRINKET = true },
    [14] = { INVTYPE_TRINKET = true },
    [15] = { INVTYPE_CLOAK = true },
    [16] = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true },
    [17] = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true },
    [18] = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true, INVTYPE_RELIC = true },
    [19] = { INVTYPE_TABARD = true },
}

local FLYOUT_SLOT, FLYOUT_GAP_X, FLYOUT_GAP_Y = 37, 4, 5
local FLYOUT_PER_ROW, FLYOUT_MAX = 5, 20

-- Retail's EquipmentManagerPane: rows of 169x44 in a list 172 wide, 331 tall.
local ROW_W, ROW_H = 169, 44
local LIST_W, LIST_H = 172, 331

-- The set dialog is retail's icon selector: icons of 36 px, 46 apart, ten to
-- a row.
local DIALOG_W, DIALOG_H = 510, 518
local ICON_SIZE, ICON_PITCH = 36, 46
local ICON_COLUMNS, ICON_ROWS = 10, 8
local GRID_LEFT, GRID_TOP = 24, 112
local SCROLL_ROWS = 2         -- rows a notch of the wheel moves the icons
local ICON_PATH = "INTERFACE\\ICONS\\"
local QUESTION_MARK = "INV_MISC_QUESTIONMARK"
local FILTER_NAMES = { all = ICON_FILTER_ALL, spell = ICON_FILTER_SPELL, item = ICON_FILTER_ITEM }

local POPUP_DELETE = "MUI_EQUIPMENT_SET_DELETE"
local POPUP_SAVE   = "MUI_EQUIPMENT_SET_SAVE"

-- Retail's two confirmations, acting on our sets.
StaticPopupDialogs[POPUP_DELETE] = {
    text = "Are you sure you want to delete the equipment set %s?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(dialog, data) MUI_EquipmentSets:Delete(data.set) end,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1,
}
StaticPopupDialogs[POPUP_SAVE] = {
    text = "Would you like to save the equipment set \"%s\"?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(dialog, data) MUI_EquipmentSets:Save(data.set, data.ignored) end,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1,
}

local function ItemId(link)
    return link and tonumber(link:match("item:(%d+)"))
end

-- ---------------------------------------------------------------------
-- EquipmentSets
-- ---------------------------------------------------------------------
object "EquipmentSets" {

    MAX = MAX_SETS,

    All = function(self)
        return MUI_DB.data.equipmentSets
    end;

    Find = function(self, name)
        for _, set in ipairs(self:All()) do
            if set.name == name then return set end
        end
    end;

    -- What is worn now, less the ignored slots.
    _Snapshot = function(self, ignored)
        local items = {}
        for slot = FIRST_SLOT, LAST_SLOT do
            if not ignored[slot] then
                items[slot] = GetInventoryItemLink("player", slot)
            end
        end
        return items
    end;

    _Changed = function(self)
        if self.OnChanged then self:OnChanged() end
    end;

    Create = function(self, name, icon, ignored)
        local set = { name = name, icon = icon, items = self:_Snapshot(ignored), ignored = CopyTable(ignored) }
        table.insert(self:All(), set)
        self:_Changed()
        return set
    end;

    -- Take what is worn now as the set's items.
    Save = function(self, set, ignored)
        set.items   = self:_Snapshot(ignored)
        set.ignored = CopyTable(ignored)
        self:_Changed()
    end;

    Modify = function(self, set, name, icon)
        set.name, set.icon = name, icon
        self:_Changed()
    end;

    Delete = function(self, set)
        tDeleteItem(self:All(), set)
        self:_Changed()
    end;

    -- Where an item is in the bags: bag, slot.
    FindInBags = function(self, itemId)
        for bag = 0, NUM_BAG_SLOTS do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                if C_Container.GetContainerItemID(bag, slot) == itemId then
                    return bag, slot
                end
            end
        end
    end;

    -- Whether every item of the set is worn, and how many are neither worn
    -- nor in the bags.
    Status = function(self, set)
        local items, worn, missing = 0, 0, 0
        for slot = FIRST_SLOT, LAST_SLOT do
            local id = ItemId(set.items[slot])
            if id then
                items = items + 1
                if ItemId(GetInventoryItemLink("player", slot)) == id then
                    worn = worn + 1
                elseif not self:FindInBags(id) then
                    missing = missing + 1
                end
            end
        end
        return items > 0 and worn == items, missing
    end;

    -- Put the set on. Armor cannot change in combat: the set waits for it to end.
    Equip = function(self, set)
        if InCombatLockdown() then
            self._pending = set
            UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1)
            return
        end
        self._pending = nil
        for slot = FIRST_SLOT, LAST_SLOT do
            local link = set.items[slot]
            if link and ItemId(GetInventoryItemLink("player", slot)) ~= ItemId(link) then
                EquipItemByName(link, slot)
            end
        end
    end;

    EquipPending = function(self)
        if self._pending then self:Equip(self._pending) end
    end;

    -- The first free slot of the bags: bag, slot.
    FreeBagSlot = function(self)
        for bag = 0, NUM_BAG_SLOTS do
            local free, family = C_Container.GetContainerNumFreeSlots(bag)
            if free > 0 and family == 0 then
                for slot = 1, C_Container.GetContainerNumSlots(bag) do
                    if not C_Container.GetContainerItemID(bag, slot) then return bag, slot end
                end
            end
        end
    end;

    -- Take off what is in an inventory slot, into the bags.
    Unequip = function(self, slot)
        local bag, bagSlot = self:FreeBagSlot()
        if not bag then
            UIErrorsFrame:AddMessage(ERR_INV_FULL, 1, 0.1, 0.1)
            return
        end
        PickupInventoryItem(slot)
        C_Container.PickupContainerItem(bag, bagSlot)
    end;

    -- Every bag item that fits an inventory slot: { bag, slot, link, icon, quality }.
    Candidates = function(self, slot)
        local accept, found = SLOT_TYPES[slot], {}
        for bag = 0, NUM_BAG_SLOTS do
            for bagSlot = 1, C_Container.GetContainerNumSlots(bag) do
                local info = C_Container.GetContainerItemInfo(bag, bagSlot)
                if info then
                    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(info.itemID)
                    if accept[equipLoc] then
                        found[#found + 1] = { bag = bag, slot = bagSlot, link = info.hyperlink, icon = info.iconFileID, quality = info.quality }
                    end
                end
            end
        end
        return found
    end;
}

-- ---------------------------------------------------------------------
-- CharacterFlyoutButton: one offer in the flyout.
-- ---------------------------------------------------------------------
class "CharacterFlyoutButton" : extends "Button" {
    __init = function(self, parent)
        Button.__init(self, parent)
        self:SetSize(FLYOUT_SLOT, FLYOUT_SLOT)
        self:SetClickSound(nil)

        self._icon = Texture(self, nil, "ARTWORK")
        self._icon:FillParent()
        self._quality = Texture(self, nil, "OVERLAY")
        self._quality:SetTexture("Interface\\Common\\WhiteIconFrame")
        self._quality:FillParent()
        local highlight = Texture(self, nil, "HIGHLIGHT")
        highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        highlight:SetBlendMode("ADD")
        highlight:FillParent()

        self:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            if self.link then
                tooltip:SetHyperlink(self.link)
            else
                tooltip:AddLine(self.text, 1, 1, 1, false, 13)
            end
        end)
    end;

    -- A bag item to equip, or (link nil) a plain action with a caption.
    Set = function(self, icon, link, quality, text, action)
        self._icon:SetTexture(icon)
        self.link, self.text, self.OnClick = link, text, action
        local color = quality and quality >= 1 and BAG_ITEM_QUALITY_COLORS[quality]
        if color then self._quality:SetVertexColor(color.r, color.g, color.b) end
        self._quality:SetVisible(color ~= nil)
    end;
}

-- ---------------------------------------------------------------------
-- CharacterEquipmentFlyout
-- ---------------------------------------------------------------------
class "CharacterEquipmentFlyout" : extends "Frame" {
    __init = function(self, paperDoll)
        Frame.__init(self, "Frame", paperDoll, "MUI_CharacterEquipmentFlyout")
        self:SetFrameStrata("HIGH")
        self:EnableMouse(true)
        self:Hide()
        self._paperDoll = paperDoll
        self._buttons = {}
        self._pieces = {}
        self.owner = nil          -- the CharacterSlot it is open for
        self._held = false        -- opened from the slot's arrow: stays without Alt

        -- Under Alt it stays only while the cursor is on the slot or on it.
        self:SetScript("OnUpdate", function()
            if self._held or not self.owner then return end
            if not IsAltKeyDown() or not (self.owner:IsMouseOver() or self:IsMouseOver()) then
                self:Close()
            end
        end)
        self:SetScript("OnHide", function() self:Close() end)
        local function refill()
            if self.owner and self:_Fill() == 0 then self:Close() end
        end
        self:RegisterEventHandler("BAG_UPDATE_DELAYED", refill)
        self:RegisterEventHandler("PLAYER_EQUIPMENT_CHANGED", refill)
    end;

    -- Open beside `slot` (a CharacterSlot); `held` keeps it open without Alt.
    Open = function(self, slot, held)
        if self.owner and self.owner ~= slot then self.owner:SetPopoutOpen(false) end
        self.owner, self._held = slot, held
        if self:_Fill() == 0 then
            self:Close()
            return
        end
        slot:SetPopoutOpen(true)
        self:Show()
    end;

    Close = function(self)
        if self.owner then self.owner:SetPopoutOpen(false) end
        self.owner = nil
        self:Hide()
    end;

    -- Opened from an arrow: a second click on the same arrow closes it.
    Toggle = function(self, slot)
        if self.owner == slot and self._held then
            self:Close()
        else
            self:Open(slot, true)
        end
    end;

    _Button = function(self, index)
        local button = self._buttons[index]
        if not button then
            button = CharacterFlyoutButton(self)
            local column, row = (index - 1) % FLYOUT_PER_ROW, math.floor((index - 1) / FLYOUT_PER_ROW)
            button:AlignParentTopLeft(3 + row * (FLYOUT_SLOT + FLYOUT_GAP_Y), 3 + column * (FLYOUT_SLOT + FLYOUT_GAP_X))
            self._buttons[index] = button
        end
        return button
    end;

    -- The offers: while the manager shows, the slot's ignore switch first;
    -- then "into the bags" when the slot holds something; then the items.
    _Fill = function(self)
        local slot = self.owner
        local manager = self._paperDoll.sidebar.manager
        local count = 0
        local function add(icon, link, quality, text, action)
            if count >= FLYOUT_MAX then return end
            count = count + 1
            local button = self:_Button(count)
            button:Set(icon, link, quality, text, action)
            button:Show()
        end

        if manager:IsVisible() and slot.slot ~= 0 then
            local ignored = manager:IsSlotIgnored(slot.slot)
            add(ignored and UNIGNORE_ART or IGNORE_ART, nil, nil,
                ignored and "Include this slot in the set" or "Ignore this slot when saving the set", function()
                manager:SetSlotIgnored(slot.slot, not ignored)
                self:_Fill()
            end)
        end
        if GetInventoryItemLink("player", slot.slot) then
            add(INTO_BAG_ART, nil, nil, "Place in bags", function()
                MUI_EquipmentSets:Unequip(slot.slot)
                self:Close()
            end)
        end
        for _, item in ipairs(MUI_EquipmentSets:Candidates(slot.slot)) do
            add(item.icon, item.link, item.quality, nil, function()
                if slot.slot == 0 then
                    C_Container.UseContainerItem(item.bag, item.slot)
                else
                    EquipItemByName(item.link, slot.slot)
                end
                self:Close()
            end)
        end
        for i = count + 1, #self._buttons do
            self._buttons[i]:Hide()
        end

        if count == 0 then return 0 end
        local columns, rows = math.min(count, FLYOUT_PER_ROW), math.ceil(count / FLYOUT_PER_ROW)
        local height = rows * (FLYOUT_SLOT + FLYOUT_GAP_Y) - FLYOUT_GAP_Y + 6
        self:SetSize(columns * (FLYOUT_SLOT + FLYOUT_GAP_X) - FLYOUT_GAP_X + 3, height)
        self:_Dress(count, rows)

        -- Under a weapon slot, or to the right of any other, tops level.
        self:ClearAllPoints()
        if slot.vertical then
            self:AnchorToTopOf(slot, FLYOUT_SLOT + 12)
        else
            self:RightOf(slot, 12, (FLYOUT_SLOT - height) / 2)
        end
        return count
    end;

    -- Retail's flyout art: one slot, one row of up to five, or rows of five.
    _Dress = function(self, count, rows)
        local used = 0
        local function piece(l, r, t, b, width, height, x, y)
            used = used + 1
            local texture = self._pieces[used]
            if not texture then
                texture = Texture(self, nil, "BACKGROUND")
                texture:SetTexture(FLYOUT_ART)
                self._pieces[used] = texture
            end
            texture:SetTexCoord(l, r, t, b)
            texture:SetSize(width, height)
            texture:ClearAllPoints()
            texture:AlignParentTopLeft(y, x)
            texture:Show()
        end

        if count == 1 then
            piece(0, 0.09765625, 0.5546875, 0.77734375, 25, 54, -5, -4)
            piece(0.41796875, 0.51171875, 0.5546875, 0.77734375, 24, 54, 20, -4)
        elseif rows == 1 then
            piece(0, 0.16796875, 0.5546875, 0.77734375, 43, 54, -5, -4)
            for i = 1, count - 2 do
                piece(0.16796875, 0.328125, 0.5546875, 0.77734375, 41, 54, 38 + (i - 1) * 41, -4)
            end
            piece(0.328125, 0.51171875, 0.5546875, 0.77734375, 47, 54, 38 + (count - 2) * 41, -4)
        else
            piece(0, 0.8359375, 0, 0.19140625, 214, 49, -5, -4)
            for i = 1, rows - 2 do
                piece(0, 0.8359375, 0.19140625, 0.35546875, 214, 42, -5, 45 + (i - 1) * 42)
            end
            piece(0, 0.8359375, 0.35546875, 0.546875, 214, 49, -5, 45 + (rows - 2) * 42)
        end
        for i = used + 1, #self._pieces do
            self._pieces[i]:Hide()
        end
    end;
}

-- ---------------------------------------------------------------------
-- CharacterSetRow: a set in the manager's list, or the "New Set" entry.
-- ---------------------------------------------------------------------
class "CharacterSetRow" : extends "Button" {
    __init = function(self, parent, manager)
        Button.__init(self, parent)
        self:SetSize(ROW_W, ROW_H)
        self:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)

        -- Retail's plate: a cap above and below (one piece, turned over for
        -- the lower one) and the run between them. The sets share one
        -- plate, capped on the first and the last row.
        self._capTop = Texture(self, nil, "BACKGROUND")
        self._capTop:SetTextureRegion(PARTS, 256, 128, 1, 65, 169, 9)
        self._capTop:SetSize(169, 9)
        self._capTop:AlignParentTopLeft(-1, 0)
        self._capBottom = Texture(self, nil, "BACKGROUND")
        self._capBottom:SetTextureRegion(PARTS, 256, 128, 1, 65, 169, 9, true, true)
        self._capBottom:SetSize(169, 9)
        self._capBottom:AlignParentBottomLeft(-4, 0)
        self._run = Texture(self, nil, "BACKGROUND")
        self._run:SetTexture("Interface\\CharacterFrame\\Char-Stat-Middle", "CLAMP", "REPEAT")
        self._run:SetVertTile(true)
        self._run:SetTexCoord(0.00390625, 0.6640625, 0, 1)
        self._run:SetWidth(169)

        self._stripe = Texture(self, nil, "BACKGROUND")
        self._stripe:SetDrawLayer("BACKGROUND", 1)
        self._stripe:SetColorTexture(0.9, 0.9, 1, 0.1)
        self._stripe:FillParentPadding(1, 0, 0, 0)

        self._selected = Texture(self, nil, "OVERLAY")
        self._selected:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")
        self._selected:SetTexCoord(0.2, 0.8, 0, 1)
        self._selected:SetBlendMode("ADD")
        self._selected:SetAlpha(0.4)
        self._selected:FillParent()
        local hover = Texture(self, nil, "HIGHLIGHT")
        hover:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar-Blue")
        hover:SetTexCoord(0.2, 0.8, 0, 1)
        hover:SetBlendMode("ADD")
        hover:SetAlpha(0.4)
        hover:FillParent()

        self._icon = Texture(self, nil, "ARTWORK")
        self._check = Texture(self, nil, "BORDER")
        self._check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        self._check:SetSize(16, 16)
        self._check:AlignParentRight(8)
        self._name = FontString(self, nil, "ARTWORK")
        self._name:SetFontSize(12)
        self._name:SetJustifyH("LEFT")
        self._name:SetSize(98, 38)
        self._name:AlignParentLeft(44)

        self._delete = self:_Tool("Interface\\Buttons\\UI-GroupLoot-Pass-Up", 14, "Delete")
        self._delete:AlignParentBottomRight(2, 2)
        self._delete.OnClick = function() manager:ConfirmDelete(self.set) end
        self._edit = self:_Tool("Interface\\WorldMap\\GEAR_64GREY", 16, "Change the name and icon")
        self._edit:LeftOf(self._delete, 1)
        self._edit.OnClick = function() manager:EditSet(self.set) end

        self.OnClick = function() manager:Select(self.set) end
        self:SetScript("OnDoubleClick", function()
            if self.set then MUI_EquipmentSets:Equip(self.set) end
        end)
        self:SetTooltip("ANCHOR_RIGHT", function(tooltip) manager:BuildSetTooltip(tooltip, self.set) end)
    end;

    -- One of the small buttons the selected row shows: half faded until
    -- the cursor is on it.
    _Tool = function(self, texture, size, tip)
        local button = ButtonSimple(self)
        button:SetTexture(texture, 1, 1, 0, 0, 1, 1)
        button:SetSize(size, size)
        button:SetAlpha(0.5)
        button.OnEnter = function() button:SetAlpha(1) end
        button.OnLeave = function() button:SetAlpha(0.5) end
        button:SetTooltip("ANCHOR_RIGHT", function(tooltip) tooltip:AddLine(tip, 1, 1, 1) end)
        return button
    end;

    -- set nil: the "New Set" entry, on a plate of its own. first / last:
    -- the row opens / closes the plate the sets share.
    Set = function(self, set, index, selected, first, last)
        self.set = set
        local capTop, capBottom = first or not set, last or not set
        self._capTop:SetVisible(capTop)
        self._capBottom:SetVisible(capBottom)
        self._run:ClearAllPoints()
        self._run:AlignParentTopLeft(capTop and 8 or 0, 1)
        self._run:AlignParentBottomLeft(capBottom and 5 or 0, 1)

        self._stripe:SetVisible(set ~= nil and index % 2 == 0)
        self._selected:SetVisible(selected)
        self._delete:SetVisible(set ~= nil and selected)
        self._edit:SetVisible(set ~= nil and selected)
        self._icon:ClearAllPoints()
        if set then
            local equipped, missing = MUI_EquipmentSets:Status(set)
            self._icon:SetTexture(set.icon)
            self._icon:SetSize(36, 36)
            self._icon:AlignParentLeft(4)
            self._name:SetText(set.name)
            if missing > 0 then
                self._name:SetTextColor(1, 0.1, 0.1, 1)
            else
                self._name:SetTextColor(1, 0.82, 0, 1)
            end
            self._check:SetVisible(equipped)
        else
            self._icon:SetTexture(PLUS_ART)
            self._icon:SetSize(30, 30)
            self._icon:AlignParentLeft(7)
            self._name:SetText("New Set")
            self._name:SetTextColor(0.1, 1, 0.1, 1)
            self._check:Hide()
        end
    end;
}

-- ---------------------------------------------------------------------
-- CharacterSetIconButton: an icon in the set dialog, in retail's slot art,
-- ringed when it is the one chosen.
-- ---------------------------------------------------------------------
class "CharacterSetIconButton" : extends "Button" {
    __init = function(self, parent)
        Button.__init(self, parent)
        self:SetSize(ICON_SIZE, ICON_SIZE)
        self:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self.index = nil          -- its icon's place among those on offer

        local slot = Texture(self, nil, "BACKGROUND")
        slot:SetTexture("Interface\\Buttons\\UI-EmptySlot-Disabled")
        slot:SetTexCoord(0.140625, 0.84375, 0.140625, 0.84375)
        slot:SetSize(45, 45)
        slot:CenterInParent(0, -1)
        self._icon = Texture(self, nil, "ARTWORK")
        self._icon:SetSize(ICON_SIZE, ICON_SIZE)
        self._icon:CenterInParent(0, -1)
        self._ring = Texture(self, nil, "OVERLAY")
        self._ring:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        self._ring:SetBlendMode("ADD")
        self._ring:FillParent()
        self._ring:Hide()
        local glow = Texture(self, nil, "HIGHLIGHT")
        glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        glow:SetBlendMode("ADD")
        glow:FillParent()
    end;

    Set = function(self, texture, chosen)
        self._icon:SetTexture(texture)
        self._ring:SetVisible(chosen)
    end;
}

-- ---------------------------------------------------------------------
-- CharacterSetDialog: a set's name and icon — retail's icon selector, which
-- is its equipment set dialog and, on this client, the macro window's. The
-- icons on offer are the ones macros choose from: the question mark, those
-- of what is worn, then every spell icon and every item icon the client
-- has. An item, a spell or a macro on the cursor, dropped on the chosen
-- icon, gives its own.
-- ---------------------------------------------------------------------
class "CharacterSetDialog" : extends "Panel" {
    __init = function(self, parent)
        Panel.__init(self, parent, "MUI_CharacterSetDialog", "")
        self:SetFrameStrata("DIALOG")
        self:SetSize(DIALOG_W, DIALOG_H)
        self:Hide()
        self._icon    = nil       -- the icon chosen
        self._chosen  = nil       -- its place among those on offer, when it is one of them
        self._filter  = "all"
        self._lists   = nil       -- the icons on offer, one list after another, while the dialog shows
        self._first   = 0         -- rows scrolled off the top
        self._buttons = {}

        local prompt = FontString(self, nil, "ARTWORK")
        prompt:SetFontSize(10.5)
        prompt:SetTextColor(1, 0.82, 0, 1)
        prompt:SetText("Enter a name for this set:")
        prompt:AlignParentTopLeft(34, GRID_LEFT)

        self._name = EditBox(self)
        self._name:SetSize(190, 22)
        self._name:AlignParentTopLeft(50, GRID_LEFT)
        self._name:SetMaxLetters(16)
        self._name.OnEnterPressed = function() self:_Accept() end
        self._name.OnTextChanged = function() self:_Validate() end

        self:_BuildChosen()
        self:_BuildFilter()
        self:_BuildGrid()

        local cancel = ButtonGold(self, nil, CANCEL)
        cancel:SetSize(100, 22)
        cancel:AlignParentBottomRight(14, 18)
        cancel.OnClick = function() self:Hide() end
        self._okay = ButtonGold(self, nil, OKAY)
        self._okay:SetSize(100, 22)
        self._okay:LeftOf(cancel, 6)
        self._okay.OnClick = function() self:_Accept() end

        -- The lists are thousands of icons long: kept only while it shows.
        self:SetScript("OnHide", function()
            self._lists, self._worn, self._spells, self._items = nil, nil, nil, nil
        end)
    end;

    -- The chosen icon, top right, as retail shows it. A click with an item,
    -- a spell or a macro on the cursor takes that one's icon.
    _BuildChosen = function(self)
        self._preview = CharacterSetIconButton(self)
        self._preview:AlignParentTopRight(36, 20)
        self._preview.OnClick = function() self:_TakeFromCursor() end
        self._preview:SetScript("OnReceiveDrag", function() self:_TakeFromCursor() end)

        local caption = FontString(self, nil, "ARTWORK")
        caption:SetFontSize(10)
        caption:SetTextColor(1, 0.82, 0, 1)
        caption:SetText(ICON_SELECTION_TITLE_CURRENT)
        caption:LeftOf(self._preview, 8)
    end;

    -- All the icons, the spells' or the items'.
    _BuildFilter = function(self)
        local label = FontString(self, nil, "ARTWORK")
        label:SetFontSize(10)
        label:SetTextColor(1, 1, 1, 1)
        label:SetText(MACRO_POPUP_CHOOSE_ICON)
        label:AlignParentTopLeft(GRID_TOP - 20, GRID_LEFT)

        self._filterButton = DropdownSimple(self, "MUI_CharacterSetIconFilter")
        self._filterButton:SetSize(130, 22)
        self._filterButton:AlignParentTopRight(GRID_TOP - 28, 18)

        local menu = DropdownMenu(self._filterButton, "MUI_CharacterSetIconFilterMenu", self._filterButton)
        menu:SetMenuWidth(130)
        local function choice(filter)
            return { label = FILTER_NAMES[filter], OnClick = function() self:_SetFilter(filter) end }
        end
        menu:SetItems({ choice("all"), choice("spell"), choice("item") })
        self._filterButton.OnClick = function() menu:Toggle() end
    end;

    -- A screenful of icons: the buttons stay where they are and show the
    -- rows the bar has scrolled to.
    _BuildGrid = function(self)
        local grid = Frame("Frame", self)
        grid:SetSize((ICON_COLUMNS - 1) * ICON_PITCH + ICON_SIZE, (ICON_ROWS - 1) * ICON_PITCH + ICON_SIZE)
        grid:AlignParentTopLeft(GRID_TOP, GRID_LEFT)
        for i = 1, ICON_COLUMNS * ICON_ROWS do
            local button = CharacterSetIconButton(grid)
            button:AlignParentTopLeft(math.floor((i - 1) / ICON_COLUMNS) * ICON_PITCH, ((i - 1) % ICON_COLUMNS) * ICON_PITCH)
            button.OnClick = function() self:_Choose(self:_IconAt(button.index), button.index) end
            self._buttons[i] = button
        end

        self._bar = MinimalScrollBar(self)
        self._bar:SetHeight((ICON_ROWS - 1) * ICON_PITCH + ICON_SIZE)
        self._bar:AlignParentTopRight(GRID_TOP, 18)
        self._bar:SetScrollSpeed(SCROLL_ROWS)
        self._bar.OnScroll = function(_, value)
            self._first = math.floor(value + 0.5)
            self:_ShowIcons()
        end
        grid:EnableMouseWheel(true)
        grid:SetScript("OnMouseWheel", function(_, delta)
            self._bar:SetValue(self._bar:GetValue() - delta * SCROLL_ROWS)
        end)
    end;

    -- name / icon: what the set has now (nil for a new one, which starts on
    -- the icon of the first thing worn); done(name, icon).
    Open = function(self, title, name, icon, done)
        self._done = done
        self:SetTitle(title)
        self._name:SetText(name or "")

        self:_LoadIcons()
        self._icon = icon or self._worn[1] or ICON_PATH .. QUESTION_MARK
        self._preview:Set(self._icon, false)
        self:_SetFilter("all")

        self:_Validate()
        self:Show()
        self._name:SetFocus()
    end;

    -- ---- the icons on offer ---------------------------------------------

    -- The client's own lists, as it hands them to the macro window: an entry
    -- is a file's id, or the bare name of a file in Interface\Icons.
    _LoadIcons = function(self)
        local worn, seen = {}, {}
        for slot = FIRST_SLOT, LAST_SLOT do
            local texture = GetInventoryItemTexture("player", slot)
            if texture and not seen[texture] then
                seen[texture] = true
                worn[#worn + 1] = texture
            end
        end
        local spells, items = {}, {}
        GetLooseMacroIcons(spells)
        GetMacroIcons(spells)
        GetLooseMacroItemIcons(items)
        GetMacroItemIcons(items)
        self._worn, self._spells, self._items = worn, spells, items
    end;

    -- In the macro window's order: the question mark, what is worn (with
    -- the items), the spells' icons, the items'.
    _SetFilter = function(self, filter)
        self._filter = filter
        self._filterButton:SetText(FILTER_NAMES[filter])
        local lists = { { QUESTION_MARK } }
        if filter ~= "spell" then lists[#lists + 1] = self._worn end
        if filter ~= "item" then lists[#lists + 1] = self._spells end
        if filter ~= "spell" then lists[#lists + 1] = self._items end
        self._lists = lists

        local rows = math.ceil(self:_Count() / ICON_COLUMNS)
        self._bar:SetMinMax(0, math.max(0, rows - ICON_ROWS))
        self._bar:SetContentSize(ICON_ROWS, math.max(rows, 1))
        self._chosen = self:_IndexOf(self._icon)
        self:_ScrollTo(self._chosen or 1)
    end;

    _Count = function(self)
        local count = 0
        for _, list in ipairs(self._lists) do
            count = count + #list
        end
        return count
    end;

    _IconAt = function(self, index)
        for _, list in ipairs(self._lists) do
            if index <= #list then
                local texture = list[index]
                return tonumber(texture) or ICON_PATH .. texture
            end
            index = index - #list
        end
    end;

    -- Where an icon is among those on offer; nil when it is not one of them.
    _IndexOf = function(self, icon)
        local name = type(icon) == "string" and strupper(icon)
        local index = 0
        for _, list in ipairs(self._lists) do
            for _, texture in ipairs(list) do
                index = index + 1
                local id = tonumber(texture)
                if id then
                    if id == icon then return index end
                elseif name and strupper(ICON_PATH .. texture) == name then
                    return index
                end
            end
        end
    end;

    _ShowIcons = function(self)
        local count = self:_Count()
        for i, button in ipairs(self._buttons) do
            local index = self._first * ICON_COLUMNS + i
            button.index = index
            button:SetVisible(index <= count)
            if index <= count then
                button:Set(self:_IconAt(index), index == self._chosen)
            end
        end
    end;

    -- Bring the row of the icon at `index` into view (to the top, when it
    -- was out of it), and show the icons as the bar now stands.
    _ScrollTo = function(self, index)
        local row = math.floor((index - 1) / ICON_COLUMNS)
        if row < self._first or row >= self._first + ICON_ROWS then
            self._bar:SetValue(row)
        end
        self._first = math.floor(self._bar:GetValue() + 0.5)
        self:_ShowIcons()
    end;

    -- `index`: the icon's place among those on offer, when the caller has it.
    _Choose = function(self, texture, index)
        self._icon = texture
        self._chosen = index or self:_IndexOf(texture)
        self._preview:Set(texture, false)
        self:_ShowIcons()
    end;

    -- The icon of what the cursor holds: an item, a spell or a macro.
    _TakeFromCursor = function(self)
        local kind, id, _, spellId = GetCursorInfo()
        local texture
        if kind == "item" then
            texture = C_Item.GetItemIconByID(id)
        elseif kind == "spell" then
            texture = C_Spell.GetSpellTexture(spellId)
        elseif kind == "macro" then
            texture = select(2, GetMacroInfo(id))
        end
        if not texture then return end
        ClearCursor()
        self:_Choose(texture)
        if self._chosen then self:_ScrollTo(self._chosen) end
    end;

    _Validate = function(self)
        self._okay:SetEnabled(strtrim(self._name:GetText()) ~= "")
    end;

    _Accept = function(self)
        local name = strtrim(self._name:GetText())
        if name == "" then return end
        self:Hide()
        self._done(name, self._icon)
    end;
}

-- ---------------------------------------------------------------------
-- CharacterEquipmentManager
-- ---------------------------------------------------------------------
class "CharacterEquipmentManager" : extends "Frame" {
    __init = function(self, parent, paperDoll)
        Frame.__init(self, "Frame", parent)
        self:FillParent()
        self:Hide()
        self._paperDoll = paperDoll
        self._rows = {}
        self._selected = nil      -- the set the buttons act on
        self._ignored = {}        -- the slots left out of the next save

        -- The two buttons span the rows under them, a little in from the
        -- pane's left edge.
        self._equip = ButtonGold(self, nil, "Equip")
        self._equip:SetSize(83, 22)
        self._equip:AlignParentTopLeft(1, 7)
        self._equip.OnClick = function() MUI_EquipmentSets:Equip(self._selected) end
        self._save = ButtonGold(self, nil, "Save")
        self._save:SetSize(83, 22)
        self._save:RightOf(self._equip, 4)
        self._save.OnClick = function() self:_ConfirmSave() end

        -- The list under the buttons, and its scroll bar in the strip to
        -- its right: always there, as retail's is.
        self._scroll = CharacterScrollArea(self, LIST_H, ROW_H, "always")
        self._scroll:SetSize(LIST_W, LIST_H)
        self._scroll:AlignParentTopLeft(24, 5)
        self._scroll.bar:ClearAllPoints()
        self._scroll.bar:AlignParentTopLeft(7, 184)
        self._scroll.bar:AlignParentBottomLeft(30, 184)

        self._dialog = CharacterSetDialog(MUI_Root)
        self._dialog:CenterInParent(0, 40)

        MUI_EquipmentSets.OnChanged = function() self:Refresh() end
        self:HookScript("OnShow", function()
            self:Refresh()
            self:_ShowSlotArrows(true)
        end)
        self:HookScript("OnHide", function()
            self._dialog:Hide()
            self:_ShowSlotArrows(false)
        end)
        local function refresh() if self:IsVisible() then self:Refresh() end end
        self:RegisterEventHandler("PLAYER_EQUIPMENT_CHANGED", refresh)
        self:RegisterEventHandler("BAG_UPDATE_DELAYED", refresh)
        self:RegisterEventHandler("PLAYER_REGEN_ENABLED", function() MUI_EquipmentSets:EquipPending() end)
    end;

    -- ---- ignored slots -------------------------------------------------

    IsSlotIgnored = function(self, slot)
        return self._ignored[slot] == true
    end;

    SetSlotIgnored = function(self, slot, ignored)
        self._ignored[slot] = ignored or nil
        self:_ShowSlotArrows(true)
    end;

    -- While the pane shows, every slot offers its flyout from an arrow and
    -- wears a mark if the next save leaves it out.
    _ShowSlotArrows = function(self, shown)
        for _, slot in pairs(self._paperDoll.slots) do
            slot:SetPopoutShown(shown)
            slot:SetIgnored(shown and self._ignored[slot.slot] == true)
        end
    end;

    -- ---- the list ------------------------------------------------------

    Select = function(self, set)
        if not set then
            self:_NewSet()
            return
        end
        self._selected = set
        self._ignored = CopyTable(set.ignored)
        self:Refresh()
        self:_ShowSlotArrows(true)
    end;

    Refresh = function(self)
        local sets = MUI_EquipmentSets:All()
        if self._selected and not tContains(sets, self._selected) then
            self._selected = nil
        end
        local count = #sets
        if count < MUI_EquipmentSets.MAX then count = count + 1 end
        for i = 1, count do
            local row = self._rows[i]
            if not row then
                row = CharacterSetRow(self._scroll.content, self)
                row:AlignParentTopLeft((i - 1) * ROW_H, 2)
                self._rows[i] = row
            end
            row:Set(sets[i], i, sets[i] ~= nil and sets[i] == self._selected, i == 1, i == #sets)
            row:Show()
        end
        for i = count + 1, #self._rows do
            self._rows[i]:Hide()
        end
        self._scroll:SetContentHeight(count * ROW_H)

        self._equip:SetEnabled(self._selected ~= nil)
        self._save:SetEnabled(self._selected ~= nil)
    end;

    -- A new set starts without the shirt and the tabard, as retail's does.
    _NewSet = function(self)
        self._selected = nil
        self._ignored = { [4] = true, [19] = true }
        self:Refresh()
        self:_ShowSlotArrows(true)
        self._dialog:Open("New Equipment Set", nil, nil, function(name, icon)
            local existing = MUI_EquipmentSets:Find(name)
            if existing then
                MUI_EquipmentSets:Save(existing, self._ignored)
                self:Select(existing)
            else
                self:Select(MUI_EquipmentSets:Create(name, icon, self._ignored))
            end
        end)
    end;

    EditSet = function(self, set)
        self._dialog:Open("Equipment Set", set.name, set.icon, function(name, icon)
            MUI_EquipmentSets:Modify(set, name, icon)
        end)
    end;

    _ConfirmSave = function(self)
        local set = self._selected
        StaticPopup_Show(POPUP_SAVE, set.name, nil, { set = set, ignored = CopyTable(self._ignored) })
    end;

    ConfirmDelete = function(self, set)
        StaticPopup_Show(POPUP_DELETE, set.name, nil, { set = set })
    end;

    -- The set's items, each in its quality's colour; red when it is gone.
    BuildSetTooltip = function(self, tooltip, set)
        if not set then
            tooltip:AddLine("New Set", 1, 1, 1, false, 13)
            tooltip:AddLine("Save what you are wearing as an equipment set.", 1, 0.82, 0, true)
            return
        end
        tooltip:AddLine(set.name, 1, 1, 1, false, 13)
        for slot = FIRST_SLOT, LAST_SLOT do
            local link = set.items[slot]
            if link then
                local id = ItemId(link)
                local name, _, quality = C_Item.GetItemInfo(link)
                local worn = ItemId(GetInventoryItemLink("player", slot)) == id
                if not worn and not MUI_EquipmentSets:FindInBags(id) then
                    tooltip:AddLine(name or link, 1, 0.1, 0.1)
                else
                    local color = ITEM_QUALITY_COLORS[quality or 1]
                    tooltip:AddLine(name or link, color.r, color.g, color.b)
                end
            end
        end
        tooltip:AddLine("Double-click to equip.", 0.5, 0.5, 0.5)
    end;
}
