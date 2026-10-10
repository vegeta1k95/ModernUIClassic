-- MUI_Collections: retail's Collections window for Classic Era, which has no
-- collections of its own — the window (MUI_CollectionsFrame) over the game's
-- mounts (MUI_MountDB, see tools/mounts_export.py) and item sets
-- (MUI_ItemSetDB, see tools/itemsets_export.py), and our own record of the
-- set pieces the character has held:
--
--   MUI_CollectionsFrame          the window and its tabs
--   MUI_CollectionsMounts         the mounts page: search, filters, the Mount button
--   MUI_CollectionsMountList      the list of mounts
--   MUI_CollectionsMountDisplay   the mount on show: the model, where it comes from
--   MUI_CollectionsSets           the sets page: search, filters, progress
--   MUI_CollectionsSetList        the list of sets
--   MUI_CollectionsSetDetails     the set on show: the model, its pieces
--   MUI_CollectionsLog            the pieces ever held, the sets and mounts starred
--   MUI_CollectionsStyle          scale, labels, art pieces
--
-- Of retail's window these are the Mounts tab and the Sets tab of
-- Appearances. Its other pages are about things Era has no system for (pets,
-- toys, heirlooms, the appearances of single items).
--
-- The micro menu's Collections button opens the window; so do the "Toggle
-- Collections" key binding and /muicollections.

BINDING_NAME_MUI_TOGGLE_COLLECTIONS = BINDING_NAME_TOGGLECOLLECTIONS

object "ModuleCollections" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Collections")
    end;

    OnEnable = function(self)
        MUI_CollectionsLog:Start()
        self.window = CollectionsWindow()
        MUI_ModuleMicroMenu:WireCollections(self.window)

        -- A click on a window of ours raises it over an open dressing room,
        -- which comes forward by itself only as it opens: bring it forward
        -- whenever it is given something to show.
        local dressingRoom = Frame(DressUpFrame)
        hooksecurefunc("DressUpVisual", function()
            if dressingRoom:IsShown() then dressingRoom:Raise() end
        end)

        ChatCommand("muicollections", function() self:Toggle() end)
    end;

    Toggle = function(self)
        self.window:Toggle()
    end;
}
