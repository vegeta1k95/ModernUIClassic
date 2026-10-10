-- MUI_CharacterPaperDoll: the Character tab — retail's PaperDollFrame.
--
-- The model stands on its race's dressing room backdrop inside retail's
-- inner border, the equipment slots down both sides and the weapons under
-- it, each in retail's slot frame. The slots are Era's own buttons, moved
-- here: their clicks (equip, use, drag, repair, link) stay Blizzard's, and
-- addons that decorate them still find them. Era never draws an item's
-- quality on them; that border is ours.
--
-- The side pane (stats, equipment manager) is MUI_CharacterSidebar.

local PARTS    = "Interface\\CharacterFrame\\Char-Paperdoll-Parts"
local EDGES_H  = "Interface\\CharacterFrame\\Char-Paperdoll-Horizontal"
local EDGES_V  = "Interface\\CharacterFrame\\Char-Paperdoll-Vertical"
local BACKDROP = "Interface\\DressUpFrame\\DressUpBackground-"
local POPOUT   = "Interface\\PaperDollInfoFrame\\UI-GearManager-FlyoutButton"

local SLOT, SLOT_GAP = 37, 4
local WEAPON_GAP = 5
local STAGE_W, STAGE_H = 231, 320
local MODEL_FACING = 0.35

local LEFT    = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }
local RIGHT   = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }
local WEAPONS = { "MainHand", "SecondaryHand", "Ranged" }

-- How dark the backdrop is kept, by race: retail's SetPaperDollBackground.
local BACKDROP_SHADE = { NightElf = 0.6, Scourge = 0.3, Troll = 0.6, Orc = 0.6 }

-- ---------------------------------------------------------------------
-- CharacterSlot: one of Era's Character<Name>Slot buttons, in retail's slot
-- frame for its `side` ("left", "right", "bottom"; nil for the ammo slot).
-- ---------------------------------------------------------------------
class "CharacterSlot" : extends "Button" {
    __init = function(self, name, parent, side)
        Button.__init(self, getglobal("Character" .. name .. "Slot"))
        self:SetParent(parent)
        self:PutInfront(parent, 1)
        self:ClearAllPoints()
        self.slot = self:GetID()

        if side then
            self.art = Texture(self, nil, "BACKGROUND")
            self.art:SetDrawLayer("BACKGROUND", -1)
        end
        if side == "left" then
            self.art:SetTextureRegion(PARTS, 256, 128, 53, 76, 49, 44)
            self.art:SetSize(49, 44)
            self.art:AlignParentTopLeft(0, -4)
        elseif side == "right" then
            self.art:SetTextureRegion(PARTS, 256, 128, 1, 76, 50, 44)
            self.art:SetSize(50, 44)
            self.art:AlignParentTopRight(0, -4)
        elseif side == "bottom" then
            self.art:SetTextureRegion(PARTS, 256, 128, 172, 1, 42, 53)
            self.art:SetSize(42, 53)
            self.art:AlignParentTopLeft(-8, -4)
        end

        self._quality = Texture(self, nil, "OVERLAY")
        self._quality:SetTexture("Interface\\Common\\WhiteIconFrame")
        self._quality:FillParent()
        self._quality:Hide()

        -- The mark of a slot an equipment set leaves alone.
        self._ignore = Texture(self, nil, "OVERLAY")
        self._ignore:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent")
        self._ignore:SetSize(40, 40)
        self._ignore:CenterInParent()
        self._ignore:Hide()

        -- The flyout's arrow: on the right edge, or under a weapon.
        self.vertical = side ~= "left" and side ~= "right"
        self._popout = Button(self)
        self._popout:SetClickSound(nil)
        self._popout:SetNormalTexture(POPOUT)
        self._popout:SetHighlightTexture(POPOUT)
        if self.vertical then
            self._popout:SetSize(32, 16)
            self._popout:Below(self, -5)
        else
            self._popout:SetSize(16, 32)
            self._popout:RightOf(self, -8)
        end
        self._popout:Hide()
        self._popout.OnClick = function()
            if self.OnPopout then self:OnPopout() end
        end
        self:SetPopoutOpen(false)
    end;

    SetPopoutShown = function(self, shown)
        self._popout:SetVisible(shown)
    end;

    -- The arrow points away from the slot until its flyout is open.
    SetPopoutOpen = function(self, open)
        local normal, highlight = self._popout:GetNormalTexture(), self._popout:GetHighlightTexture()
        if self.vertical then
            if open then
                normal:SetTexCoord(0.15625, 0.84375, 0, 0.5)
                highlight:SetTexCoord(0.15625, 0.84375, 0.5, 1)
            else
                normal:SetTexCoord(0.15625, 0.84375, 0.5, 0)
                highlight:SetTexCoord(0.15625, 0.84375, 1, 0.5)
            end
        elseif open then
            normal:SetTexCoord(0.15625, 0, 0.84375, 0, 0.15625, 0.5, 0.84375, 0.5)
            highlight:SetTexCoord(0.15625, 0.5, 0.84375, 0.5, 0.15625, 1, 0.84375, 1)
        else
            normal:SetTexCoord(0.15625, 0.5, 0.84375, 0.5, 0.15625, 0, 0.84375, 0)
            highlight:SetTexCoord(0.15625, 1, 0.84375, 1, 0.15625, 0.5, 0.84375, 0.5)
        end
    end;

