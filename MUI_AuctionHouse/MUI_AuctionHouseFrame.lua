-- MUI_AuctionHouseFrame: the auction house window — retail's AuctionHouseFrame
-- (800x538, three tabs: Buy, Sell, Auctions) over Era's auction API.
--
-- Era still runs the legacy auction client, and the session belongs to its
-- AuctionFrame: the panel manager opens it at an auctioneer, Escape and
-- walking away close it, and its OnHide ends the session. So that frame
-- stays the real panel. Its art and children are hidden, it stops taking
-- the mouse, and this window rides on top of it, following it by screen
-- position (the two stay independent frames, as with the profession
-- window). Closing goes through CloseAuctionHouse, which has the client
-- hide its own frame; the module hides this one from that frame's OnHide.
--
--   AuctionHouseWindow()
--     :Open() / :Close()            from the native frame's OnShow / OnHide
--     :SetDisplayMode(mode)         "Buy", "ItemBuy", "ItemSell", "Auctions"
--     :StartSearch()                search box + filters + category
--     :RefreshSearch()              the same again, if a search was run
--     :SearchFavorites()
--     :OpenItem(row)                a browse row's listings
--     .scan .searchBar .categories .browse .buy .sell .auctions

local Style = MUI_AuctionHouseStyle
local S     = Style.S

local FRAME_W, FRAME_H = 800, 538
-- Where the window's top-left sits from the native frame's: the panel
-- manager puts that frame flush against the screen edge, retail's a little in.
local NATIVE_DX, NATIVE_DY = 16, -12

local TITLES = {
    Buy      = "Browse Auctions",
    ItemBuy  = "Browse Auctions",
    ItemSell = "Sell",
    Auctions = "Your Auctions",
}

class "AuctionHouseWindow" : extends "PanelPortrait" {
    __init = function(self)
        PanelPortrait.__init(self, nil, "MUI_AuctionHouseFrame", "")
        self:SetFrameStrata("HIGH")
        self:SetToplevel(true)
        self:SetSize(FRAME_W * S, FRAME_H * S)
        self:AlignParentTopLeft(116, 16)
        self:Hide()
        self.mode = nil

        self._blizzard = Frame(AuctionFrame)

        self._closeButton = CloseButton(self)
        self._closeButton:PutInfront(self._border, 1)
        self._closeButton:SetScale(0.9)
        -- The client closes its frame, and that closes ours; outside an
        -- auction session there is nothing to close but this window.
        self._closeButton.OnClick = function()
            CloseAuctionHouse()
            if not self._blizzard:IsShown() then self:Close() end
        end

        self:_BuildTopBar()
        self:_BuildMoney()

        self.scan = AuctionHouseScan()

        self.searchBar = AuctionHouseSearchBar(self, self)
        self.searchBar:AlignParentTopRight(29 * S, 12 * S)
        self.categories = AuctionHouseCategories(self, self)
        self.categories:AlignParentTopLeft(73 * S, 4 * S)
        self.browse = AuctionHouseBrowse(self, self)
        self.browse:AlignParentTopLeft(74 * S, 172 * S)
        self.buy = AuctionHouseBuy(self, self)
        self.buy:AlignParentTopLeft(69 * S, 172 * S)
        self.sell = AuctionHouseSell(self, self)
        self.sell:AlignParentTopLeft(69 * S, 4 * S)
        self.auctions = AuctionHouseAuctions(self, self)
        self.auctions:AlignParentTopLeft(42 * S, 5 * S)
        self.searchBar:UpdateFavorites()

        self:_BuildTabs()

        self:RegisterEventHandler("PLAYER_MONEY", function() self:_UpdateMoney() end)
        self:HookScript("OnUpdate", function() self:_FollowNative() end)
    end;

    -- The streak band under the title bar.
    _BuildTopBar = function(self)
        local width = self:GetWidth()
        local tiles = math.ceil(width / 256)
        local tileW = width / tiles
        for i = 1, tiles do
            local band = Texture(self, nil, "BACKGROUND")
            band:SetDrawLayer("BACKGROUND", 1)
            band:SetTextureRegion(MUI.TEX_BASE .. "frame-inner-horizontal", 256, 128, 0, 0, 256, 40)
            band:SetSize(tileW, 40)
            band:AlignParentTopLeft(16, (i - 1) * tileW)
        end
    end;

