-- MUI_AuctionHouseSell: the Sell tab (retail's ItemSellFrame and
-- ItemSellList) on Era's posting API.
--
-- Left, the form: the item slot, quantity, price per item, duration, the
-- deposit and total, Create Auction. "Buyout Only" (the default) posts at
-- a fixed price; unchecked, a starting bid row appears and the buyout
-- becomes optional. Right, the slotted item's auctions cheapest first:
-- clicking one copies its unit price into the form.
--
-- The sell slot is the client's, not ours: ClickAuctionSellItemButton moves
-- the cursor's item in or out, GetAuctionSellItemInfo reads it, and
-- NEW_AUCTION_UPDATE says it changed. The window keeps the client's
-- "auctions tab showing" flag up, so right-clicking an item in the bags
-- drops it here as on the native Auctions tab.
--
-- One auction of `quantity` items is posted, through the native Create
-- Auction button's own StartPost: when the client wants the post confirmed
-- (AUCTION_HOUSE_POST_WARNING) the native frame's dialog answers through
-- that button, and the pending post has to be the one it holds.

local Style = MUI_AuctionHouseStyle
local S     = Style.S

local DURATIONS = { AUCTION_DURATION_ONE, AUCTION_DURATION_TWO, AUCTION_DURATION_THREE }

local ROW_TOP, ROW_STEP, ROW_H = 96, 45, 30
local LABEL_W = 93

local MARKET_COLUMNS = {
    { key = "unit",   title = "Unit Price", width = 110, justify = "RIGHT", text = function(d) return d.unitText end },
    { key = "buyout", title = "Buyout",     width = 110, justify = "RIGHT", text = function(d) return d.buyoutText end },
    { key = "count",  title = "Qty",        width = 44,  justify = "RIGHT", text = function(d) return d.count end },
    { key = "owner",  title = "Seller",     fill = true, justify = "LEFT",  text = function(d) return d.owner or "" end },
}

local function Coins(copper)
    return C_CurrencyInfo.GetCoinTextureString(copper, 11)
end

class "AuctionHouseSell" : extends "Frame" {
    __init = function(self, parent, owner)
        Frame.__init(self, "Frame", parent)
        self:SetSize(791 * S, 442 * S)
        self._owner      = owner
        self._buyoutOnly = true
        self._duration   = MUI_DB.data.auctionHouse.sellDuration
        self._stackCount = 0      -- the slotted item's stack limit
        self._totalCount = 0      -- how many of it are in the bags
        self._startPrice, self._buyoutPrice = 0, 0
        self._marketName = nil    -- the item the market list was asked for
        self._market     = {}
        self._sortKey    = "unit"
        self._sortDesc   = false

        self:_BuildForm()
        self:_BuildMarket()
        self:_LayoutRows()

        self:RegisterEventHandler("NEW_AUCTION_UPDATE", function() self:_OnSlotChanged() end)
        self:UpdateItem()
    end;

    -- ---- the form ------------------------------------------------------

    _BuildForm = function(self)
        local form = Frame("Frame", self)
        form:SetSize(363 * S, 442 * S)
        form:AlignParentTopLeft()
        self._form = form
        local bg = Style:Background(form, "SellLeft", "ARTWORK")
        bg:SetSize(357 * S, 437 * S)
        bg:AlignParentTopLeft(3 * S, 3 * S)
        local inset = Style:Inset(form)

        self:_BuildPlate(form, inset)
        self:_BuildSlot(form)

        self._quantityRow = self:_Row("Quantity")
        self._quantity = AuctionHouseInput(self._quantityRow, 134)
        self._quantity:SetNumeric(true)
        self._quantity:SetMaxLetters(4)
        self._quantity:RightOf(self._quantityRow.label, 18 * S)
        self._quantity.OnTextChanged = function() self:_Validate() end
        local max = ButtonGold(self._quantityRow, nil, "Max")
        max:SetSize(50 * S, 20 * S)
        max.label:SetFontSize(10)
        max:RightOf(self._quantity, 10 * S)
        max.OnClick = function()
            self._quantity:SetNumber(math.min(self._stackCount, self._totalCount))
        end

        self._buyoutRow = self:_Row("Buyout")
        self._buyout = AuctionHouseMoneyInput(self._buyoutRow)
        self._buyout:RightOf(self._buyoutRow.label, 18 * S)
        self._buyout.OnChanged = function() self:_Validate() end

