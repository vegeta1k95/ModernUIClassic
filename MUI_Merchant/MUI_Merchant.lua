-- MUI_Merchant: vendor window additions.
--
-- "Sell junk": a button in the repair row that sells every grey item in the
-- bags, laid out like retail's MerchantSellAllJunkButton. Retail shifted the
-- repair buttons left (repair-all's right edge at 118, repair-item 8 px to its
-- left, no "Repair" label) and put the junk button at 126..162, clear of the
-- buyback slot, which on Era starts around 176. Era has no
-- C_MerchantFrame.SellAllJunkItems, so it sells slot by slot.

local BUTTON_SIZE = 36
local JUNK_ATLAS  = "SpellIcon-256x256-SellJunk"
-- Used when this client doesn't ship retail's atlas.
local JUNK_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_Coin_02"

object "ModuleMerchant" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Merchant")
    end;

    OnEnable = function(self)
        self._merchant   = Frame(MerchantFrame)
        self._repairAll  = Frame(MerchantRepairAllButton)
        self._repairItem = Frame(MerchantRepairItemButton)
        self._repairText = FontString(MerchantRepairText)
        self:_CreateSellJunkButton()

        -- Blizzard re-anchors the repair buttons on every merchant update.
        hooksecurefunc("MerchantFrame_UpdateRepairButtons", function() self:_LayoutRepairRow() end)
        -- Re-check when the window itself shows: at MERCHANT_SHOW our handler
        -- can run before Blizzard's shows the frame, and the button then kept
        -- its greyed state from the last visit until the bags changed.
        self._merchant:HookScript("OnShow", function() self:_UpdateSellJunk() end)
        self._sellJunk:RegisterEventHandler("BAG_UPDATE_DELAYED", function() self:_UpdateSellJunk() end)
        -- Items the client hadn't loaded yet report no quality; re-check as
        -- their data arrives.
        self._sellJunk:RegisterEventHandler("GET_ITEM_INFO_RECEIVED", function() self:_UpdateSellJunk() end)
    end;

    -- Retail's repair row. Only while Blizzard shows the repair buttons (repair
    -- vendors, merchant tab); the junk button has its own fixed slot.
    _LayoutRepairRow = function(self)
        if not self._repairAll:IsShown() then return end
        self._repairAll:ClearAllPoints()
        self._repairAll:AlignParentBottomLeft(33, 118 - BUTTON_SIZE)
        self._repairItem:ClearAllPoints()
        self._repairItem:LeftOf(self._repairAll, 8)
        self._repairText:Hide()
    end;

    -- ---- sell junk ------------------------------------------------------

    _CreateSellJunkButton = function(self)
        local btn = Button(self._merchant, "MUI_MerchantSellJunkButton")
        btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        btn:AlignParentBottomLeft(33, 162 - BUTTON_SIZE)

        -- Retail's art: empty-slot frame behind the icon, quickslot press,
        -- square highlight.
        local slot = Texture(btn, nil, "BACKGROUND")
        slot:SetTexture("Interface\\Buttons\\UI-EmptySlot")
        slot:SetSize(64, 64)
        slot:AlignParentTopLeft(-14, -13)

        self._sellJunkIcon = Texture(btn, nil, "BORDER")
        if not self._sellJunkIcon:SetBlizzardAtlas(JUNK_ATLAS) then
            self._sellJunkIcon:SetTexture(JUNK_ICON_FALLBACK)
        end
        self._sellJunkIcon:FillParent()
        btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square"):SetBlendMode("ADD")

        btn:SetTooltip("ANCHOR_RIGHT", function(tip)
            local junk, value = self:_CollectJunk()
            tip:AddTitle("Sell Junk")
            if #junk == 0 then
                tip:AddLine("No junk in your bags", 0.8, 0.8, 0.8)
            else
                tip:AddLine(#junk .. (#junk == 1 and " item" or " items"), 1, 1, 1)
                if value > 0 then
                    tip:AddLine(C_CurrencyInfo.GetCoinTextureString(value), 1, 1, 1)
                end
            end
        end)
        btn.OnClick = function() self:_SellJunk() end
        self._sellJunk = btn
    end;

    -- Grey items with a vendor price: list of {bag, slot} and their total value.
    _CollectJunk = function(self)
        local junk, value = {}, 0
        for bag = 0, NUM_BAG_SLOTS do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                local quality = info and (info.quality or C_Item.GetItemQualityByID(info.itemID))
                if quality == Enum.ItemQuality.Poor and not info.hasNoValue then
                    junk[#junk + 1] = { bag, slot }
                    local price = select(11, C_Item.GetItemInfo(info.itemID))
                    value = value + (price or 0) * (info.stackCount or 1)
                end
            end
        end
        return junk, value
    end;

    _SellJunk = function(self)
        for _, s in ipairs(self:_CollectJunk()) do
            local info = C_Container.GetContainerItemInfo(s[1], s[2])
            if info and not info.isLocked then
                C_Container.UseContainerItem(s[1], s[2])
            end
        end
    end;

    _UpdateSellJunk = function(self)
        if not self._merchant:IsShown() then return end
        local hasJunk = #self:_CollectJunk() > 0
        self._sellJunk:SetEnabled(hasJunk)
        self._sellJunkIcon:SetDesaturated(not hasJunk)
    end;
}