    SetIgnored = function(self, ignored)
        self._ignore:SetVisible(ignored)
    end;

    UpdateQuality = function(self)
        local link = GetInventoryItemLink("player", self.slot)
        local quality = link and select(3, C_Item.GetItemInfo(link))
        local color = quality and quality >= 1 and BAG_ITEM_QUALITY_COLORS[quality]
        if color then
            self._quality:SetVertexColor(color.r, color.g, color.b)
            self._quality:Show()
        else
            self._quality:Hide()
        end
    end;
}

-- ---------------------------------------------------------------------
-- CharacterPaperDoll
-- ---------------------------------------------------------------------
class "CharacterPaperDoll" : extends "CharacterPane" {

    wide = true,

    __init = function(self, window)
        CharacterPane.__init(self, window)

        self:_BuildStage()
        self:_BuildBorder()
        self:_BuildSlots()
        self:BuildLevelText()
        self.sidebar = CharacterSidebar(self, window)
        self.flyout  = CharacterEquipmentFlyout(self)

        -- A slot's flyout opens from its arrow, or under Alt while the
        -- cursor is on the slot.
        for _, button in pairs(self.slots) do
            button.OnPopout = function() self.flyout:Toggle(button) end
            button:HookScript("OnEnter", function()
                self._hovered = button
                self:_OfferFlyout()
            end)
            button:HookScript("OnLeave", function()
                if self._hovered == button then self._hovered = nil end
            end)
        end
        self:RegisterEventHandler("MODIFIER_STATE_CHANGED", function() self:_OfferFlyout() end)

        self:HookScript("OnShow", function() self:Refresh() end)
        self:RegisterEventHandler("PLAYER_EQUIPMENT_CHANGED", function(_, _, slot)
            local button = self.slotsById[slot]
            if button then button:UpdateQuality() end
        end)
        -- An item the client had not seen yet has no quality until its data arrives.
        self:RegisterEventHandler("GET_ITEM_INFO_RECEIVED", function()
            if self:IsVisible() then self:_UpdateQualities() end
        end)
    end;

    -- Retail shows the specialization's icon in the ring; here that is the
    -- talent tree with the most points.
    GetPortrait = function(self)
        local spec = MUI_Talents:GetPrimarySpec()
        return "player", spec and MUI_SPEC_ICONS[MUI.GetClassID()][spec.index]
    end;

    -- ---- the model -----------------------------------------------------

    -- The model's rect, clipped: the backdrop is taller than it. The
    -- backdrop's four quarters are the dressing room's, desaturated and
    -- shaded as retail has them.
    _BuildStage = function(self)
        local stage = Frame("Frame", self)
        stage:SetSize(STAGE_W, STAGE_H)
        stage:AlignParentTopLeft(6, 48)
        stage:SetClipsChildren(true)
        self._stage = stage

        local art = Frame("Frame", stage)
        art:FillParent()
        local _, race = UnitRace("player")
        local quarters = {
            { 212, 245, 0,   0,   0.171875, 1,        0.0392156862745098, 1 },
            { 19,  245, 0,   212, 0,        0.296875, 0.0392156862745098, 1 },
            { 212, 128, 245, 0,   0.171875, 1,        0,                  1 },
            { 19,  128, 245, 212, 0,        0.296875, 0,                  1 },
        }
        for i, q in ipairs(quarters) do
            local t = Texture(art, nil, "BACKGROUND")
            t:SetTexture(BACKDROP .. race .. i)
            t:SetTexCoord(q[5], q[6], q[7], q[8])
            t:SetDesaturated(true)
            t:SetSize(q[1], q[2])
            t:AlignParentTopLeft(q[3], q[4])
        end
        local shade = Texture(art, nil, "BORDER")
        shade:SetColorTexture(0, 0, 0, BACKDROP_SHADE[race] or 0.7)
        shade:FillParent()

        self.model = CharacterModel(stage, "MUI_CharacterModel", "player", MODEL_FACING)
        self.model:PutInfront(art, 1)
    end;

    -- Retail's inner border around the model, and the line across the inset
    -- under it that the weapon slots sit on.
    _BuildBorder = function(self)
        local border = Frame("Frame", self)
        border:FillParent()
        border:PutInfront(self.model, 2)
        self._borderFrame = border