        self._startBidRow = self:_Row("Starting Bid")
        self._startBid = AuctionHouseMoneyInput(self._startBidRow)
        self._startBid:RightOf(self._startBidRow.label, 18 * S)
        self._startBid.OnChanged = function() self:_Validate() end

        self._durationRow = self:_Row("Duration")
        self._durationButton = DropdownSimple(self._durationRow)
        self._durationButton:SetSize(120 * S, 22)
        self._durationButton:RightOf(self._durationRow.label, 18 * S)
        self._durationButton:SetText(DURATIONS[self._duration])
        self._durationMenu = DropdownMenu(self._durationButton, nil, self._durationButton)
        self._durationMenu:SetMenuWidth(130)
        local items = {}
        for index, text in ipairs(DURATIONS) do
            items[index] = { label = text, OnClick = function() self:_SetDuration(index) end }
        end
        self._durationMenu:SetItems(items)
        self._durationButton.OnClick = function() self._durationMenu:Toggle() end

        self._depositRow = self:_Row("Deposit")
        self._deposit = Style:Label(self._depositRow, 10.5, 1, 1, 1)
        self._deposit:RightOf(self._depositRow.label, 18 * S)

        self._totalRow = self:_Row("Total Price")
        self._total = Style:Label(self._totalRow, 10.5, 1, 1, 1)
        self._total:RightOf(self._totalRow.label, 18 * S)

        self._post = ButtonGold(form, nil, "Create Auction")
        self._post:SetSize(160 * S, 22 * S)
        self._post.label:SetFontSize(10.5)
        self._post:SetClickSound(SOUNDKIT.LOOT_WINDOW_COIN_SOUND)
        self._post.OnClick = function() self:_Post() end

        self._mode = CheckBoxThin(form, nil, "Buyout Only")
        self._mode:SetSize(110, 13)
        self._mode:SetBoxSize(11, 11)
        self._mode.label:SetFontSize(10.5)
        self._mode.label:SetTextColor(1, 0.82, 0, 1)
        self._mode:AlignParentBottomLeft(12 * S, 12 * S)
        self._mode:SetChecked(true)
        self._mode.OnChanged = function(_, checked)
            self._buyoutOnly = checked
            self:_LayoutRows()
            self:_Validate()
        end
        self._mode:SetTooltip("ANCHOR_RIGHT", function(tip)
            tip:AddLine("Sell at a fixed price. Uncheck to set a starting bid, with or without a buyout.", 1, 0.82, 0, true)
        end)
    end;

    -- The "Create Auction" plate on the form's top edge, above its border.
    _BuildPlate = function(self, form, inset)
        local plate = Frame("Frame", form)
        plate:PutInfront(inset, 1)
        local label = Style:Label(plate, 9.5, 1, 0.82, 0)
        label:SetText("Create Auction")
        label:CenterInParent()
        plate:SetSize(label:GetStringWidth() + 42 * S, 23 * S)
        plate:AlignParentTopLeft(-20 * S, 42 * S)
        local left = Style:Piece(plate, "ARTWORK", "SellTabLeft", 9, 23)
        left:AlignParentLeft()
        local right = Style:Piece(plate, "ARTWORK", "SellTabRight", 9, 23)
        right:AlignParentRight()
        local middle = Style:Piece(plate, "ARTWORK", "SellTabMiddle", 9, 23)
        middle:FillBetweenH(left, right)
    end;

    -- Retail's item display: the header plate with the slot at its left and
    -- the item's name beside it. Slot and plate both take the item.
    _BuildSlot = function(self, form)
        local display = Button(form)
        display:SetClickSound(nil)
        display:SetSize(342 * S, 72 * S)
        display:AlignParentTop(14 * S)
        local art = Style:Piece(display, "BORDER", "ItemHeaderFrame", 342, 72)
        art:FillParent()

        local slot = Button(display)
        slot:SetClickSound(nil)
        slot:SetSize(54 * S, 54 * S)
        slot:AlignParentLeft(12 * S)
        local empty = Style:Piece(slot, "BACKGROUND", "ItemIconEmpty", 54, 54)
        empty:FillParent()
        self._icon = Texture(slot, nil, "ARTWORK")
        self._icon:FillParent(2 * S)
        self._icon:Hide()

