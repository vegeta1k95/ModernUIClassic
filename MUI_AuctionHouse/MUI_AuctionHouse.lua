-- MUI_AuctionHouse: retail's auction house window on Classic Era.
--
-- Era has the legacy auction client (the old three-tab AuctionFrame over the
-- page-based global API), not retail's Blizzard_AuctionHouseUI. This module
-- shows retail's window instead and keeps Era's frame underneath as the
-- session's owner:
--
--   MUI_AuctionHouseFrame        the window, its tabs and display modes
--   MUI_AuctionHouseBrowse       search bar, filters, aggregated results
--   MUI_AuctionHouseCategories   the category tree
--   MUI_AuctionHouseBuy          an item's listings, bid and buyout
--   MUI_AuctionHouseSell         posting an auction, the item's market
--   MUI_AuctionHouseAuctions     your auctions and bids, cancelling
--   MUI_AuctionHouseList         the table they all list in
--   MUI_AuctionHouseScan         the query channel to the listing API
--   MUI_AuctionHouseWidgets      tabs, input fields, scroll areas
--   MUI_AuctionHouseStyle        scale, labels, art pieces, money text
--
-- Not carried over from retail, which Era's API has nothing for:
-- commodities, the WoW Token, multi-stack posting.
--
-- Stands down when a dedicated auction addon is loaded: those build on
-- Era's own frame, which this module empties.

local RIVALS = { "Auctionator", "TradeSkillMaster", "aux-addon", "Auc-Advanced", "AuctionLite" }

object "ModuleAuctionHouse" : extends "Module" {
    __init = function(self)
        Module.__init(self, "AuctionHouse")
    end;

    OnEnable = function(self)
        for _, addon in ipairs(RIVALS) do
            if C_AddOns.IsAddOnLoaded(addon) then return end
        end

        -- Era's auction addon loads on the first visit to an auctioneer.
        if AuctionFrame then
            self:_HookNative()
        else
            self._loader = Frame()
            self._loader:RegisterEventHandler("ADDON_LOADED", function(_, _, addon)
                if addon == "Blizzard_AuctionUI" then
                    self._loader:UnregisterEventHandler("ADDON_LOADED")
                    self:_HookNative()
                end
            end)
        end
    end;

    -- The native frame opening and closing is the auction session
    -- starting and ending.
    _HookNative = function(self)
        local native = Frame(AuctionFrame)
        native:HookScript("OnShow", function() self:_Open() end)
        native:HookScript("OnHide", function()
            if self.window then self.window:Close() end
        end)
        if native:IsShown() then self:_Open() end
    end;

    -- The window is built on the first visit.
    _Open = function(self)
        if not self.window then self.window = AuctionHouseWindow() end
        self.window:Open()
    end;
}
