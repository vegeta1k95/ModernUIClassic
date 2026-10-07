-- MUI_BankTabs: the bank's bag slots as tabs down the window's right edge,
-- where retail has its bank tabs.
--
-- A bought slot shows the bag in it, or the empty-slot art: drop a bag on it
-- to put one in, drag it off to take it out; any other item dropped on it
-- goes into that bag. Hovering it lights the bag's slots in the grid. After
-- the bought slots comes one "+" tab, retail's purchase tab, for the next
-- slot on sale; the slots beyond it are not shown.
--
--   BankBagTab(parent, index, grid)     index 1..NUM_BANKBAGSLOTS
--     :Update()

local SIZE      = 29
local EMPTY_BAG = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"

class "BankBagTab" : extends "Button" {
    __init = function(self, parent, index, grid)
        Button.__init(self, parent, "MUI_BankBagTab" .. index)
        self:SetSize(SIZE, SIZE)
        self:SetClickSound(nil)
        self.index     = index
        self.container = NUM_BAG_SLOTS + index
        -- As Era's own bank bag buttons resolve theirs.
        self._inventorySlot = BankButtonIDToInvSlotID(index, 1)
        self._buying = false

        local border = Texture(self, nil, "BACKGROUND")
        border:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
        border:SetSize(58, 58)
        border:AlignParentTopLeft(-10, -3)

        self._plate = Texture(self, nil, "BORDER")
        self._plate:SetColorTexture(0.1, 0.1, 0.1, 1)
        self._plate:FillParent()

        self._icon = Texture(self, nil, "ARTWORK")
        self._icon:FillParent()

        self._plus = Texture(self, nil, "ARTWORK")
        self._plus:SetDrawLayer("ARTWORK", 1)
        self._plus:SetTextureRegion(MUI.TEX_SKIN .. "bank\\bank-purchase-plus", 64, 64, 0, 0, 33, 33)
        self._plus:SetSize(30, 30)
        self._plus:CenterInParent()

        -- Dark while a search matches nothing in the bag.
        self._search = Texture(self, nil, "OVERLAY")
        self._search:SetColorTexture(0, 0, 0, 0.8)
        self._search:FillParent()
        self._search:Hide()

        self:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square"):SetBlendMode("ADD")

        self:RegisterForDrag("LeftButton")
        self:SetScript("OnDragStart", function()
            if not self._buying then PickupBagFromSlot(self._inventorySlot) end
        end)
        self:SetScript("OnReceiveDrag", function()
            if not self._buying then PutItemInBag(self._inventorySlot) end
        end)
        self.OnClick = function()
            if self._buying then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
                StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
            elseif IsModifiedClick("PICKUPITEM") then
                PickupBagFromSlot(self._inventorySlot)
            else
                PutItemInBag(self._inventorySlot)
            end
        end

        self.OnEnter = function()
            if not self._buying then grid:Highlight(self.container) end
        end
        self.OnLeave = function() grid:Highlight(nil) end
        self:SetTooltip("ANCHOR_RIGHT", function(tip) self:_BuildTooltip(tip) end)
    end;

    Update = function(self)
        local bought = GetNumBankSlots()
        local owned  = self.index <= bought
        self._buying = self.index == bought + 1
        self:SetVisible(owned or self._buying)
        self._plate:SetVisible(self._buying)
        self._plus:SetVisible(self._buying)
        self._icon:SetVisible(owned)

        local bag = owned and GetInventoryItemTexture("player", self._inventorySlot)
        if owned then
            self._icon:SetTexture(bag or EMPTY_BAG)
            self._icon:SetDesaturated(IsInventoryItemLocked(self._inventorySlot))
        end
        self._search:SetVisible(bag and C_Container.IsContainerFiltered(self.container))
    end;

    _BuildTooltip = function(self, tip)
        if self._buying then
            local cost = GetBankSlotCost((GetNumBankSlots()))
            tip:AddTitle(BANK_BAG_PURCHASE)
            if GetMoney() < cost then
                tip:AddLine(COSTS_LABEL .. " " .. C_CurrencyInfo.GetCoinTextureString(cost), 1, 0.1, 0.1)
            else
                tip:AddLine(COSTS_LABEL .. " " .. C_CurrencyInfo.GetCoinTextureString(cost), 1, 1, 1)
            end
        elseif not tip:SetInventoryItem("player", self._inventorySlot) then
            tip:AddTitle(BANK_BAG)
        end
    end;
}