        local function corner(y)
            local t = Texture(border, nil, "OVERLAY")
            t:SetTextureRegion(PARTS, 256, 128, 104, y, 7, 7)
            t:SetSize(7, 7)
            return t
        end
        local topLeft, topRight       = corner(103), corner(94)
        local bottomLeft, bottomRight = corner(85), corner(76)
        topLeft:AlignParentTopLeft(4, 46)
        topRight:AlignParentTopRight(4, 47)
        bottomLeft:AlignParentBottomLeft(31, 46)
        bottomRight:AlignParentBottomRight(31, 47)

        local function vertical(l, r)
            local t = Texture(border, nil, "OVERLAY")
            t:SetTexture(EDGES_V)
            t:SetVertTile(true)
            t:SetTexCoord(l, r, 0, 1)
            t:SetWidth(5)
            return t
        end
        local function horizontal(t0, b0)
            local t = Texture(border, nil, "OVERLAY")
            t:SetTexture(EDGES_H)
            t:SetHorizTile(true)
            t:SetTexCoord(0, 1, t0, b0)
            t:SetHeight(5)
            return t
        end

        -- Each edge runs between two corners, a pixel outside them.
        local left = vertical(0.0625, 0.375)
        left:AlignParentTopLeft(11, 45)
        left:AlignParentBottomLeft(38, 45)
        local right = vertical(0.5, 0.8125)
        right:AlignParentTopRight(11, 46)
        right:AlignParentBottomRight(38, 46)
        local top = horizontal(0.5, 0.8125)
        top:AlignParentTopLeft(3, 53)
        top:AlignParentTopRight(3, 54)
        local bottom = horizontal(0.0625, 0.375)
        bottom:AlignParentBottomLeft(30, 53)
        bottom:AlignParentBottomRight(30, 54)

        local shelf = horizontal(0.0625, 0.375)
        shelf:AlignParentBottomLeft(27, 0)
        shelf:AlignParentBottomRight(27, 0)
    end;

    -- ---- the slots -----------------------------------------------------

    _BuildSlots = function(self)
        local holder = Frame("Frame", self)
        holder:FillParent()
        holder:PutInfront(self._borderFrame, 1)

        self.slots = {}
        self.slotsById = {}
        local function add(name, side)
            local button = CharacterSlot(name, holder, side)
            self.slots[name] = button
            self.slotsById[button.slot] = button
            return button
        end

        local previous
        for i, name in ipairs(LEFT) do
            local button = add(name, "left")
            if i == 1 then button:AlignParentTopLeft(2, 4) else button:Below(previous, SLOT_GAP) end
            previous = button
        end
        for i, name in ipairs(RIGHT) do
            local button = add(name, "right")
            if i == 1 then button:AlignParentTopRight(2, 4) else button:Below(previous, SLOT_GAP) end
            previous = button
        end

        -- Era has a third weapon: the row of three is centred under the
        -- model, where retail's two are, with the ammo slot beside it.
        local row = #WEAPONS * SLOT + (#WEAPONS - 1) * WEAPON_GAP
        for i, name in ipairs(WEAPONS) do
            local button = add(name, "bottom")
            if i == 1 then
                button:AlignParentBottom(12, (SLOT - row) / 2)
            else
                button:RightOf(previous, WEAPON_GAP)
            end
            previous = button
        end

        -- The row's end pieces, against the first and the last slot's frame.
        local first, last = self.slots.MainHand, self.slots.Ranged
        local capLeft = Texture(first, nil, "BACKGROUND")
        capLeft:SetDrawLayer("BACKGROUND", -1)
        capLeft:SetTextureRegion(PARTS, 256, 128, 181, 56, 6, 54)
        capLeft:SetSize(6, 54)
        capLeft:AlignParentTopLeft(-8, -10)
        local capRight = Texture(last, nil, "BACKGROUND")
        capRight:SetDrawLayer("BACKGROUND", -1)
        capRight:SetTextureRegion(PARTS, 256, 128, 172, 56, 7, 54)
        capRight:SetSize(7, 54)
        capRight:AlignParentTopLeft(-8, 38)

        -- The ammo slot keeps its own small frame, less the piece that
        -- joined it to the classic ranged slot (its one overlay texture;
        -- the quality border, hidden with it, shows again when it applies).
        local ammo = add("Ammo")
        ammo:RightOf(last, 16)
        for _, region in ipairs(ammo:GetRegions()) do
            if region:GetObjectType() == "Texture" and region:GetDrawLayer() == "OVERLAY" then
                region:Hide()
            end
        end
    end;

    _OfferFlyout = function(self)
        local slot = self._hovered
        if slot and IsAltKeyDown() and self.flyout.owner ~= slot and self:IsVisible() then
            self.flyout:Open(slot, false)
        end
    end;

    _UpdateQualities = function(self)
        for _, button in pairs(self.slots) do
            button:UpdateQuality()
        end
    end;

    Refresh = function(self)
        self:UpdateLevelText()
        self:_UpdateQualities()
    end;
}
