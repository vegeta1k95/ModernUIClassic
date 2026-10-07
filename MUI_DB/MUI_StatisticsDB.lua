-- StatisticsDB: the Statistics tab's content — retail's statistics tree
-- (Blizzard's STATISTIC-flagged achievements) cut down to what Classic Era
-- has, plus a few of NewEra's own. Era has no GetStatistic: every value is
-- one of MUI_AchievementEngine's tallies, fed by MUI_StatisticsTrackers, or
-- is read live off the character (skills, honorable kills).
--
-- A category: { id, name, parent? }. A statistic: { cat, name, key, kind?,
-- fmt?, skill? }; `kind` says how the engine reads `key`:
--   nil        counters[key] — totals, and the maxima the trackers keep
--   "kinds"    how many different kinds tallies[key] holds
--   "top"      the kind with the highest tally, as "Name (n)"
--   "set"      how many entries sets[key] holds
--   "perday"   counters[key] over the days the tallies have been running
--   "skill"    the current rank of skill line `skill`
--   "skillmax" the highest rank seen for skill line `skill`
--   "hk"       lifetime honorable kills, from the client
-- `fmt` is "money" (the value is copper) or "pct" (a speed, as % of run speed).

object "StatisticsDB" {
    __init = function(self)
        self._categories = {
            { id = 1,  name = "Character" },
            { id = 11, name = "Wealth",           parent = 1 },
            { id = 12, name = "Consumables",      parent = 1 },
            { id = 2,  name = "Kills" },
            { id = 21, name = "Creatures",        parent = 2 },
            { id = 22, name = "Honorable Kills",  parent = 2 },
            { id = 23, name = "Killing Blows",    parent = 2 },
            { id = 3,  name = "Deaths" },
            { id = 4,  name = "Quests" },
            { id = 5,  name = "Skills" },
            { id = 51, name = "Secondary Skills", parent = 5 },
            { id = 52, name = "Professions",      parent = 5 },
            { id = 6,  name = "Travel" },
            { id = 7,  name = "Social" },
            { id = 8,  name = "Dungeons & Raids" },
            { id = 81, name = "Dungeons",         parent = 8 },
            { id = 82, name = "Raids",            parent = 8 },
            { id = 9,  name = "Player vs. Player" },
            { id = 91, name = "Battlegrounds",    parent = 9 },
            { id = 92, name = "World",            parent = 9 },
        }

        -- { npcId, boss, instance, isRaid }: the final boss of every Era instance
        self._bosses = {
            { 11520, "Taragaman the Hungerer",    "Ragefire Chasm" },
            { 3654,  "Mutanus the Devourer",      "Wailing Caverns" },
            { 639,   "Edwin VanCleef",            "The Deadmines" },
            { 4275,  "Archmage Arugal",           "Shadowfang Keep" },
            { 4829,  "Aku'mai",                   "Blackfathom Deeps" },
            { 1716,  "Bazil Thredd",              "The Stockade" },
            { 7800,  "Mekgineer Thermaplugg",     "Gnomeregan" },
            { 4421,  "Charlga Razorflank",        "Razorfen Kraul" },
            { 3977,  "High Inquisitor Whitemane", "Scarlet Monastery" },
            { 7358,  "Amnennar the Coldbringer",  "Razorfen Downs" },
            { 2748,  "Archaedas",                 "Uldaman" },
            { 7267,  "Chief Ukorz Sandscalp",     "Zul'Farrak" },
            { 12201, "Princess Theradras",        "Maraudon" },
            { 5709,  "Shade of Eranikus",         "Sunken Temple" },
            { 9019,  "Emperor Dagran Thaurissan", "Blackrock Depths" },
            { 9568,  "Overlord Wyrmthalak",       "Lower Blackrock Spire" },
            { 10363, "General Drakkisath",        "Upper Blackrock Spire" },
            { 10440, "Baron Rivendare",           "Stratholme" },
            { 1853,  "Darkmaster Gandling",       "Scholomance" },
            { 11501, "King Gordok",               "Dire Maul" },
            { 10184, "Onyxia",                    "Onyxia's Lair",       true },
            { 14834, "Hakkar",                    "Zul'Gurub",           true },
            { 15339, "Ossirian the Unscarred",    "Ruins of Ahn'Qiraj",  true },
            { 11502, "Ragnaros",                  "Molten Core",         true },
            { 11583, "Nefarian",                  "Blackwing Lair",      true },
            { 15727, "C'Thun",                    "Temple of Ahn'Qiraj", true },
            { 15990, "Kel'Thuzad",                "Naxxramas",           true },
        }

        local list = {}
        local function add(cat, name, key, kind, fmt, skill)
            list[#list + 1] = { cat = cat, name = name, key = key, kind = kind, fmt = fmt, skill = skill }
        end

        -- Character
        add(1, "Items looted", "itemsLooted")
        add(1, "Epic items looted", "epicsLooted")
        add(1, "Books read", "books", "set")
        add(1, "Falls survived (>50% health)", "fallsSurvived")
        -- Wealth
        add(11, "Total gold acquired", "goldTotal", nil, "money")
        add(11, "Average gold earned per day", "goldTotal", "perday", "money")
        add(11, "Gold looted", "goldLoot", nil, "money")
        add(11, "Gold from quest rewards", "goldQuest", nil, "money")
        add(11, "Gold earned from auctions", "goldAuction", nil, "money")
        add(11, "Auctions posted", "auctionsPosted")
        add(11, "Auction purchases", "auctionsBought")
        add(11, "Most expensive bid on auction", "auctionBidMax", nil, "money")
        add(11, "Most expensive auction sold", "auctionSoldMax", nil, "money")
        add(11, "Gold from vendors", "goldVendor", nil, "money")
        add(11, "Gold spent on travel", "goldTaxi", nil, "money")
        add(11, "Gold spent on postage", "goldPostage", nil, "money")
        add(11, "Most gold ever owned", "goldMax", nil, "money")
        -- Consumables
        add(12, "Bandages used", "bandages")
        add(12, "Bandage used most", "bandageKinds", "top")
        add(12, "Different bandage types used", "bandageKinds", "kinds")
        add(12, "Health potions consumed", "healthPotions")
        add(12, "Health potion used most", "healthPotionKinds", "top")
        add(12, "Different health potions used", "healthPotionKinds", "kinds")
        add(12, "Mana potions consumed", "manaPotions")
        add(12, "Mana potion used most", "manaPotionKinds", "top")
        add(12, "Different mana potions used", "manaPotionKinds", "kinds")
        add(12, "Elixirs consumed", "elixirs")
        add(12, "Elixir consumed most", "elixirKinds", "top")
        add(12, "Different elixirs used", "elixirKinds", "kinds")
        add(12, "Flasks consumed", "flasks")
        add(12, "Flask consumed most", "flaskKinds", "top")
        add(12, "Different flasks consumed", "flaskKinds", "kinds")
        add(12, "Beverages consumed", "drinks")
        add(12, "Beverage consumed most", "drinkKinds", "top")
        add(12, "Different beverages consumed", "drinkKinds", "kinds")
        add(12, "Food eaten", "foods")
        add(12, "Food eaten most", "foodKinds", "top")
        add(12, "Different foods eaten", "foodKinds", "kinds")
        add(12, "Healthstones used", "healthstones")
        -- Kills
        add(21, "Creatures killed", "creaturesKilled")
        add(21, "Different creature types killed", "creatureTypes", "kinds")
        add(21, "Creature type killed the most", "creatureTypes", "top")
        add(21, "Critters killed", "crittersKilled")
        add(22, "Total Honorable Kills", "hk", "hk")
        add(22, "World Honorable Kills", "hkWorld")
        add(22, "Battleground Honorable Kills", "hkBG")
        add(22, "Alterac Valley Honorable Kills", "hk_av")
        add(22, "Arathi Basin Honorable Kills", "hk_ab")
        add(22, "Warsong Gulch Honorable Kills", "hk_wsg")
        add(23, "Total Killing Blows", "kb")
        add(23, "World Killing Blows", "kbWorld")
        add(23, "Battleground Killing Blows", "kbBG")
        add(23, "Alterac Valley Killing Blows", "kb_av")
        add(23, "Arathi Basin Killing Blows", "kb_ab")
        add(23, "Warsong Gulch Killing Blows", "kb_wsg")
        -- Deaths
        add(3, "Total deaths", "deaths")
        add(3, "Deaths from drowning", "deathDrowning")
        add(3, "Deaths from fatigue", "deathFatigue")
        add(3, "Deaths from falling", "deathFalling")
        add(3, "Deaths from fire and lava", "deathFireLava")
        add(3, "Resurrected by priests", "resPriest")
        add(3, "Rebirthed by druids", "resDruid")
        add(3, "Spirit returned to body by shamans", "resShaman")
        add(3, "Redeemed by paladins", "resPaladin")
        add(3, "Resurrected by soulstones", "resSoulstone")
        add(3, "Deaths in Alterac Valley", "deaths_av")
        add(3, "Deaths in Arathi Basin", "deaths_ab")
        add(3, "Deaths in Warsong Gulch", "deaths_wsg")
        add(3, "Group member deaths witnessed", "groupDeaths")
        -- Quests
        add(4, "Quests completed", "qcount")
        add(4, "Average quests completed per day", "quests", "perday")
        add(4, "Quests abandoned", "questsAbandoned")
        -- Skills
        add(51, "Cooking skill", "skill_Cooking", "skill", nil, "Cooking")
        add(51, "Cooking Recipes known", "recipes_Cooking")
        add(51, "First Aid skill", "skill_First Aid", "skill", nil, "First Aid")
        add(51, "First Aid Manuals learned", "recipes_First Aid")
        add(51, "Fishing skill", "skill_Fishing", "skill", nil, "Fishing")
        add(51, "Fish caught", "fish")
        add(51, "Fish and other things caught", "fishAll")
        local professions = {
            { "Alchemy",        "Alchemy Recipes learned" },
            { "Blacksmithing",  "Blacksmithing Plans learned" },
            { "Enchanting",     "Enchanting formulae learned" },
            { "Engineering",    "Engineering Schematics learned" },
            { "Herbalism" },
            { "Leatherworking", "Leatherworking Patterns learned" },
            { "Mining",         "Smelting Recipes learned", "Smelting" },
            { "Skinning" },
            { "Tailoring",      "Tailoring Patterns learned" },
        }
        for _, p in ipairs(professions) do
            add(52, "Highest " .. p[1] .. " skill", "skillmax_" .. p[1], "skillmax", nil, p[1])
            if p[2] then add(52, p[2], "recipes_" .. (p[3] or p[1])) end
            if p[1] == "Enchanting" then
                add(52, "Materials produced from disenchanting", "disenchantMats")
                add(52, "Items disenchanted", "disenchants")
            end
        end
        -- Travel
        add(6, "Flight paths taken", "flights")
        add(6, "Summons accepted", "summons")
        add(6, "Mage Portals taken", "portals")
        add(6, "Mage portal taken most", "portalKinds", "top")
        add(6, "Number of times hearthed", "hearths")
        add(6, "Fastest recorded run speed", "speedTop", nil, "pct")
        -- Social
        add(7, "Number of hugs", "hugs")
        add(7, "Total facepalms", "facepalms")
        add(7, "Total times playing world's smallest violin", "violins")
        add(7, "Total times LOL'd", "lols")
        add(7, "Total cheers", "cheers")
        add(7, "Total waves", "waves")
        -- Dungeons & Raids
        add(8, "Dungeon and raid bosses slain", "bossesSlain")
        for _, b in ipairs(self._bosses) do
            add(b[4] and 82 or 81, b[2] .. " kills (" .. b[3] .. ")", "boss_" .. b[1])
        end
        -- Player vs. Player
        add(91, "Battlegrounds played", "bgPlayed")
        add(91, "Battlegrounds won", "bgWon")
        add(91, "Alterac Valley battles", "bg_av")
        add(91, "Alterac Valley victories", "bgwin_av")
        add(91, "Alterac Valley towers captured", "avTowersCaptured")
        add(91, "Alterac Valley towers defended", "avTowersDefended")
        add(91, "Arathi Basin battles", "bg_ab")
        add(91, "Arathi Basin victories", "bgwin_ab")
        add(91, "Warsong Gulch battles", "bg_wsg")
        add(91, "Warsong Gulch victories", "bgwin_wsg")
        add(91, "Warsong Gulch flags captured", "wsgCaps")
        add(91, "Warsong Gulch flags returned", "wsgReturns")
        add(92, "Duels won", "duelsWon")
        add(92, "Duels lost", "duelsLost")

        self._list = list
    end;

    GetCategories = function(self) return self._categories end;
    GetAll = function(self) return self._list end;
    GetFinalBosses = function(self) return self._bosses end;
}
