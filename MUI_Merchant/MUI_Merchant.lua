-- MUI_Merchant: the vendor window, Era's MerchantFrame, as retail's: the
-- metal frame with the merchant in its portrait ring and their name as the
-- title, retail's dark band under the goods with its repair and sell junk
-- icons, the buyback slot under its undo arrow, names and icon borders in
-- their item's quality colour, "Page 1 of 3", and the frame tabs under it.
--
-- Reskinned in place. The frame, its slots and its buttons stay Blizzard's,
-- and Blizzard's update functions keep filling them; what has to follow an
-- update follows from hooks on them. Era's slot, label plate and page button
-- art is retail's own, byte for byte. Retail's band and icons are on a sheet
-- the Era client doesn't have (Interface/MerchantFrame/Merchant), shipped
-- here.
--
-- "Sell junk" is retail's MerchantSellAllJunkButton. Era has no
-- C_MerchantFrame.SellAllJunkItems, so it sells slot by slot.

-- Retail's merchant sheet (512 x 256): x, y, w, h.
local SHEET = MUI.TEX_SKIN .. "merchant\\merchant"
local ART = {
    band      = { 1, 1, 332, 61 },      -- UI-Merchant-BotFrame
    sellJunk  = { 1, 64, 72, 72 },      -- SpellIcon-256x256-SellJunk
    repair    = { 75, 64, 72, 72 },     -- SpellIcon-256x256-Repair
    repairAll = { 1, 138, 72, 72 },     -- SpellIcon-256x256-RepairAll
}
-- Retail draws the band 2 wider than it is on the sheet.
local BAND_W, BAND_H = 334, 61

local BUTTON_SIZE = 36
-- Retail's repair row (its MerchantFrame_UpdateRepairButtons, without guild
-- repairs): repair-all's right edge 118 in from the left and 33 up, repair
-- an item 8 to its left, sell junk's right edge 80 right of repair-all's
-- left one; at a vendor who can't repair, sell junk's right edge 148 in
-- from the right.
local ROW_Y, REPAIR_RIGHT, REPAIR_GAP = 33, 118, 8
local JUNK_FROM_REPAIR, JUNK_RIGHT = 80, 148

-- Retail's buyback slot on the merchant page: 30 further right than Era's
-- and narrower, its name beside the icon with no label plate and no price,
-- the stack count smaller, and the undo arrow over the icon.
local BUYBACK_X, BUYBACK_Y, BUYBACK_W, BUYBACK_H = 30, 53, 115, 37
local BUYBACK_NAME_W, BUYBACK_NAME_H = 70, 35
local BUYBACK_COUNT_SCALE = 0.65
local UNDO_ATLAS, UNDO_SIZE = "common-icon-undo", 20
local BUYBACK_ICON = "Interface\\MerchantFrame\\UI-BuyBack-Icon"

-- Where retail's MerchantFrame_UpdateCurrencies puts the money: 1 higher
-- than Era's XML.
local MONEY_RIGHT, MONEY_Y = 4, 8

-- Retail chains its tabs 3 apart (PanelTemplates_AnchorTabs); Era's XML
-- tucks the second one 16 under the first.
local TAB_GAP = 3

local function Paint(texture, art)
    texture:SetTextureRegion(SHEET, 512, 256, art[1], art[2], art[3], art[4])
end

class "MerchantWindow" : extends "Frame" {

    __init = function(self)
        Frame.__init(self, MerchantFrame)
        self._events   = Frame()
        self._slots    = {}       -- by Blizzard's slot frame: its name, icon border and item
        self._pageText = FontString(MerchantPageText)

        self:_HideClassicArt()
        -- Retail's band under the goods, on Era's first strip of border:
        -- Blizzard shows it with the merchant page and hides it with the
        -- buyback one.
        local band = Texture(MerchantFrameBottomLeftBorder)
        Paint(band, ART.band)
        band:SetSize(BAND_W, BAND_H)
        self:_BuildRepairRow()
        self:_BuildBuyback()
        self:_BuildSlots()
        self:_BuildTabs()

        local money = Frame(MerchantMoneyFrame)
        money:ClearAllPoints()
        money:AlignParentBottomRight(MONEY_Y, MONEY_RIGHT)