    -- The player's money, bottom left: a dark well with the thin gold band.
    _BuildMoney = function(self)
        local well = InnerFrame(self)
        well:SetSize(165 * S, 24 * S)
        well:AlignParentBottomLeft(3 * S, 2 * S)
        local band = Frame("Frame", self, nil, "ThinGoldEdgeTemplate")
        band:SetSize(158 * S, 19 * S)
        band:AlignParentBottomLeft(6 * S, 5 * S)
        band:PutInfront(well, 1)
        self._money = Style:Label(band, 10.5, 1, 1, 1)
        self._money:SetJustifyH("RIGHT")
        self._money:AlignParentRight(6 * S)
    end;

    _UpdateMoney = function(self)
        self._money:SetText(C_CurrencyInfo.GetCoinTextureString(GetMoney(), 11))
    end;

    -- Buy, Sell and Auctions, hanging under the window's bottom edge.
    _BuildTabs = function(self)
        self._tabs = {}
        local x = 22
        for _, spec in ipairs({ { "Buy", "Buy" }, { "ItemSell", "Sell" }, { "Auctions", "Auctions" } }) do
            local mode = spec[1]
            local tab = AuctionHouseTab(self, spec[2])
            tab:SetPoint("TOPLEFT", self, "BOTTOMLEFT", x, 1)
            tab.OnClick = function() self:SetDisplayMode(mode) end
            self._tabs[mode] = tab
            x = x + tab:GetWidth() - 4
        end
    end;

    -- ---- the native frame ----------------------------------------------

    -- Empty the native frame: nothing of it shows or takes a click. Its
    -- width is brought to this window's right edge, where its side dressing
    -- room hangs (ctrl-click an item).
    _HideNative = function(self)
        local native = self._blizzard
        native:HideAllRegions()
        native:HideAllChildren()
        native:EnableMouse(false)
        native:SetWidth(NATIVE_DX + FRAME_W * S)
    end;

    -- Sit on the native frame wherever the panel manager has put it.
    _FollowNative = function(self)
        local native = self._blizzard
        local left, top = native:GetLeft(), native:GetTop()
        if not left or (left == self._nativeLeft and top == self._nativeTop) then return end
        self._nativeLeft, self._nativeTop = left, top
        local ratio = native:GetEffectiveScale() / self:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * ratio + NATIVE_DX, top * ratio + NATIVE_DY)
    end;

    -- A visit starts: the native frame has just opened.
    Open = function(self)
        self:SetPortraitFromUnit("npc")
        self:_UpdateMoney()
        self.browse:Reset()
        self.mode = nil
        self:SetDisplayMode("Buy")
        self._nativeLeft = nil
        self:_FollowNative()
        self:Show()
        -- Only once this window is up does the native one go blank.
        self:_HideNative()
        -- The client's "auctions tab showing" flag: with it up, a right-click
        -- on a bag item puts it in the sell slot instead of using it.
        SetAuctionsTabShowing(true)
    end;

    Close = function(self)
        self.scan:Cancel()
        self.searchBar:ClosePopups()
        self.sell:ClosePopups()
        self:Hide()
    end;

    -- ---- views ---------------------------------------------------------

    SetDisplayMode = function(self, mode)
        if mode ~= self.mode then
            self.searchBar:ClosePopups()
            self.sell:ClosePopups()
        end
        self.mode = mode
        local buying = mode == "Buy" or mode == "ItemBuy"
        self.searchBar:SetVisible(buying)
        self.categories:SetVisible(buying)
        self.browse:SetVisible(mode == "Buy")
        self.buy:SetVisible(mode == "ItemBuy")
        self.sell:SetVisible(mode == "ItemSell")
        self.auctions:SetVisible(mode == "Auctions")
        self._tabs.Buy:SetSelected(buying)
        self._tabs.ItemSell:SetSelected(mode == "ItemSell")
        self._tabs.Auctions:SetSelected(mode == "Auctions")
        self:SetTitle(TITLES[mode])
        if mode == "ItemSell" then
            self.sell:OnDisplayed()
        elseif mode == "Auctions" then
            self.auctions:OnDisplayed()
        end
    end;

    StartSearch = function(self)
        self:SetDisplayMode("Buy")
        self.browse:Search(self.searchBar:GetQuery(), self.categories:GetFilters())
    end;

    RefreshSearch = function(self)
        if self.browse.searched then self:StartSearch() end
    end;

    SearchFavorites = function(self)
        self:SetDisplayMode("Buy")
        self.browse:SearchFavorites()
    end;

    OpenItem = function(self, row)
        self:SetDisplayMode("ItemBuy")
        self.buy:Open(row)
    end;
}
