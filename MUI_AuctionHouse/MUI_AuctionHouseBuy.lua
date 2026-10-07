-- MUI_AuctionHouseBuy: one item's listings, opened from a browse row
-- (retail's ItemBuyFrame): the item card, its auctions cheapest first, a
-- bid amount with Bid and Buyout acting on the selected one.
--
-- The item is asked for again by its exact name, sorted by unit price, so
-- the page in the buffer is this item's cheapest fifty auctions and each
-- row's index is what PlaceAuctionBid wants. The buffer shifts whenever an
-- auction on the page is bought or bid on; the scan hands the page back
-- (OnRefresh) and the rows are rebuilt, and nothing is bid on without
-- checking that the auction at that index is still the one selected.

local Style = MUI_AuctionHouseStyle
local S     = Style.S

local POPUP_BUYOUT = "MUI_AUCTION_BUYOUT"
local POPUP_BID    = "MUI_AUCTION_BID"

-- Era's own confirmations (BUYOUT_AUCTION / BID_AUCTION), acting on our
-- selection instead of the native frame's.
StaticPopupDialogs[POPUP_BUYOUT] = {
    text = BUYOUT_AUCTION_CONFIRMATION,
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(dialog, data) data.panel:Place(data.row, data.amount) end,
    OnShow = function(dialog, data) MoneyFrame_Update(dialog.MoneyFrame, data.amount) end,
    hasMoneyFrame = 1,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1,
}
StaticPopupDialogs[POPUP_BID] = {
    text = BID_AUCTION_CONFIRMATION,
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(dialog, data) data.panel:Place(data.row, data.amount) end,
    OnShow = function(dialog, data) MoneyFrame_Update(dialog.MoneyFrame, data.amount) end,
    hasMoneyFrame = 1,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1,
}

local COLUMNS = {
    { key = "unit",   title = "Unit Price", width = 105, justify = "RIGHT", text = function(d) return d.unitText end },
    { key = "buyout", title = "Buyout",     width = 105, justify = "RIGHT", text = function(d) return d.buyoutText end },
    { key = "bid",    title = "Bid",        width = 105, justify = "RIGHT", text = function(d) return d.bidText end },
    { key = "count",  title = "Qty",        width = 44,  justify = "RIGHT", text = function(d) return d.count end },
    { key = "owner",  title = "Seller",     fill = true, justify = "LEFT",  text = function(d) return d.owner or "" end },
    { key = "time",   title = "Time Left",  width = 80,  justify = "RIGHT", text = function(d) return d.timeText end },
}

class "AuctionHouseBuy" : extends "Frame" {
    __init = function(self, parent, owner)
        Frame.__init(self, "Frame", parent)
        self:SetSize(627 * S, 464 * S)
        self._owner    = owner
        self._item     = nil     -- itemId, name, quality, icon, link
        self._listings = {}
        self._selected = nil
        self._sortKey  = "unit"
        self._sortDesc = false

        self._back = ButtonGold(self, nil, "Back")
        self._back:SetSize(110 * S, 22 * S)
        self._back.label:SetFontSize(10.5)
        self._back:AlignParentTopLeft(9 * S, 11 * S)
        self._back.OnClick = function() owner:SetDisplayMode("Buy") end

        self:_BuildItemCard()
        self:_BuildActions()
        self:_BuildList()

        self:RegisterEventHandler("PLAYER_MONEY", function() self:_UpdateActions() end)
        self:SetScript("OnHide", function() self:HidePopups() end)
        self:_UpdateActions()
    end;

    -- Retail's ItemDisplay: the item in its quality ring, its name beside it.
    _BuildItemCard = function(self)
        local card = Frame("Frame", self)
        card:SetSize(626 * S, 86 * S)
        card:AlignParentTopLeft(41 * S, 0)
        local bg = Style:Background(card, "BuyHeader")
        bg:SetSize(617 * S, 81 * S)
        bg:AlignParentTopLeft(2 * S, 3 * S)
        Style:Inset(card)

        local button = Button(card)
        button:SetClickSound(nil)
        button:SetSize(54 * S, 54 * S)
        button:AlignParentLeft(22 * S, -2 * S)
        self._icon = Texture(button, nil, "ARTWORK")
        self._icon:FillParent(5 * S)
        self._ring = Style:Piece(button, "OVERLAY", "ItemIconBorderWhite", 54, 54)
        self._ring:CenterInParent()
        button.OnClick = function()
            local item = self._item
            if item and item.link and IsModifiedClick() then HandleModifiedItemClick(item.link) end
        end
        button:SetTooltip("ANCHOR_RIGHT", function(tip)
            if self._item and self._item.link then tip:SetHyperlink(self._item.link) end
        end)

        self._name = Style:Label(card, 13, 1, 1, 1)
        self._name:SetJustifyH("LEFT")
        self._name:SetWordWrap(false)
        self._name:SetWidth(520 * S)
        self._name:RightOf(button, 12 * S)
    end;

    -- Retail's BidFrame and BuyoutFrame along the bottom: the bid amount,
    -- Bid, Buyout.
    _BuildActions = function(self)
        local bottom = (8 + (AuctionHouseInput.HEIGHT - 22) / 2) * S

        self._buyout = ButtonGold(self, nil, "Buyout")
        self._buyout:SetSize(110 * S, 22 * S)
        self._buyout.label:SetFontSize(10.5)
        self._buyout:AlignParentBottomRight(bottom, 8 * S)
        self._buyout.OnClick = function()
            local row = self._selected
            if row then StaticPopup_Show(POPUP_BUYOUT, nil, nil, { panel = self, row = row, amount = row.buyout }) end
        end

        self._bid = ButtonGold(self, nil, "Bid")
        self._bid:SetSize(110 * S, 22 * S)
        self._bid.label:SetFontSize(10.5)
        self._bid:LeftOf(self._buyout, 6 * S)
        self._bid.OnClick = function()
            local row = self._selected
            if row then
                StaticPopup_Show(POPUP_BID, nil, nil, { panel = self, row = row, amount = self._bidAmount:GetCopper() })
            end
        end

        self._bidAmount = AuctionHouseMoneyInput(self)
        self._bidAmount:LeftOf(self._bid, 10 * S)
        self._bidAmount.OnChanged = function() self:_UpdateActions() end
    end;

    _BuildList = function(self)
        self.list = AuctionHouseList(self, COLUMNS, {
            width = 619, height = 276, background = "BuyMarket", refresh = { x = -4, y = 132 },
        })
        self.list:AlignParentTopLeft(141 * S, 0)
        self.list.OnSort = function(_, key)
            if self._sortKey == key then
                self._sortDesc = not self._sortDesc
            else
                self._sortKey, self._sortDesc = key, false
            end
            self:_Publish(true)
        end
        self.list.OnRowClick = function(_, row) self:_Select(row) end
        self.list.OnRefresh = function() if self._item then self:Query() end end
    end;

    -- ---- data ----------------------------------------------------------

    -- Show `item` (a browse row) and ask for its auctions.
    Open = function(self, item)
        self._item = { itemId = item.itemId, name = item.name, quality = item.quality, icon = item.icon, link = item.link }
        self._icon:SetPortrait(item.icon)
        Style:SetPiece(self._ring, Style:QualityRing(item.quality))
        self._name:SetText(Style:QualityText(item.name, item.quality))
        self:Query()
    end;

    Query = function(self)
        self:_Select(nil)
        self._listings = {}
        self.list:SetData({})
        self.list:SetTotalText("")
        self.list:SetLoading(true, SEARCHING_FOR_ITEMS)
        self._owner.scan:Start({
            text  = self._item.name,
            exact = true,
            sort  = "unitprice",
            OnPage = function(rows, _, total) self:_SetListings(rows, total) end,
            OnDone = function()
                self.list:SetLoading(false)
                self.list:SetEmptyText(BROWSE_NO_RESULTS)
            end,
            OnRefresh = function(rows, total) self:_SetListings(rows, total) end,
        })
    end;

    -- The page's rows as listings: the price to show, the least next bid
    -- (Era's rule: the starting bid while there is none, else the bid plus
    -- the increment), the unit price.
    _SetListings = function(self, rows, total)
        local previous = self._selected
        local player = UnitName("player")
        local listings = {}
        for _, row in ipairs(rows) do
            if row.name == self._item.name then
                local hasBid = row.bidAmount > 0
                row.bid         = hasBid and row.bidAmount or row.minBid
                row.requiredBid = hasBid and (row.bidAmount + row.minIncrement) or row.minBid
                row.unit        = row.buyout > 0 and math.ceil(row.buyout / row.count) or nil
                row.own         = row.owner == player
                row.unitText    = Style:Money(row.unit, "-")
                row.buyoutText  = Style:Money(row.buyout, "-")
                row.bidText     = Style:Money(row.bid, "-")
                -- your own standing bid in green
                if row.highBidder then row.bidText = "|cff40ff40" .. row.bidText .. "|r" end
                row.timeText    = Style:TimeLeft(row.timeLeft)
                listings[#listings + 1] = row
            end
        end
        self._listings = listings
        self.list:SetLoading(false)
        self.list:SetTotalText(total > #listings and (#listings .. " / " .. total) or tostring(#listings))

        -- keep the selection on the same auction when it is still there
        local selected
        if previous then
            for _, row in ipairs(listings) do
                if row.owner == previous.owner and row.count == previous.count and row.buyout == previous.buyout
                        and row.minBid == previous.minBid and row.bidAmount == previous.bidAmount then
                    selected = row
                    break
                end
            end
        end
        self._selected = selected
        self:_Publish(true)
        if previous and not selected then self:HidePopups() end
        self:_UpdateActions()
    end;

    _Publish = function(self, keepScroll)
        local key, desc = self._sortKey, self._sortDesc
        table.sort(self._listings, function(a, b)
            local av, bv
            if key == "buyout" then
                av, bv = a.buyout > 0 and a.buyout or math.huge, b.buyout > 0 and b.buyout or math.huge
            elseif key == "bid" then
                av, bv = a.bid, b.bid
            elseif key == "count" then
                av, bv = a.count, b.count
            elseif key == "owner" then
                av, bv = string.lower(a.owner or ""), string.lower(b.owner or "")
            elseif key == "time" then
                av, bv = a.timeLeft or 0, b.timeLeft or 0
            else
                av, bv = a.unit or math.huge, b.unit or math.huge
            end
            if av == bv then return a.index < b.index end
            if desc then return av > bv end
            return av < bv
        end)
        self.list:SetData(self._listings, keepScroll)
        self.list:SetSelected(self._selected)
        self.list:SetSort(key, desc)
    end;

    -- ---- acting --------------------------------------------------------

    _Select = function(self, row)
        self:HidePopups()
        self._selected = row
        self.list:SetSelected(row)
        if row then self._bidAmount:SetCopper(row.requiredBid) end
        self:_UpdateActions()
    end;

    -- Era's own rules (AuctionFrameBrowse_Update): no bidding on your own
    -- auction or over your own bid; a bid of at least the next bid that you
    -- can pay; a buyout you can pay, counting a bid you already have down.
    _UpdateActions = function(self)
        local row = self._selected
        local canBid, canBuyout = false, false
        if row and not row.own then
            local money = GetMoney()
            if row.buyout > 0 and row.buyout >= row.minBid then
                canBuyout = money >= row.buyout or (row.highBidder and money + row.bidAmount >= row.buyout)
            end
            local bid = self._bidAmount:GetCopper()
            canBid = not row.highBidder and bid >= row.requiredBid and bid <= MAXIMUM_BID_PRICE and money >= bid
                and (row.buyout == 0 or bid < row.buyout)
        end
        self._bid:SetEnabled(canBid)
        self._buyout:SetEnabled(canBuyout)
    end;

    -- Bid `amount` on `row` (a buyout is a bid of the buyout price), if the
    -- buffer still holds that auction at that index.
    Place = function(self, row, amount)
        if not self._owner.scan:Matches(row) then
            UIErrorsFrame:AddMessage("That auction has changed.", 1.0, 0.1, 0.1, 1.0)
            return
        end
        PlaceAuctionBid("list", row.index, amount)
    end;

    HidePopups = function(self)
        StaticPopup_Hide(POPUP_BUYOUT)
        StaticPopup_Hide(POPUP_BID)
    end;
}
