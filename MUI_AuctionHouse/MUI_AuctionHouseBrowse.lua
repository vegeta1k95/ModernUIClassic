-- MUI_AuctionHouseBrowse: the Buy tab's search bar and browse results.
--
--   AuctionHouseSearchBar     favourites button, search box, Filter, Search
--   AuctionHouseFilterPanel   the Filter popup: level range, usable, rarity
--   AuctionHouseBrowse        the results: one row per item, with its lowest
--                             unit price and the quantity on offer
--
-- Retail's browse is aggregated by the server. Era's API only returns flat
-- pages of auctions, so a search reads the result page by page and folds
-- the auctions into items here. The pages are asked for in name order: all
-- of an item's auctions then arrive together, so when a very broad search
-- is cut off at MAX_PAGES every item shown still has its true price and
-- quantity, and what is missing is the tail of the alphabet.

local Style = MUI_AuctionHouseStyle
local S     = Style.S

local PAGE_SIZE = 50
-- 2500 auctions. A whole category on a busy realm is more; the list says so.
local MAX_PAGES = 50

local SQUARE_UP        = "Interface\\Buttons\\UI-SquareButton-Up"
local SQUARE_DOWN      = "Interface\\Buttons\\UI-SquareButton-Down"
local SQUARE_HIGHLIGHT = "Interface\\Buttons\\UI-Common-MouseHilight"

-- ---------------------------------------------------------------------
-- AuctionHouseFilterPanel: the popup under the Filter button. Its choices
-- are read by the search bar (minLevel, maxLevel, usable, rarity); a change
-- calls onChanged. The popup shell and its click-away are DropdownMenu's.
-- ---------------------------------------------------------------------
local RARITIES = { -1, 0, 1, 2, 3, 4 }   -- -1 = any, then Poor .. Epic

class "AuctionHouseFilterPanel" {
    __init = function(self, bar, toggle, onChanged)
        self.minLevel  = 0
        self.maxLevel  = 0
        self.usable    = false
        self.rarity    = -1
        self._onChanged = onChanged

        self._menu = DropdownMenu(bar, nil, toggle)
        self._menu:SetMenuWidth(176)
        self._menu:SetAnchor(function(popup, anchor)
            popup:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 12, 4)
        end)
        local popup = self._menu.popup
        popup:SetHeight(214)

        local levelTitle = Style:Label(popup, 10.5, 1, 0.82, 0)
        levelTitle:SetText("Level Range")
        levelTitle:AlignParentTopLeft(13, 15)

        self._min = self:_LevelBox(popup)
        self._min:AlignParentTopLeft(31, 19)
        local dash = Style:Label(popup, 10.5, 1, 1, 1)
        dash:SetText("-")
        dash:RightOf(self._min, 6)
        self._max = self:_LevelBox(popup)
        self._max:RightOf(dash, 6)

        self._usable = CheckBoxThin(popup, nil, "Usable Items Only")
        self._usable:SetSize(140, 13)
        self._usable:SetBoxSize(11, 11)
        self._usable.label:SetFontSize(10.5)
        self._usable:AlignParentTopLeft(59, 17)
        self._usable.OnChanged = function(_, checked)
            self.usable = checked
            self._onChanged()
        end

        local rarityTitle = Style:Label(popup, 10.5, 1, 0.82, 0)
        rarityTitle:SetText("Rarity")
        rarityTitle:AlignParentTopLeft(82, 15)

        self._rarities = {}
        for i, quality in ipairs(RARITIES) do
            local text = quality < 0 and "All" or Style:QualityText(_G["ITEM_QUALITY" .. quality .. "_DESC"], quality)
            local radio = CheckBoxThin(popup, nil, text)
            radio:SetSize(140, 13)
            radio:SetBoxSize(11, 11)
            radio.label:SetFontSize(10.5)
            radio:AlignParentTopLeft(100 + (i - 1) * 17, 19)
            radio:SetChecked(quality == self.rarity)
            radio.OnChanged = function() self:_SetRarity(quality) end
            self._rarities[i] = radio
        end
    end;

    -- A level box applies when it loses the focus, not on every digit.
    _LevelBox = function(self, popup)
        local box = EditBoxQuantity(popup)
        box:HookScript("OnEditFocusLost", function() self:_ReadLevels() end)
        return box
    end;

    _ReadLevels = function(self)
        local min, max = self._min:GetNumber(), self._max:GetNumber()
        if min == self.minLevel and max == self.maxLevel then return end
        self.minLevel, self.maxLevel = min, max
        self._onChanged()
    end;

    -- The rarity boxes are a radio group: one is always checked.
    _SetRarity = function(self, quality)
        local changed = self.rarity ~= quality
        self.rarity = quality
        for i, radio in ipairs(self._rarities) do
            radio:SetChecked(RARITIES[i] == quality)
        end
        if changed then self._onChanged() end
    end;

    -- How many of the choices are off their default.
    CountActive = function(self)
        local n = 0
        if self.minLevel > 0 or self.maxLevel > 0 then n = n + 1 end
        if self.usable then n = n + 1 end
        if self.rarity >= 0 then n = n + 1 end
        return n
    end;

    Toggle = function(self) self._menu:Toggle() end;
    Close  = function(self) self._menu:Close() end;
}


