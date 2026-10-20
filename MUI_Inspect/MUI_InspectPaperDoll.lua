-- MUI_InspectPaperDoll: the inspect window's Character tab — retail's
-- InspectPaperDollFrame.
--
-- The inspected player's model stands on their race's backdrop inside the
-- character window's border (MUI_CharacterPaperDoll), their gear down both
-- sides and the weapons under it. The slots are Era's own buttons, moved
-- here: their tooltips and modified clicks stay Blizzard's, and they carry
-- retail's slot frames already; the quality border, which Era never draws,
-- is ours. Over the model, retail's level line with the class in its
-- colour, and its button to the dressing room. Out of range, where the
-- client has no model to draw, the faction's crest stands alone, as on
-- retail.
--
-- Retail's Talents button is left out: vanilla servers don't send an
-- inspected player's talents.

local SLOT, SLOT_GAP, WEAPON_GAP = 37, 4, 5
-- Retail's inspect model turns to Model_OnLoad's default.
local MODEL_FACING = 0.61

local LEFT    = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }
local RIGHT   = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }
local WEAPONS = { "MainHand", "SecondaryHand", "Ranged" }

local CRESTS = {
    Alliance = "Interface\\Timer\\Alliance-Logo",
    Horde    = "Interface\\Timer\\Horde-Logo",
}

-- What the dressing room puts on: the armour that shows, then each weapon
-- in its own hand. Not the ranged weapon, which would take a hand.
local OUTFIT = {
    INVSLOT_HEAD, INVSLOT_SHOULDER, INVSLOT_BACK, INVSLOT_CHEST, INVSLOT_BODY, INVSLOT_TABARD,
    INVSLOT_WRIST, INVSLOT_HAND, INVSLOT_WAIST, INVSLOT_LEGS, INVSLOT_FEET,
}

-- ---------------------------------------------------------------------
-- InspectSlot: one of Era's Inspect<Name>Slot buttons, with retail's
-- quality border.
-- ---------------------------------------------------------------------
class "InspectSlot" : extends "Button" {
    __init = function(self, name, parent)
        Button.__init(self, getglobal("Inspect" .. name .. "Slot"))
        self:SetParent(parent)
        self:PutInfront(parent, 1)
        self:ClearAllPoints()
        self.slot = self:GetID()

        self._quality = Texture(self, nil, "OVERLAY")
        self._quality:SetTexture("Interface\\Common\\WhiteIconFrame")
        self._quality:FillParent()
        self._quality:Hide()
    end;

    -- Common and better; nothing while the client has yet to load the item.
    UpdateQuality = function(self, unit)
        local link = GetInventoryItemLink(unit, self.slot)
        local quality = link and C_Item.GetItemQualityByID(link)
        local color = quality and quality >= 1 and BAG_ITEM_QUALITY_COLORS[quality]
        if color then
            self._quality:SetVertexColor(color.r, color.g, color.b)
        end
        self._quality:SetVisible(color and true or false)
    end;
}

-- ---------------------------------------------------------------------
-- InspectPaperDoll
-- ---------------------------------------------------------------------
class "InspectPaperDoll" : extends "CharacterPane" {

    -- Retail's frame width for the tab, and where its inset ends above the
    -- frame's bottom.
    frameWidth  = 338,
    insetBottom = 4,

    __init = function(self, window)
        CharacterPane.__init(self, window)

        self._stage = PaperDollStage(self)
        self.model = CharacterModel(self._stage, "MUI_InspectModel", nil, MODEL_FACING)
        self.model:PutInfront(self._stage.art, 1)
        self._border = PaperDollBorder(self, self.model)

        self._crest = Texture(self, nil, "OVERLAY")
        self._crest:SetSize(256, 256)
        self._crest:CenterAt(window.canvas, 0, -10)
        self._crest:Hide()

        self:_BuildSlots()
        self:_BuildHeader()