        self._name = Style:Label(display, 13, 1, 1, 1)
        self._name:SetJustifyH("LEFT")
        self._name:SetWidth(250 * S)
        self._name:RightOf(slot, 12 * S)

        for _, button in ipairs({ display, slot }) do
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            button:RegisterForDrag("LeftButton")
            button.OnClick = function(_, mouseButton) self:_ClickSlot(mouseButton) end
            button:SetScript("OnReceiveDrag", function() self:_ClickSlot("LeftButton") end)
            button:SetScript("OnDragStart", function() self:_ClickSlot("LeftButton") end)
        end
        slot:SetTooltip("ANCHOR_RIGHT", function(tip)
            if GetAuctionSellItemInfo() then
                tip:SetAuctionSellItem()
            else
                tip:AddTitle("Auction Item")
                tip:AddLine("Drag an item here to auction it, or right-click it in your bags.", 1, 1, 1, true)
            end
        end)
    end;

    -- A form row: its label right-aligned in the first 93, the control after.
    _Row = function(self, text)
        local row = Frame("Frame", self._form)
        row:SetSize(330 * S, ROW_H * S)
        row.label = Style:Label(row, 10.5, 1, 0.82, 0)
        row.label:SetJustifyH("RIGHT")
        row.label:SetWidth(LABEL_W * S)
        row.label:AlignParentLeft()
        row.label:SetText(text)
        return row
    end;

