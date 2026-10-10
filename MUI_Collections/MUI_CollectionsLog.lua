-- MUI_CollectionsLog: the set pieces this character has ever held. Era keeps
-- no collection of appearances, so the Collections window keeps one of its
-- own: a piece counts as collected from the moment it is seen on the
-- character, in its bags or in its bank, and stays so after it is gone. It is
-- kept with the character's saved variables (MUI_DB.data.collections), along
-- with the sets and the mounts starred in their lists.
--
--   MUI_CollectionsLog
--     :Start()                  take in what is held now, watch for more
--     :Has(itemId)
--     :Count(set)               pieces held, pieces in all
--     :IsFavorite(setId)
--     :SetFavorite(setId, favorite)
--     .OnChanged                called when a piece or a star is added or a
--                               star taken away
--     :IsFavoriteMount(spell)
--     :SetFavoriteMount(spell, favorite)
--     .OnMountsChanged          called when a mount's star is set or taken

object "CollectionsLog" {
    __init = function(self)
        self.OnChanged = nil
        self.OnMountsChanged = nil
        self._items = {}
        self._favorites = {}
        self._mounts = {}
        self._bankOpen = false
    end;

    Start = function(self)
        local saved = MUI_DB.data.collections
        self._items, self._favorites, self._mounts = saved.items, saved.favorites, saved.mounts

        self._watcher = Frame()
        self._watcher:RegisterEventHandler("BAG_UPDATE_DELAYED", function()
            self:_ScanBags()
            if self._bankOpen then self:_ScanBank() end
            self:_Report()
        end)
        self._watcher:RegisterEventHandler("PLAYER_EQUIPMENT_CHANGED", function()
            self:_ScanEquipped()
            self:_Report()
        end)
        self._watcher:RegisterEventHandler("BANKFRAME_OPENED", function()
            self._bankOpen = true
            self:_ScanBank()
            self:_Report()
        end)
        self._watcher:RegisterEventHandler("BANKFRAME_CLOSED", function()
            self._bankOpen = false
        end)
        self._watcher:RegisterEventHandler("PLAYERBANKSLOTS_CHANGED", function()
            self:_ScanBank()
            self:_Report()
        end)

        self:_ScanEquipped()
        self:_ScanBags()
        self:_ScanCounts()
        self:_Report()
    end;

    Has = function(self, itemId)
        return self._items[itemId] == true
    end;

    Count = function(self, set)
        local held = 0
        for _, item in ipairs(set.items) do
            if self._items[item] then held = held + 1 end
        end
        return held, #set.items
    end;

    IsFavorite = function(self, setId)
        return self._favorites[setId] == true
    end;

    SetFavorite = function(self, setId, favorite)
        self._favorites[setId] = favorite and true or nil
        if self.OnChanged then self.OnChanged() end
    end;

    IsFavoriteMount = function(self, spell)
        return self._mounts[spell] == true
    end;

    SetFavoriteMount = function(self, spell, favorite)
        self._mounts[spell] = favorite and true or nil
        if self.OnMountsChanged then self.OnMountsChanged() end
    end;

    -- ---- internals --------------------------------------------------------

    _See = function(self, itemId)
        if itemId and not self._items[itemId] and MUI_ItemSetDB:GetSetsOfItem(itemId) then
            self._items[itemId] = true
            self._fresh = true
        end
    end;

    _Report = function(self)
        if not self._fresh then return end
        self._fresh = false
        if self.OnChanged then self.OnChanged() end
    end;

    _ScanContainer = function(self, container)
        for slot = 1, C_Container.GetContainerNumSlots(container) do
            self:_See(C_Container.GetContainerItemID(container, slot))
        end
    end;

    _ScanBags = function(self)
        for bag = 0, NUM_BAG_SLOTS do
            self:_ScanContainer(bag)
        end
    end;

    _ScanBank = function(self)
        self:_ScanContainer(BANK_CONTAINER)
        for bag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
            self:_ScanContainer(bag)
        end
    end;

    _ScanEquipped = function(self)
        for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
            self:_See(GetInventoryItemID("player", slot))
        end
    end;

    -- The bank lists its slots only while it is open; a count that takes the
    -- bank in is there anywhere, so the pieces lying in it are found at login.
    _ScanCounts = function(self)
        for _, set in ipairs(MUI_ItemSetDB:GetSets()) do
            for _, item in ipairs(set.items) do
                if not self._items[item] and (C_Item.GetItemCount(item, true) or 0) > 0 then
                    self:_See(item)
                end
            end
        end
    end;
}