        -- Blizzard's art and the frame levels come back with every show.
        -- The sell junk button looks at the bags again then too: at
        -- MERCHANT_SHOW a bag event can come before the frame shows, and the
        -- button kept its state from the last visit until the bags changed.
        MUI_PanelChrome:Apply(MerchantFrame)
        self:HookScript("OnShow", function()
            MUI_PanelChrome:Apply(MerchantFrame)
            self:_UpdateSellJunk()
        end)

        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function() self:_OnMerchantPage() end)
        hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function() self:_OnBuybackPage() end)
        hooksecurefunc("MerchantFrame_UpdateRepairButtons", function() self:_LayoutRepairRow() end)
        hooksecurefunc("MerchantFrameItem_UpdateQuality", function(slot, link) self:_ShowQuality(slot, link) end)
    end;

    -- ---- frame ---------------------------------------------------------

    -- What PanelChrome leaves of Era's art: the button bar's strip, the
    -- loose portrait and name, and two pieces Blizzard shows again with the
    -- merchant page: its second strip of border (the band is drawn on the
    -- first) and the "Repair" label retail dropped.
    _HideClassicArt = function(self)
        Texture(MerchantFrameBtnCornerLeft):Hide()
        Texture(MerchantFrameBtnCornerRight):Hide()
        Texture(MerchantFrameButtonBottomBorder):Hide()
        Texture(MerchantFramePortrait):Hide()
        FontString(MerchantNameText):Hide()
        Texture(MerchantFrameBottomRightBorder):SetAlpha(0)
        FontString(MerchantRepairText):SetAlpha(0)
    end;

    -- Retail's tabs. The first stays where Era's XML has it, as retail's
    -- does.
    _BuildTabs = function(self)
        local merchant = PanelTab(MerchantFrameTab1, "bottom")
        local buyback = PanelTab(MerchantFrameTab2, "bottom")
        buyback:ClearAllPoints()
        buyback:RightOf(merchant, TAB_GAP)
    end;

    -- After Blizzard fills the merchant page: the merchant in the ring and
    -- as the title, the page out of how many, and the buyback slot's arrow,
    -- grey with nothing to buy back.
    _OnMerchantPage = function(self)
        self:SetPortraitToUnit("npc")
        MUI_PanelChrome:SetTitle(MerchantFrame, UnitName("npc"))
        local pages = math.ceil(GetMerchantNumItems() / MERCHANT_ITEMS_PER_PAGE)
        self._pageText:SetText(MERCHANT_PAGE_NUMBER:format(MerchantFrame.page, pages))
        self._buybackMoney:Hide()
        self._undo:SetDesaturated(GetNumBuybackItems() == 0)
        self._sellJunk:Show()
    end;

    _OnBuybackPage = function(self)
        self:SetPortraitToAsset(BUYBACK_ICON)
        MUI_PanelChrome:SetTitle(MerchantFrame, MERCHANT_BUYBACK)
        self._sellJunk:Hide()
    end;

    -- ---- goods ---------------------------------------------------------

    -- Era's MerchantFrameItem_UpdateQuality is empty, but Blizzard still
    -- calls it for every slot it fills: the goods, the buyback rows and the
    -- buyback slot.
    _BuildSlots = function(self)
        for i = 1, BUYBACK_ITEMS_PER_PAGE do
            self:_AddSlot(_G["MerchantItem" .. i])
        end
        self:_AddSlot(MerchantBuyBackItem)
    end;

    _AddSlot = function(self, native)
        self._slots[native] = {
            name   = FontString(native.Name),
            border = Texture(native.ItemButton.IconBorder),
            link   = nil,
        }
    end;

    -- Retail's: the name in its item's quality colour, and the icon framed
    -- in it (common and better).
    _ShowQuality = function(self, native, link)
        local slot = self._slots[native]
        slot.link = link
        local quality = link and C_Item.GetItemQualityByID(link)
        local color = quality and ITEM_QUALITY_COLORS[quality] or NORMAL_FONT_COLOR
        slot.name:SetTextColor(color.r, color.g, color.b)
        local edge = quality and BAG_ITEM_QUALITY_COLORS[quality]
        if edge then
            slot.border:SetVertexColor(edge.r, edge.g, edge.b)
        end
        slot.border:SetVisible(edge ~= nil)
        -- An item the client has yet to load has no quality yet.
        if link and not quality then
            self._events:RegisterEventHandler("GET_ITEM_INFO_RECEIVED", function() self:_RetryQuality() end)
        end
    end;

    _RetryQuality = function(self)
        self._events:UnregisterEventHandler("GET_ITEM_INFO_RECEIVED")
        if not self:IsVisible() then return end
        for native, slot in pairs(self._slots) do
            if slot.link then self:_ShowQuality(native, slot.link) end
        end
    end;

    -- ---- buyback slot --------------------------------------------------

    _BuildBuyback = function(self)
        local slot = Frame(MerchantBuyBackItem)
        slot:SetSize(BUYBACK_W, BUYBACK_H)
        slot:ClearAllPoints()
        slot:SetPoint("TOPLEFT", MerchantItem10, "BOTTOMLEFT", BUYBACK_X, -BUYBACK_Y)

        Texture(MerchantBuyBackItemNameFrame):Hide()
        local name = FontString(MerchantBuyBackItemName)
        name:SetSize(BUYBACK_NAME_W, BUYBACK_NAME_H)
        name:ClearAllPoints()
        name:RightOf(Texture(MerchantBuyBackItemSlotTexture), -5, 2)
        -- Blizzard shows the price again with every update.
        self._buybackMoney = Frame(MerchantBuyBackItemMoneyFrame)

        local button = Button(MerchantBuyBackItemItemButton)
        FontString(MerchantBuyBackItemItemButtonCount):SetScale(BUYBACK_COUNT_SCALE)
        local undo = Frame("Frame", button)
        undo:FillParent()
        self._undo = Texture(undo, nil, "ARTWORK")
        self._undo:SetBlizzardAtlas(UNDO_ATLAS)
        self._undo:SetSize(UNDO_SIZE, UNDO_SIZE)
        self._undo:CenterInParent(0, -1)
    end;

    -- ---- repair row ----------------------------------------------------

    -- Retail's icons on Era's repair buttons, each on an empty slot as the
    -- sell junk button. Blizzard greys the repair-all icon when there is
    -- nothing to repair.
    _BuildRepairRow = function(self)
        self._repairAll  = Button(MerchantRepairAllButton)
        self._repairItem = Button(MerchantRepairItemButton)
        self:_SkinSlotButton(self._repairAll, Texture(MerchantRepairAllIcon), ART.repairAll)
        -- The repair-an-item icon has no name: the button's one BORDER texture.
        for _, region in ipairs(self._repairItem:GetRegions()) do
            if region:GetDrawLayer() == "BORDER" then
                self:_SkinSlotButton(self._repairItem, region, ART.repair)
            end
        end
        self:_BuildSellJunk()
    end;

    _SkinSlotButton = function(self, button, icon, art)
        local slot = Texture(button, nil, "BACKGROUND")
        slot:SetTexture("Interface\\Buttons\\UI-EmptySlot")
        slot:SetSize(64, 64)
        slot:AlignParentTopLeft(-14, -13)
        Paint(icon, art)
    end;

    -- Blizzard lays the row out again on every merchant page update, and
    -- shows the repair buttons at a vendor who repairs.
    _LayoutRepairRow = function(self)
        self._sellJunk:ClearAllPoints()
        if not self._repairAll:IsShown() then
            self._sellJunk:AlignParentBottomRight(ROW_Y, JUNK_RIGHT)
            return
        end
        self._repairAll:ClearAllPoints()
        self._repairAll:AlignParentBottomLeft(ROW_Y, REPAIR_RIGHT - BUTTON_SIZE)
        self._repairItem:ClearAllPoints()
        self._repairItem:LeftOf(self._repairAll, REPAIR_GAP)
        self._sellJunk:LeftOf(self._repairAll, -JUNK_FROM_REPAIR)
    end;

    -- ---- sell junk -----------------------------------------------------

    _BuildSellJunk = function(self)
        local btn = Button(self, "MUI_MerchantSellJunkButton")
        btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square"):SetBlendMode("ADD")
        self._sellJunkIcon = Texture(btn, nil, "BORDER")
        self._sellJunkIcon:FillParent()
        self:_SkinSlotButton(btn, self._sellJunkIcon, ART.sellJunk)

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
        btn:RegisterEventHandler("BAG_UPDATE_DELAYED", function() self:_UpdateSellJunk() end)
        -- Items the client hadn't loaded yet report no quality; re-check as
        -- their data arrives.
        btn:RegisterEventHandler("GET_ITEM_INFO_RECEIVED", function() self:_UpdateSellJunk() end)
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
        if not self:IsShown() then return end
        local hasJunk = #self:_CollectJunk() > 0
        self._sellJunk:SetEnabled(hasJunk)
        self._sellJunkIcon:SetDesaturated(not hasJunk)
    end;
}

object "ModuleMerchant" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Merchant")
    end;

    OnEnable = function(self)
        self.window = MerchantWindow()
    end;
}
