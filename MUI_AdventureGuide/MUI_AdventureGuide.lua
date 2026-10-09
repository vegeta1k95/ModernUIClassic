-- MUI_AdventureGuide: retail's Adventure Guide for Classic Era, which has no
-- dungeon journal — the window (MUI_AdventureGuideFrame) over our own data
-- (MUI_EncounterJournalDB: NewEra's dataset, see tools/encounterjournal_export.py):
--
--   MUI_AdventureGuideFrame       the window, its bar, tabs and navigation
--   MUI_AdventureGuideInstances   the grid of dungeons / raids
--   MUI_AdventureGuideEncounter   an instance's pages: bosses, lore, tabs
--   MUI_AdventureGuideSections    a boss's abilities
--   MUI_AdventureGuideLoot        loot lists and the slot filter
--   MUI_AdventureGuideModel       a boss in 3D
--   MUI_AdventureGuideSearch      the search box, its preview and results
--   MUI_AdventureGuideWidgets     scroll areas, side tabs, the breadcrumb bar
--   MUI_AdventureGuideStyle       scale, labels, art pieces
--
-- Of retail's guide this is the Dungeons and Raids tabs. Its other tabs
-- (Journeys, Traveler's Log, Suggested Content, Item Sets) are about systems
-- Era does not have; so are the difficulty and class filters.
--
-- The micro menu's Adventure Guide button opens the window; so do the
-- "Toggle Adventure Guide" key binding, /muiguide, and a boss's portrait on
-- a dungeon map (MUI_MapDungeonView), which opens it on that boss.

BINDING_NAME_MUI_TOGGLE_ADVENTUREGUIDE = "Toggle Adventure Guide"

object "ModuleAdventureGuide" : extends "Module" {
    __init = function(self)
        Module.__init(self, "AdventureGuide")
    end;

    OnEnable = function(self)
        self.window = AdventureGuideWindow()
        MUI_ModuleMicroMenu:WireAdventureGuide(self.window)

        ChatCommand("muiguide", function() self:Toggle() end)
    end;

    Toggle = function(self)
        self.window:Toggle()
    end;

    -- Open the guide on the boss a dungeon map shows with this creature
    -- display. Returns whether the journal has such a boss.
    OpenBoss = function(self, mapCode, display)
        local instance, encounter = MUI_EncounterJournalDB:FindByDisplay(mapCode, display)
        if not instance then return false end
        self.window:Show()
        self.window:Raise()
        self.window:ShowEncounter(instance, encounter)
        return true
    end;
}