        self:HookScript("OnShow", function() self:Refresh() end)
        self:RegisterEventHandler("INSPECT_READY", function(_, _, guid)
            local unit = InspectFrame.unit
            if unit and UnitGUID(unit) == guid and self:IsVisible() then self:Refresh() end
        end)
        self:RegisterEventHandler("UNIT_LEVEL", function(_, _, unit)
            if unit == InspectFrame.unit and self:IsVisible() then self:_UpdateLevel(unit) end
        end)
        -- An item the client had not seen yet has no quality until its data arrives.
        self:RegisterEventHandler("GET_ITEM_INFO_RECEIVED", function()
            if self:IsVisible() then self:_UpdateQualities() end
        end)
        -- Era fills a slot on an inspect, and when the player changes gear.
        hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(native)
            local slot = self.slotsById[Button(native):GetID()]
            local unit = InspectFrame.unit
            if slot and unit then slot:UpdateQuality(unit) end
        end)
    end;

    -- Retail's level line in the strip under the title, and its button to
    -- the dressing room under that.
    _BuildHeader = function(self)
        self._level = FontString(self, nil, "OVERLAY")
        self._level:SetFontSize(10)
        self._level:SetTextColor(1, 0.82, 0, 1)
        self._level:SetWidth(220)
        self._level:SetWordWrap(false)
        self._level:AlignTop(self.window.canvas, 27)

        local view = ButtonGold(self, nil, VIEW_IN_DRESSUP_FRAME)
        view:SetSize(30 + view.label:GetStringWidth(), 22)
        view:AlignTop(self.window.canvas, 39)
        view:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        view.OnClick = function() self:_ViewInDressingRoom() end
    end;

    -- The columns of the character window's paper doll. Era has a third
    -- weapon: the row of three is centred under the model.
    _BuildSlots = function(self)
        local holder = Frame("Frame", self)
        holder:FillParent()
        holder:PutInfront(self._border, 1)

        self.slotsById = {}
        local function add(name)
            local slot = InspectSlot(name, holder)
            self.slotsById[slot.slot] = slot
            return slot
        end

        local previous
        for i, name in ipairs(LEFT) do
            local slot = add(name)
            if i == 1 then slot:AlignParentTopLeft(2, 4) else slot:Below(previous, SLOT_GAP) end
            previous = slot
        end
        for i, name in ipairs(RIGHT) do
            local slot = add(name)
            if i == 1 then slot:AlignParentTopRight(2, 4) else slot:Below(previous, SLOT_GAP) end
            previous = slot
        end
        local row = #WEAPONS * SLOT + (#WEAPONS - 1) * WEAPON_GAP
        for i, name in ipairs(WEAPONS) do
            local slot = add(name)
            if i == 1 then
                slot:AlignParentBottom(12, (SLOT - row) / 2)
            else
                slot:RightOf(previous, WEAPON_GAP)
            end
            previous = slot
        end
    end;

    -- "Level 60 Warrior", the class in its colour: retail's line for a
    -- player whose specialization it doesn't know.
    _UpdateLevel = function(self, unit)
        local level = UnitLevel(unit)
        local className, classFile = UnitClass(unit)
        if not classFile then return end
        local color = MUI.ClassColor(classFile):GenerateHexColor()
        self._level:SetText(PLAYER_LEVEL_NO_SPEC:format(level == -1 and "??" or level, color, className))
    end;

    _UpdateQualities = function(self)
        local unit = InspectFrame.unit
        if not unit then return end
        for _, slot in pairs(self.slotsById) do
            slot:UpdateQuality(unit)
        end
    end;

    Refresh = function(self)
        local unit = InspectFrame.unit
        if not unit then return end
        self:_UpdateLevel(unit)
        self:_UpdateQualities()

        local _, race = UnitRace(unit)
        if race then self._stage:SetRace(race) end
        self.model:Follow(unit)
        self._stage:Show()
        self._border:Show()
        local crest = not self.model:Refresh() and CRESTS[UnitFactionGroup(unit)]
        if crest then self._crest:SetTexture(crest) end
        self._crest:SetVisible(crest and true or false)
        self._stage:SetVisible(not crest)
        self._border:SetVisible(not crest)
    end;

    -- Retail's button: the player's own model in the dressing room, in what
    -- the inspected player wears. Era opens the dressing room through the
    -- panel manager, which addon code can't do in combat.
    _ViewInDressingRoom = function(self)
        local unit = InspectFrame.unit
        if not unit or (InCombatLockdown() and not Frame(DressUpFrame):IsShown()) then return end
        DressUpFrame_Show()
        local model = DressUpModel(DressUpModelFrame)
        model:Undress()
        for _, slot in ipairs(OUTFIT) do
            local link = GetInventoryItemLink(unit, slot)
            if link then model:TryOn(link) end
        end
        local mainHand = GetInventoryItemLink(unit, INVSLOT_MAINHAND)
        if mainHand then model:TryOn(mainHand, "MAINHANDSLOT") end
        local offHand = GetInventoryItemLink(unit, INVSLOT_OFFHAND)
        if offHand then model:TryOn(offHand, "SECONDARYHANDSLOT") end
    end;
}
