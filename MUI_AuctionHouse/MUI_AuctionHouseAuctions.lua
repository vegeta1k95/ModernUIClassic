-- MUI_AuctionHouseAuctions: the Auctions tab (retail's AuctionsFrame) —
-- what you have up for sale and what you have bid on.
--
-- Two top tabs, Auctions and Bids. On the left the summary: "All" and one
-- line per item, filtering the table on the right (Name | Bid | Buyout |
-- Time Left). Cancel Auction acts on the selected auction of yours.
--
-- Both lists are the client's ("owner" and "bidder"): Era's own auction
-- frame, still running out of sight, asks for them whenever the auction
-- house opens, and AUCTION_OWNED_LIST_UPDATE / AUCTION_BIDDER_LIST_UPDATE
-- announce every change.

local Style = MUI_AuctionHouseStyle
local S     = Style.S

local SUMMARY_ROW_H = 21
local POPUP_CANCEL  = "MUI_AUCTION_CANCEL"

-- Era's own CANCEL_AUCTION confirmation, on our selection.
StaticPopupDialogs[POPUP_CANCEL] = {
    text = CANCEL_AUCTION_CONFIRMATION,
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(dialog, data) data.panel:Cancel(data.row) end,
    OnShow = function(dialog, data)
        MoneyFrame_Update(dialog.MoneyFrame, data.cost)
        dialog:SetText(data.cost > 0 and CANCEL_AUCTION_CONFIRMATION_MONEY or CANCEL_AUCTION_CONFIRMATION)
    end,
    hasMoneyFrame = 1,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1,
}

local COLUMNS = {
    { key = "name",   title = "Name",      fill = true, justify = "LEFT",  text = function(d) return d.label end, icon = true },
    { key = "bid",    title = "Bid",       width = 120, justify = "RIGHT", text = function(d) return d.bidText end },
    { key = "buyout", title = "Buyout",    width = 120, justify = "RIGHT", text = function(d) return d.buyoutText end },
    { key = "time",   title = "Time Left", width = 90,  justify = "RIGHT", text = function(d) return d.timeText end },
}

-- ---------------------------------------------------------------------
-- AuctionHouseSummaryRow: a line of the summary (AuctionsSummaryLine): the
-- item's small framed icon and name, or the "All" line.
-- ---------------------------------------------------------------------
class "AuctionHouseSummaryRow" : extends "Button" {
    __init = function(self, parent, owner)
        Button.__init(self, parent)
        self:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self:SetSize(136 * S, SUMMARY_ROW_H * S)
        self.entry = nil

        self._selected = Style:Piece(self, "BACKGROUND", "RowSelect", 1, 1)
        self._selected:FillParent()
        self._selected:Hide()
        self:SetHighlightAtlas(MUI_AtlasRegistry.AuctionHouse, "RowHighlight", true)

        self._icon = Texture(self, nil, "BORDER")
        self._icon:SetSize(14 * S, 14 * S)
        self._icon:AlignParentLeft(4 * S)
        self._iconBorder = Style:Piece(self, "ARTWORK", "ItemIconSmallBorder", 16, 16)
        self._iconBorder:CenterAt(self._icon)

        self._label = Style:Label(self, 9.5, 1, 0.82, 0)
        self._label:SetJustifyH("LEFT")
        self._label:SetWordWrap(false)

        self.OnClick = function() owner:SelectSummary(self.entry) end
    end;

    SetEntry = function(self, entry, selected)
        self.entry = entry
        self._icon:SetVisible(entry.name ~= nil)
        self._iconBorder:SetVisible(entry.name ~= nil)
        self._label:ClearAllPoints()
        if entry.name then
            self._icon:SetTexture(entry.icon)
            self._label:SetWidth(110 * S)
            self._label:AlignParentLeft(24 * S)
            self._label:SetText(Style:QualityText(entry.name, entry.quality))
        else
            self._label:SetWidth(124 * S)
            self._label:AlignParentLeft(6 * S)
            self._label:SetText(entry.title)
        end
        self._selected:SetVisible(selected)
    end;
}


class "AuctionHouseAuctions" : extends "Frame" {
    __init = function(self, parent, owner)
        Frame.__init(self, "Frame", parent)
        self:SetSize(795 * S, 469 * S)
        self._owner    = owner
        self._kind     = "owner"   -- the client's list: "owner" (your auctions) or "bidder" (your bids)
        self._rows     = {}
        self._filter   = nil       -- the summary's item name; nil = all
        self._selected = nil
        self._sortKey  = nil       -- nil keeps the client's order
        self._sortDesc = false
        self._summaryRows = {}

        self:_BuildTabs()
        self:_BuildSummary()
        self:_BuildList()

        self._cancel = ButtonGold(self, nil, "Cancel Auction")
        self._cancel:SetSize(158 * S, 22 * S)
        self._cancel.label:SetFontSize(10.5)
        self._cancel:AlignParentBottomRight(-22 * S, 3 * S)
        self._cancel.OnClick = function()
            local row = self._selected
            if row then StaticPopup_Show(POPUP_CANCEL, nil, nil, { panel = self, row = row, cost = row.cancelCost }) end
        end

        self:RegisterEventHandler("AUCTION_OWNED_LIST_UPDATE", function()
            if self._kind == "owner" and self:IsVisible() then self:Refresh() end
        end)
        self:RegisterEventHandler("AUCTION_BIDDER_LIST_UPDATE", function()
            if self._kind == "bidder" and self:IsVisible() then self:Refresh() end
        end)
        self:SetScript("OnHide", function() StaticPopup_Hide(POPUP_CANCEL) end)

        self:_SetKind("owner")
    end;

    -- The two tabs standing on the lists' top edge.
    _BuildTabs = function(self)
        self._tabAuctions = AuctionHouseTab(self, "Auctions", true)
        self._tabAuctions:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 58 * S, -34 * S)
        self._tabAuctions.OnClick = function() self:_SetKind("owner") end
        self._tabBids = AuctionHouseTab(self, "Bids", true)
        self._tabBids:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 58 * S + self._tabAuctions:GetWidth() - 4, -34 * S)
        self._tabBids.OnClick = function() self:_SetKind("bidder") end
    end;

    _BuildSummary = function(self)
        local summary = Frame("Frame", self)
        summary:SetFrameLevel(self:GetFrameLevel() + 3)
        summary:SetSize(168 * S, 437 * S)
        summary:AlignParentTopLeft(32 * S, -1 * S)
        local bg = Style:Background(summary, "SummaryList")
        bg:FillParent(3 * S)
        Style:Inset(summary)

        self._summary = AuctionHouseScrollArea(summary, 138 * S, 431 * S, 8 * S, 2 * SUMMARY_ROW_H * S)
        self._summary:AlignParentTopLeft(3 * S, 3 * S)
    end;

    _BuildList = function(self)
        self.list = AuctionHouseList(self, COLUMNS, {
            width = 623, height = 438, background = "Index", tooltips = true, refresh = { x = -4, y = 34 },
        })
        self.list:SetFrameLevel(self:GetFrameLevel() + 3)
        self.list:AlignParentTopLeft(31 * S, 167 * S)
        self.list.OnSort = function(_, key)
            if self._sortKey == key then
                self._sortDesc = not self._sortDesc
            else
                self._sortKey, self._sortDesc = key, false
            end
            self:_Publish(true)
        end
        self.list.OnRowClick = function(_, row) self:_Select(row) end
        self.list.OnRefresh = function()
            if self._kind == "owner" then GetOwnerAuctionItems() else GetBidderAuctionItems() end
        end
    end;

    -- ---- data ----------------------------------------------------------

    _SetKind = function(self, kind)
        self._kind = kind
        self._filter = nil
        self._tabAuctions:SetSelected(kind == "owner")
        self._tabBids:SetSelected(kind == "bidder")
        self._cancel:SetVisible(kind == "owner")
        self.list:SetEmptyText(kind == "owner" and "You have no auctions." or "You have no bids.")
        self:Refresh()
    end;

    -- One row of the client's list: what the table shows of it, and for an
    -- auction of yours what cancelling costs (Era: 5% of the standing bid).
    _Row = function(self, kind, i)
        local name, icon, count, quality, _, _, _, minBid, _, buyout, bidAmount, highBidder, _, _, _, saleStatus, itemId = GetAuctionItemInfo(kind, i)
        if not name or name == "" then return nil end
        local timeLeft = GetAuctionItemTimeLeft(kind, i)
        local row = {
            index = i, kind = kind, name = name, itemId = itemId, icon = icon, count = count, quality = quality,
            minBid = minBid, bidAmount = bidAmount, buyout = buyout, timeLeft = timeLeft,
            sold = saleStatus == 1,
            link = GetAuctionItemLink(kind, i),
            cancelCost = math.floor(bidAmount * AUCTION_CANCEL_COST / 100),
        }
        local hasBid = bidAmount > 0
        row.bid = hasBid and bidAmount or minBid
        if row.sold then
            -- sold, the money on its way: the client reports seconds until delivery
            row.label      = "|cff808080" .. string.format(AUCTION_ITEM_SOLD, name) .. "|r"
            row.bidText    = Style:Money(bidAmount)
            row.buyoutText = ""
            row.timeText   = string.format(AUCTION_ITEM_TIME_UNTIL_DELIVERY, SecondsToTime(math.max(timeLeft, 1)))
        else
            row.label = Style:QualityText(name, quality)
            if count > 1 then row.label = row.label .. " |cff808080x" .. count .. "|r" end
            row.bidText = Style:Money(row.bid)
            if kind == "bidder" then
                -- your bid in green while it stands, red once outbid
                row.bidText = (highBidder and "|cff40ff40" or "|cffff4040") .. row.bidText .. "|r"
            elseif not hasBid then
                row.bidText = "|cff808080" .. row.bidText .. "|r"
            end
            row.buyoutText = Style:Money(buyout, "-")
            row.timeText   = Style:TimeLeft(timeLeft)
        end
        return row
    end;

    -- Read the current list again and rebuild summary and table.
    Refresh = function(self)
        local previous = self._selected
        local kind = self._kind
        local rows = {}
        for i = 1, (GetNumAuctionItems(kind)) do
            rows[#rows + 1] = self:_Row(kind, i)
        end
        self._rows = rows

        -- keep the selection on the same auction when it is still there
        self._selected = nil
        if previous and previous.kind == kind then
            for _, row in ipairs(rows) do
                if self:_Same(row, previous) then
                    self._selected = row
                    break
                end
            end
        end
        if previous and not self._selected then StaticPopup_Hide(POPUP_CANCEL) end

        self:_PublishSummary()
        self:_Publish(true)
    end;

    _Same = function(self, a, b)
        return a.itemId == b.itemId and a.count == b.count and a.minBid == b.minBid
           and a.buyout == b.buyout and a.bidAmount == b.bidAmount
    end;

    -- "All" and one line per item on the list, by name.
    _PublishSummary = function(self)
        local entries, seen, filterAlive = {}, {}, false
        for _, row in ipairs(self._rows) do
            if not seen[row.name] then
                seen[row.name] = true
                entries[#entries + 1] = { name = row.name, icon = row.icon, quality = row.quality }
                if row.name == self._filter then filterAlive = true end
            end
        end
        table.sort(entries, function(a, b) return a.name < b.name end)
        table.insert(entries, 1, { title = self._kind == "owner" and "All Auctions" or "All Bids" })
        if not filterAlive then self._filter = nil end

        for i, entry in ipairs(entries) do
            local line = self._summaryRows[i]
            if not line then
                line = AuctionHouseSummaryRow(self._summary.content, self)
                line:AlignParentTopLeft((i - 1) * SUMMARY_ROW_H * S, 0)
                self._summaryRows[i] = line
            end
            line:SetEntry(entry, entry.name == self._filter)
            line:Show()
        end
        for i = #entries + 1, #self._summaryRows do self._summaryRows[i]:Hide() end
        self._summary:SetContentHeight(#entries * SUMMARY_ROW_H * S)
    end;

    SelectSummary = function(self, entry)
        self._filter = entry.name
        self:_Select(nil)
        self:_PublishSummary()
        self:_Publish(false)
    end;

    -- The rows through the summary's filter, sorted, into the table.
    _Publish = function(self, keepScroll)
        local rows = {}
        for _, row in ipairs(self._rows) do
            if not self._filter or row.name == self._filter then rows[#rows + 1] = row end
        end
        local key, desc = self._sortKey, self._sortDesc
        if key then
            table.sort(rows, function(a, b)
                local av, bv
                if key == "bid" then
                    av, bv = a.bid, b.bid
                elseif key == "buyout" then
                    av, bv = a.buyout, b.buyout
                elseif key == "time" then
                    av, bv = a.timeLeft, b.timeLeft
                else
                    av, bv = string.lower(a.name), string.lower(b.name)
                end
                if av == bv then return a.index < b.index end
                if desc then return av > bv end
                return av < bv
            end)
        end
        self.list:SetData(rows, keepScroll)
        self.list:SetSelected(self._selected)
        self.list:SetSort(key, desc)
        self.list:SetTotalText(tostring(#rows))
        self:_UpdateCancel()
    end;

    -- ---- acting --------------------------------------------------------

    _Select = function(self, row)
        StaticPopup_Hide(POPUP_CANCEL)
        self._selected = row
        self.list:SetSelected(row)
        self:_UpdateCancel()
    end;

    _UpdateCancel = function(self)
        local row = self._selected
        self._cancel:SetEnabled(row ~= nil and row.kind == "owner" and not row.sold
            and CanCancelAuction(row.index) and true or false)
    end;

    -- Cancel `row`, if the client's list still holds that auction there.
    Cancel = function(self, row)
        local current = self:_Row("owner", row.index)
        if not (current and self:_Same(current, row)) then
            UIErrorsFrame:AddMessage("That auction has changed.", 1.0, 0.1, 0.1, 1.0)
            return
        end
        CancelAuction(row.index)
    end;

    -- The tab came forward.
    OnDisplayed = function(self)
        self:Refresh()
    end;
}
