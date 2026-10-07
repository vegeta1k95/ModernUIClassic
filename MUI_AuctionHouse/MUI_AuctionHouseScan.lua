-- MUI_AuctionHouseScan: the one channel to Era's auction listing API.
--
-- Era runs the legacy auction client: QueryAuctionItems returns one page of
-- fifty auctions into a single shared "list" buffer, throttled, and the
-- answer arrives as AUCTION_ITEM_LIST_UPDATE. Every view that lists
-- auctions (browse, an item's listings, the sell tab's market) asks through
-- here, one job at a time; a new job replaces the old.
--
--   job = {
--       text, exact,                        name filter, whole-name match
--       minLevel, maxLevel, usable, rarity, the filter panel's choices
--       filters,                            a category's filter list
--       sort,                               server-side sort column
--       maxPages,                           pages to read (default 1)
--       OnPage(rows, page, total),          each page as it arrives
--       OnDone(capped),                     after the last; capped = more existed
--       OnCancel(),                         replaced or closed before the last
--       OnRefresh(rows, total),             the buffer changed afterwards
--   }
--
-- A row is one auction of the current page: index (its place in the buffer,
-- which is what PlaceAuctionBid takes), itemId, name, icon, count, quality,
-- minBid, minIncrement, bidAmount, buyout, highBidder, owner, timeLeft, link,
-- level (the level the item requires; nil when the listing's level column
-- holds something else for it: a recipe's skill, a bag's slots).
--
-- The buffer is live: bidding on or buying an auction re-sends the page and
-- shifts every index after it. A single-page job therefore keeps receiving
-- the page through OnRefresh until the next job starts, and Matches tells
-- whether a row still describes the auction at its index.

-- NUM_AUCTION_ITEMS_PER_PAGE, which lives in the load-on-demand auction addon.
local PAGE_SIZE = 50
local RETRY     = 0.1

class "AuctionHouseScan" : extends "Frame" {
    __init = function(self)
        Frame.__init(self, "Frame")
        self._job      = nil     -- the job being read
        self._view     = nil     -- the finished job whose page is in the buffer
        self._awaiting = false   -- a query is out, its answer not yet read
        self:RegisterEventHandler("AUCTION_ITEM_LIST_UPDATE", function() self:_OnListUpdate() end)
        self:RegisterEventHandler("AUCTION_HOUSE_CLOSED", function() self:Cancel() end)
    end;

    Start = function(self, job)
        self:_Abandon()
        self._job      = job
        self._view     = nil
        self._awaiting = false
        job.page = 0
        self:_Send(job)
    end;

    Cancel = function(self)
        self:_Abandon()
        self._view     = nil
        self._awaiting = false
    end;

    -- Drop the job being read, telling it so.
    _Abandon = function(self)
        local job = self._job
        self._job = nil
        if job and job.OnCancel then job.OnCancel() end
    end;

    -- Send the job's current page as soon as the client takes queries.
    _Send = function(self, job)
        if self._job ~= job then return end
        if not CanSendAuctionQuery("list") then
            C_Timer.After(RETRY, function() self:_Send(job) end)
            return
        end
        if job.sort then
            SortAuctionClearSort("list")
            SortAuctionSetSort("list", job.sort, false)
        end
        self._awaiting = true
        -- Era's own argument defaults (AuctionFrameBrowse_Search): 0 for an
        -- empty level box, -1 for any rarity; a nil there drops the query.
        QueryAuctionItems(job.text or "", job.minLevel or 0, job.maxLevel or 0, job.page,
            job.usable or false, job.rarity or -1, false, job.exact or false, job.filters)
    end;

    _OnListUpdate = function(self)
        local job = self._job
        if job then
            -- Only the first update after a query is its answer; later ones
            -- (item data trickling in) would be read as the next page.
            if not self._awaiting then return end
            self._awaiting = false
            local rows, total, batch = self:ReadPage()
            job.OnPage(rows, job.page, total)
            if self._job ~= job then return end
            -- A full page means more, whatever `total` says: on a filtered
            -- query some realms report the page's own size as the total.
            local more = batch >= PAGE_SIZE or (job.page + 1) * PAGE_SIZE < total
            if more and job.page + 1 < (job.maxPages or 1) then
                job.page = job.page + 1
                self:_Send(job)
            else
                self._job  = nil
                self._view = job
                job.OnDone(more)
            end
        elseif self._view and self._view.OnRefresh then
            local rows, total = self:ReadPage()
            self._view.OnRefresh(rows, total)
        end
    end;

    -- The page now in the buffer: rows, the query's total, the page's size.
    ReadPage = function(self)
        local rows = {}
        local batch, total = GetNumAuctionItems("list")
        for i = 1, batch do
            local name, icon, count, quality, _, level, levelKind, minBid, minIncrement, buyout,
                  bidAmount, highBidder, _, owner, _, _, itemId = GetAuctionItemInfo("list", i)
            if name == "" then name = nil end
            -- An item this client has not seen yet comes without a name;
            -- its id still identifies it, and the name follows.
            if name or itemId then
                rows[#rows + 1] = {
                    index        = i,
                    itemId       = itemId,
                    name         = name,
                    icon         = icon,
                    count        = count or 1,
                    quality      = quality or 1,
                    level        = levelKind == "REQ_LEVEL_ABBR" and level or nil,
                    minBid       = minBid or 0,
                    minIncrement = minIncrement or 0,
                    bidAmount    = bidAmount or 0,
                    buyout       = buyout or 0,
                    highBidder   = highBidder and true or false,
                    owner        = owner,
                    timeLeft     = GetAuctionItemTimeLeft("list", i),
                    link         = GetAuctionItemLink("list", i),
                }
            end
        end
        return rows, total or batch, batch
    end;

    -- Whether the auction at `row.index` is still the one `row` was read
    -- from. Checked before money moves: the buffer shifts under the list.
    Matches = function(self, row)
        local _, _, count, _, _, _, _, minBid, _, buyout, bidAmount, _, _, _, _, _, itemId = GetAuctionItemInfo("list", row.index)
        return itemId == row.itemId and count == row.count and buyout == row.buyout
           and minBid == row.minBid and bidAmount == row.bidAmount
    end;
}
