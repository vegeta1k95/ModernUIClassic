-- MUI_DB: Persistent database backed by MUI_SavedVars
-- Access directly: MUI_DB.settings.actionbars.lockBars = true
-- Initialized with defaults on ADDON_LOADED, merged with saved data

local DEFAULTS = {
    settings = {
        nameplates = {
            showLevel = true,
            questIcons = true,
        },
        minimapTracker = {
            filters = {
                Auctioneer         = true,
                Banker             = true,
                Battlemaster       = true,
                Stablemaster       = true,
                Innkeeper          = true,
                FlightMaster       = true,
                Repair             = true,
                Mailbox            = true,
                ProfessionTrainer  = true,
                ClassTrainer       = true,
                LowLevelQuests     = false,
            },
        },
        -- Generic focus state managed by MUI_FocusManager.
        --   kind = "quest" | "flightmaster" | ... | nil
        --   key  = questId | taxi nodeID | ...           | nil
        focus = {
            kind = nil,
            key  = nil,
        },
        questHelper = {

            -- Minimap
            showMinimapObjectivePins         = false,
            showMinimapObjectiveAreas        = true,
            showLowLevelAvailableQuests      = false,  -- minimap pins

            -- Quest Log
            showObjectivesInQuestLog         = true,
            showObjectivesOnMap              = true,
            showQuestLevel                   = false,
            showQuestDifficultyColor         = false,
            showLowLevelAvailableQuestsOnMap = false,  -- world-map pins
            showDungeonsOnMap                = true,
            questTypeIcons                   = true,   -- POI glyph by quest type (map / log / tracker)
            showZoneStory                    = true,   -- zone story banner atop the map quest log
            zoneStoryCollapsed               = false,
            autoCollapseQuestCategories      = false,

            -- Custom tracker state (see QuestTracker). Opt-out: every
            -- accepted quest is tracked by default; flipping the row's
            -- toggle un-tracks (adds to this table). The focused quest
            -- moved to settings.focus when MUI_FocusManager landed.
            untrackedQuests                  = {},
        },
        professions = {
            showLearned     = true,
            showUnlearned   = true,
        },
        spellbook = {
            showPassive     = true,
            showHeaderIcons = true,
        },
        bags = {
            combined = false,   -- join all bags into one window (retail-style)
        },
        -- Edit-mode layouts keyed by frame name: [name] = { points = {...}, scale = N }.
        -- Written by the edit-mode "Save" button, applied on PLAYER_ENTERING_WORLD.
        editmode = {},
        -- Edit-mode alignment grid (a display aid, not a per-frame layout).
        -- Toggled/sized from the Interface Settings panel; persists on change.
        editmodeGrid = {
            enabled = false,
            spacing = 50,
        },
    },
    data = {
        -- Recipes ticked "Track Recipe" in the profession window, as the
        -- quest tracker shows them: { spellID, name, reagents = { { itemID,
        -- count, name } } } (MUI_RecipeTracker).
        trackedRecipes = {},
        -- Achievement progress (MUI_AchievementEngine): what is earned and
        -- when, the trackers' tallies, kills and quests found, battleground
        -- columns, what is on the objective tracker.
        achievements = {
            earned     = {},
            counters   = {},
            sets       = {},
            tallies    = {},
            kills      = {},
            lockout    = {},
            qdone      = {},
            bg         = {},
            day        = { stamp = "", n = 0, best = 0 },
            tracked    = {},
            backfilled = false,
        },
        spells = {
            general = {},
            class = {
                {},     -- 1st spec
                {},     -- 2nd spec
                {},     -- 3rd spec
            },
            trainerServiceCount = 0,
        },
        -- Auction house (MUI_AuctionHouse): items starred in the browse list,
        -- keyed by item id, and the duration last used to post an auction.
        auctionHouse = {
            favorites    = {},
            sellDuration = 2,
        },
        -- Equipment sets (MUI_CharacterEquipment), in the order made:
        -- { name, icon, items = { [slot] = link }, ignored = { [slot] = true } }.
        equipmentSets = {},
        -- Collections (MUI_CollectionsLog): every set piece this character
        -- has held, [item id] = true, and the sets starred in the list,
        -- [set id] = true.
        collections = {
            items     = {},
            favorites = {},
        },
        -- [nodeID] = true for every taxi node the player has discovered.
        -- C_TaxiMap.GetTaxiNodesForMap doesn't expose discovery state in
        -- Classic Era (isUndiscovered is always false), so MapStaticPinManager
        -- captures it itself at TAXIMAP_OPENED via GetAllTaxiNodes.
        discoveredTaxiNodes = {},
    }
}

-- Deep merge: copies missing keys from defaults into target
local function MergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            MergeDefaults(target[k], v)
        else
            if target[k] == nil then
                target[k] = v
            end
        end
    end
end

-- One-time migrations that run after MergeDefaults populates structure.
-- Keep these idempotent: each migration checks if its work is already
-- done before applying.
local function RunMigrations(db)
    -- focusedQuest → settings.focus (MUI_FocusManager landed; quest focus
    -- is now one kind among many).
    local qh = db.settings and db.settings.questHelper
    if qh and qh.focusedQuest then
        db.settings.focus      = db.settings.focus or { kind = nil, key = nil }
        db.settings.focus.kind = "quest"
        db.settings.focus.key  = qh.focusedQuest
        qh.focusedQuest        = nil
    end
end

MUI_DB = {}
MUI_Mod:RegisterEventHandler("ADDON_LOADED", function(self, _, addonName)
    if addonName == "ModernUI" then
        if not MUI_SavedVars then
            MUI_SavedVars = {}
        end
        MergeDefaults(MUI_SavedVars, DEFAULTS)
        RunMigrations(MUI_SavedVars)
        MUI_DB = MUI_SavedVars
        self:UnregisterEventHandler("ADDON_LOADED")
    end
end)

-- Per-character SavedVariables are keyed by character NAME, so a deleted
-- character and a freshly created one with the same name share the same
-- file. Detect that mismatch by stamping class/race/name and wipe to
-- defaults when it changes. PLAYER_LOGIN is the earliest event where
-- UnitClass/UnitRace are reliable; modules' OnEnable runs later at
-- PLAYER_ENTERING_WORLD, so the wipe is safe here.
MUI_Mod:RegisterEventHandler("PLAYER_LOGIN", function(self)
    local _, classFile = UnitClass("player")
    local _, raceFile  = UnitRace("player")
    local name         = UnitName("player")
    if classFile and raceFile and name then
        local current = classFile .. "|" .. raceFile .. "|" .. name
        if MUI_SavedVars._identity and MUI_SavedVars._identity ~= current then
            wipe(MUI_SavedVars)
            MergeDefaults(MUI_SavedVars, DEFAULTS)
            MUI.Print("|cffffd200ModernUI:|r new character on this name slot, settings reset to defaults.")
        end
        MUI_SavedVars._identity = current
    end
    self:UnregisterEventHandler("PLAYER_LOGIN")
end)