-- ---------------------------------------------------------------------
-- AuctionHouseSearchBar: retail's SearchBar, 618x40 — the favourites button
-- at the left, the search box, then Filter and Search at the right.
-- ---------------------------------------------------------------------
class "AuctionHouseSearchBar" : extends "Frame" {
    __init = function(self, parent, owner)
        Frame.__init(self, "Frame", parent)
        self:SetSize(618 * S, 40 * S)
        self._owner = owner

        self._favorites = Button(self)
        self._favorites:SetSize(28 * S, 28 * S)
        self._favorites:AlignParentLeft()
        self._favorites:SetNormalTexture(SQUARE_UP)
        self._favorites:SetPushedTexture(SQUARE_DOWN)
        self._favorites:SetHighlightTexture(SQUARE_HIGHLIGHT, "ADD")
        self._star = Style:Piece(self._favorites, "OVERLAY", "IconFavorite", 15.5, 14)
        self._star:CenterInParent()
        self._favorites.OnClick = function() owner:SearchFavorites() end
        self._favorites:SetTooltip("ANCHOR_RIGHT", function(tip)
            tip:AddTitle("Favorites")
            if owner.browse:HasFavorites() then
                tip:AddLine("Search for your favorite items.", 1, 1, 1, true)
            else
                tip:AddLine("Star an item in the results to add it to your favorites.", 0.7, 0.7, 0.7, true)
            end
        end)

        self._box = SearchBox(self)
        self._box:SetSize(241 * S, 22 * S)
        self._box:RightOf(self._favorites, 9 * S)
        self._box.OnEnterPressed = function() owner:StartSearch() end

        self._search = ButtonGold(self, nil, "Search")
        self._search:SetSize(132 * S, 22 * S)
        self._search.label:SetFontSize(10.5)
        self._search:AlignParentRight()
        self._search.OnClick = function() owner:StartSearch() end

        -- our dropdown art is drawn for a 22-high button, whatever the scale
        self._filter = DropdownSimple(self)
        self._filter:SetSize(93 * S, 22)
        self._filter:LeftOf(self._search, 10 * S)
        self._panel = AuctionHouseFilterPanel(self, self._filter, function()
            self:_UpdateFilterLabel()
            owner:RefreshSearch()
        end)
        self._filter.OnClick = function() self._panel:Toggle() end
        self:_UpdateFilterLabel()
    end;

    _UpdateFilterLabel = function(self)
        local n = self._panel:CountActive()
        self._filter:SetText(n > 0 and ("Filter (" .. n .. ")") or "Filter")
    end;