    -- Stack the rows in use under the item display, the button under them.
    _LayoutRows = function(self)
        self._startBidRow:SetVisible(not self._buyoutOnly)
        local rows = { self._quantityRow, self._buyoutRow }
        if not self._buyoutOnly then rows[#rows + 1] = self._startBidRow end
        rows[#rows + 1] = self._durationRow
        rows[#rows + 1] = self._depositRow
        rows[#rows + 1] = self._totalRow
        for i, row in ipairs(rows) do
            row:ClearAllPoints()
            row:AlignParentTopLeft((ROW_TOP + (i - 1) * ROW_STEP) * S, 10.5 * S)
        end
        self._post:ClearAllPoints()
        self._post:AlignParentTop((ROW_TOP + (#rows - 1) * ROW_STEP + ROW_H + 16) * S)
    end;

    _SetDuration = function(self, index)
        self._duration = index
        MUI_DB.data.auctionHouse.sellDuration = index
        self._durationButton:SetText(DURATIONS[index])
        self:_Validate()
    end;

    -- ---- the slot ------------------------------------------------------

    -- Left: move the cursor's item in, or the slotted item onto the cursor.
    -- Right: send the slotted item back to the bags.
    _ClickSlot = function(self, mouseButton)
        if mouseButton == "RightButton" then
            if GetAuctionSellItemInfo() then
                ClickAuctionSellItemButton(AuctionsItemButton, "LeftButton")
                ClearCursor()
            end
        else
            ClickAuctionSellItemButton(AuctionsItemButton, "LeftButton")
        end
    end;

    -- An item landing in the slot brings the Sell tab forward, whichever
    -- tab was open (retail's SetPostItem).
    _OnSlotChanged = function(self)
        if not self._owner:IsShown() then return end
        if GetAuctionSellItemInfo() and self._owner.mode ~= "ItemSell" then
            self._owner:SetDisplayMode("ItemSell")
        else
            self:UpdateItem()
        end
    end;

    -- Read the slot into the form and ask for the item's market.
    UpdateItem = function(self)
        local name, icon, count, quality, _, _, _, stackCount, totalCount = GetAuctionSellItemInfo()
        self._icon:SetTexture(icon)
        self._icon:SetVisible(name ~= nil)
        self._name:SetText(name and Style:QualityText(name, quality) or "")
        self._stackCount = stackCount or 0
        self._totalCount = totalCount or 0
        if name then self._quantity:SetNumber(count) end
        self:_Validate()
        self:_QueryMarket(name)
    end;

    -- ---- posting -------------------------------------------------------

    -- The auction the form describes, its deposit and total, and whether it
    -- can be posted (Era's AuctionsFrameAuctions_ValidateAuction).
    _Validate = function(self)
        -- an input reporting its text while the form is still being built
        if not self._mode then return end
        local name = GetAuctionSellItemInfo()
        local quantity = self._quantity:GetNumber()
        local buyout = self._buyout:GetCopper() * quantity
        local start = buyout
        if not self._buyoutOnly then start = self._startBid:GetCopper() * quantity end
        self._startPrice, self._buyoutPrice = start, buyout

        local deposit = name and GetAuctionDeposit(self._duration, start, buyout, quantity, 1) or 0
        self._deposit:SetText(Coins(deposit))
        self._total:SetText(Coins(buyout > 0 and buyout or start))

        self._post:SetEnabled(name ~= nil
            and quantity >= 1 and quantity <= self._stackCount and quantity <= self._totalCount
            and start >= 1 and start <= MAXIMUM_BID_PRICE and buyout <= MAXIMUM_BID_PRICE
            and (buyout == 0 or buyout >= start))
    end;

    _Post = function(self)
        AuctionsCreateAuctionButton:StartPost(self._startPrice, self._buyoutPrice, self._duration,
            self._quantity:GetNumber(), 1, false)
    end;

    -- ---- the market ----------------------------------------------------

    _BuildMarket = function(self)
        self.list = AuctionHouseList(self, MARKET_COLUMNS, {
            width = 427, height = 442, background = "SellRight", refresh = { x = -4, y = 30 },
        })
        self.list:AlignParentTopLeft(0, 364 * S)
        self.list.OnSort = function(_, key)
            if self._sortKey == key then
                self._sortDesc = not self._sortDesc
            else
                self._sortKey, self._sortDesc = key, false
            end
            self:_PublishMarket(true)
        end
        -- the price input is per item
        self.list.OnRowClick = function(_, row)
            if row.unit then self._buyout:SetCopper(row.unit) end
        end
        self.list.OnRefresh = function()
            self._marketName = nil
            self:_QueryMarket((GetAuctionSellItemInfo()))
        end
    end;

    -- The market of the item named `name` (nil clears the list). Asked once
    -- per item: the slot reports itself more than once.
    _QueryMarket = function(self, name)
        if name == self._marketName then return end
        self._marketName = name
        self._market = {}
        self.list:SetData({})
        self.list:SetTotalText("")
        if not name then
            self.list:SetLoading(false)
            self.list:SetEmptyText("")
            return
        end
        self.list:SetLoading(true, SEARCHING_FOR_ITEMS)
        self._owner.scan:Start({
            text  = name,
            exact = true,
            sort  = "unitprice",
            OnPage = function(rows, _, total) self:_SetMarket(name, rows, total) end,
            OnDone = function()
                self.list:SetLoading(false)
                self.list:SetEmptyText(BROWSE_NO_RESULTS)
            end,
            OnRefresh = function(rows, total) self:_SetMarket(name, rows, total) end,
        })
    end;

    _SetMarket = function(self, name, rows, total)
        -- the slot has moved on since this was asked for
        if name ~= self._marketName then return end
        local market = {}
        for _, row in ipairs(rows) do
            if row.name == name and row.buyout > 0 then
                row.unit       = math.ceil(row.buyout / row.count)
                row.unitText   = Style:Money(row.unit)
                row.buyoutText = Style:Money(row.buyout)
                market[#market + 1] = row
            end
        end
        self._market = market
        self.list:SetLoading(false)
        self.list:SetTotalText(total > #rows and (#rows .. " / " .. total) or tostring(#rows))
        self:_PublishMarket(true)
    end;

    _PublishMarket = function(self, keepScroll)
        local key, desc = self._sortKey, self._sortDesc
        table.sort(self._market, function(a, b)
            local av, bv
            if key == "buyout" then
                av, bv = a.buyout, b.buyout
            elseif key == "count" then
                av, bv = a.count, b.count
            elseif key == "owner" then
                av, bv = string.lower(a.owner or ""), string.lower(b.owner or "")
            else
                av, bv = a.unit, b.unit
            end
            if av == bv then return a.index < b.index end
            if desc then return av > bv end
            return av < bv
        end)
        self.list:SetData(self._market, keepScroll)
        self.list:SetSort(key, desc)
    end;

    -- The tab came forward: the listing buffer may have been used by a
    -- search since, so the slotted item's market is asked for again.
    OnDisplayed = function(self)
        self._marketName = nil
        self:UpdateItem()
    end;

    ClosePopups = function(self)
        self._durationMenu:Close()
        self._quantity:ClearFocus()
        self._buyout:ClearFocus()
        self._startBid:ClearFocus()
    end;
}