    -- The gold star while there are favourites to search for.
    UpdateFavorites = function(self)
        self._star:SetDesaturated(not self._owner.browse:HasFavorites())
    end;

    -- What to search for: the box's text and the filter panel's choices.
    -- A quoted text asks for that exact name, as in Era's own search box.
    GetQuery = function(self)
        local text = self._box:GetText() or ""
        local exact = false
        local dequoted = DequoteString(text)
        if dequoted then text, exact = dequoted, true end
        local panel = self._panel
        return {
            text     = text,
            exact    = exact,
            minLevel = panel.minLevel,
            maxLevel = panel.maxLevel,
            usable   = panel.usable,
            rarity   = panel.rarity,
        }
    end;

    ClosePopups = function(self)
        self._panel:Close()
        self._box:ClearFocus()
    end;
}


-- ---------------------------------------------------------------------
-- AuctionHouseBrowse: the browse results (retail's BrowseResultsFrame):
-- Price | Name | Level | Quantity | favourite star. Level is the level the
-- item requires, red when above the player's, as in Era's own list.
-- ---------------------------------------------------------------------
local COLUMNS = {
    { key = "price",    title = "Price",    width = 146, justify = "LEFT",  text = function(d) return d.priceText end },
    { key = "name",     title = "Name",     fill = true, justify = "LEFT",  text = function(d) return d.label end, icon = true },
    { key = "level",    title = "Level",    width = 55,  justify = "CENTER", text = function(d) return d.levelText end },
    { key = "quantity", title = "Quantity", width = 83,  justify = "RIGHT", text = function(d) return d.quantityText end },
    { key = "favorite", width = 24, favorite = true },
}

local PENDING_NAME = "|cff808080" .. RETRIEVING_ITEM_INFO .. "|r"

class "AuctionHouseBrowse" : extends "Frame" {
    __init = function(self, parent, owner)
        Frame.__init(self, "Frame", parent)
        self:SetSize(623 * S, 437 * S)
        self._owner    = owner
        self._items    = {}      -- the aggregate: name (or "#id" until named) -> entry
        self._job      = nil     -- the scan job these results come from
        self._pending  = false   -- some entries still wait for their item's name
        self._sortKey  = "name"
        self._sortDesc = false
        -- a search has run this visit (a filter change then re-runs it)
        self.searched  = false

        self.list = AuctionHouseList(self, COLUMNS, { width = 623, height = 437, background = "Index", tooltips = true })
        self.list:AlignParentTopLeft()
        self.list.OnSort = function(_, key)
            if self._sortKey == key then
                self._sortDesc = not self._sortDesc
            else
                self._sortKey, self._sortDesc = key, false
            end
            self:_Publish(false)
        end
        self.list.OnRowClick = function(_, data)
            if data.name then owner:OpenItem(data) end
        end
        self.list.IsFavorite = function(_, data) return self:IsFavorite(data.itemId) end
        self.list.OnFavorite = function(_, data) self:ToggleFavorite(data.itemId) end

        -- progress while reading, and what was left out of a cut-off search
        self._status = Style:Label(self, 9.5, 0.6, 0.6, 0.6)
        self._status:SetJustifyH("RIGHT")
        self._status:AlignParentBottomRight(-17 * S, 28 * S)

        -- names of items this client had not seen arrive one by one
        self:RegisterEventHandler("GET_ITEM_INFO_RECEIVED", function()
            if not self._pending or self._nameTimer then return end
            self._nameTimer = true
            C_Timer.After(0.25, function()
                self._nameTimer = nil
                if self._pending then self:_Publish(true) end
            end)
        end)

        self:Reset()
    end;

    -- A fresh visit: the tip, no results.
    Reset = function(self)
        self._items   = {}
        self._job     = nil
        self.searched = false
        self._status:SetText("")
        self.list:SetLoading(false)
        self.list:SetEmptyText(BROWSE_SEARCH_TEXT)
        self:_Publish(false)
    end;

    -- ---- searching -----------------------------------------------------

    Search = function(self, query, filters)
        self.searched = true
        self._items = {}
        self._status:SetText("")
        self.list:SetData({})
        self.list:SetLoading(true, SEARCHING_FOR_ITEMS)
        local job
        job = {
            text     = query.text,
            exact    = query.exact,
            minLevel = query.minLevel,
            maxLevel = query.maxLevel,
            usable   = query.usable,
            rarity   = query.rarity,
            filters  = filters,
            sort     = "name",
            maxPages = MAX_PAGES,
            OnPage = function(rows, page, total)
                for _, row in ipairs(rows) do self:_Absorb(row) end
                self.list:SetLoading(false)
                self:_Publish(page > 0)
                local pages = math.min(math.max(math.ceil(total / PAGE_SIZE), page + 1), MAX_PAGES)
                if pages > 1 then
                    self._status:SetText(string.format("%s %d / %d", SEARCHING_FOR_ITEMS, page + 1, pages))
                end
            end,
            OnDone = function(capped)
                self.list:SetLoading(false)
                self.list:SetEmptyText(BROWSE_NO_RESULTS)
                if capped then
                    self._status:SetText(string.format(
                        "Showing the first %d auctions by name. Narrow the search to see the rest.", MAX_PAGES * PAGE_SIZE))
                else
                    self._status:SetText("")
                end
            end,
            OnCancel = function() self:_Interrupted(job) end,
        }
        self._job = job
        self._owner.scan:Start(job)
    end;

    -- Another query took the listing channel before `job` was read out
    -- (an item opened, the sell tab's market). What arrived stays.
    _Interrupted = function(self, job)
        if self._job ~= job then return end
        self.list:SetLoading(false)
        self.list:SetEmptyText(BROWSE_NO_RESULTS)
        self._status:SetText("Search interrupted. Search again for the full results.")
    end;

    -- Each favourite by its exact name, one query after another; every
    -- favourite gets a row, on offer or not, so it can be unstarred here.
    SearchFavorites = function(self)
        self.searched = false
        self._items = {}
        self._status:SetText("")
        self.list:SetLoading(false)
        local names = {}
        for itemId in pairs(self:_Store()) do
            local name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemId)
            if name then
                self._items[name] = { itemId = itemId, name = name, link = link, quality = quality, icon = icon, count = 0 }
                names[#names + 1] = name
            else
                -- not in this client's cache: ask for it, it will be there next time
                C_Item.RequestLoadItemDataByID(itemId)
            end
        end
        table.sort(names)
        if #names == 0 then
            self._owner.scan:Cancel()
            self.list:SetLoading(false)
            self.list:SetEmptyText("You have no favorite items. Star an item in the results to add one.")
            self:_Publish(false)
            return
        end
        self:_Publish(false)
        self:_SearchFavorite(names, 1)
    end;

    _SearchFavorite = function(self, names, i)
        local name = names[i]
        self._status:SetText(string.format("%s %d / %d", SEARCHING_FOR_ITEMS, i, #names))
        local job
        job = {
            text  = name,
            exact = true,
            sort  = "unitprice",
            OnPage = function(rows)
                for _, row in ipairs(rows) do
                    if row.name == name then self:_Absorb(row) end
                end
            end,
            OnDone = function(capped)
                -- one page each: with more on offer, the quantity is a floor
                self._items[name].partial = capped
                self:_Publish(true)
                if i < #names then
                    self:_SearchFavorite(names, i + 1)
                else
                    self._status:SetText("")
                end
            end,
            OnCancel = function() self:_Interrupted(job) end,
        }
        self._job = job
        self._owner.scan:Start(job)
    end;

    -- ---- the aggregate -------------------------------------------------

    -- Fold one auction into its item. Keyed by name, which tells apart the
    -- random-suffix variants one item id covers; an item whose name the
    -- client does not have yet is keyed by its id until the name arrives.
    _Absorb = function(self, row)
        local key = row.name or ("#" .. row.itemId)
        local item = self._items[key]
        if not item then
            item = { itemId = row.itemId, name = row.name, icon = row.icon, quality = row.quality, count = 0 }
            self._items[key] = item
        end
        item.link  = item.link or row.link
        item.level = item.level or row.level
        item.count = item.count + row.count
        if row.buyout > 0 then
            local unit = math.ceil(row.buyout / row.count)
            if not item.unit or unit < item.unit then item.unit = unit end
        end
    end;

    -- Give the entries waiting for a name the one the client has by now,
    -- merging into the named entry when a later page brought one.
    _ResolveNames = function(self)
        local pending, named = false, {}
        for key, item in pairs(self._items) do
            if not item.name then
                local name = C_Item.GetItemInfo(item.itemId)
                if name then named[key] = name else pending = true end
            end
        end
        for key, name in pairs(named) do
            local item = self._items[key]
            self._items[key] = nil
            local known = self._items[name]
            if known then
                known.count = known.count + item.count
                if item.unit and (not known.unit or item.unit < known.unit) then known.unit = item.unit end
            else
                item.name = name
                self._items[name] = item
            end
        end
        self._pending = pending
    end;

    -- Rows from the aggregate, sorted, into the list.
    _Publish = function(self, keepScroll)
        self:_ResolveNames()
        local rows = {}
        local playerLevel = UnitLevel("player")
        for _, item in pairs(self._items) do
            -- The listing's own level where that is the level required, else
            -- (a favourite not on offer, a recipe, a bag) what the item says.
            local level = item.level or (item.link and select(5, C_Item.GetItemInfo(item.link))) or 0
            local levelText = ""
            if level > playerLevel then
                levelText = RED_FONT_COLOR_CODE .. level .. FONT_COLOR_CODE_CLOSE
            elseif level > 0 then
                levelText = tostring(level)
            end
            rows[#rows + 1] = {
                itemId       = item.itemId,
                name         = item.name,
                quality      = item.quality,
                icon         = item.icon,
                link         = item.link,
                count        = item.count,
                unit         = item.unit,
                level        = level,
                label        = item.name and Style:QualityText(item.name, item.quality) or PENDING_NAME,
                levelText    = levelText,
                priceText    = Style:Money(item.unit, "-"),
                quantityText = item.count > 0 and (item.count .. (item.partial and "+" or "")) or "-",
            }
        end
        local key, desc = self._sortKey, self._sortDesc
        table.sort(rows, function(a, b)
            local av, bv
            if key == "price" then
                av, bv = a.unit or math.huge, b.unit or math.huge
            elseif key == "quantity" then
                av, bv = a.count, b.count
            elseif key == "level" then
                av, bv = a.level, b.level
            else
                av, bv = string.lower(a.name or ""), string.lower(b.name or "")
            end
            if av == bv then return (a.name or "") < (b.name or "") end
            if desc then return av > bv end
            return av < bv
        end)
        self.list:SetData(rows, keepScroll)
        self.list:SetSort(key, desc)
    end;

    -- ---- favourites ----------------------------------------------------

    _Store = function(self)
        return MUI_DB.data.auctionHouse.favorites
    end;

    IsFavorite = function(self, itemId)
        return itemId ~= nil and self:_Store()[itemId] == true
    end;

    HasFavorites = function(self)
        return next(self:_Store()) ~= nil
    end;

    ToggleFavorite = function(self, itemId)
        if not itemId then return end
        local store = self:_Store()
        if store[itemId] then store[itemId] = nil else store[itemId] = true end
        self._owner.searchBar:UpdateFavorites()
    end;
}
