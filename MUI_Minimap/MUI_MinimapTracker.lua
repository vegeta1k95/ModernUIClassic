-- MinimapTracker: decides which pins live on the minimap based on the user's
-- filter settings (MUI_DB.settings.minimapTracker.filters) and the player's
-- current zone. Subscribes to zone changes and filter toggles, creates /
-- destroys MinimapPin instances accordingly.
--
-- Pins are built per top-level zone only: when the player enters a new zone
-- we tear down existing pins and rebuild from the DB using the zone's
-- spawn entries. Out-of-zone NPCs/objects are never pinned (minimap shows
-- player-centric context; cross-continent icons would be dead pixels).
--
-- Filter wiring: each DB filter flag maps to a matcher (by npcFlags bit,
-- by object name, or by domain-specific rule) and an icon type string.
-- When a filter flips on, we find matching entries in the current zone and
-- spawn a pin each; when it flips off, we destroy that filter's pins.
--
-- The MUI_MinimapTrackerMenu (the dropdown UI) already writes to
-- MUI_DB.settings.minimapTracker.filters on user click — this module just
-- reacts.

-- NPC-flag bits as used in Questie's Classic Era DB (see Questie's
-- Database/npcDB.lua:59-79 `QuestieDB.npcFlags` Classic branch). These are
-- NOT Blizzard's UNIT_NPC_FLAG_* values — Questie packs the Classic set
-- into a smaller bitmask. E.g. Innkeeper Farley's stored npcFlags=135 =
-- 1+2+4+128 = GOSSIP + QUEST_GIVER + VENDOR + INNKEEPER.

local NPC_FLAG_GOSSIP       = 1
local NPC_FLAG_QUESTGIVER   = 2
local NPC_FLAG_VENDOR       = 4
local NPC_FLAG_FLIGHTMASTER = 8
local NPC_FLAG_TRAINER      = 16
local NPC_FLAG_INNKEEPER    = 128
local NPC_FLAG_BANKER       = 256
local NPC_FLAG_AUCTIONEER   = 4096
local NPC_FLAG_REPAIR       = 16384

local function hasFlag(mask, flag)
    if not mask then return false end
    return (mask % (flag * 2)) >= flag   -- bitwise AND without bit-lib
end


-- Class-trainer NPC IDs for Classic Era, per class, ported verbatim from
-- Questie's Modules/QuestieMenu/ClassTrainers.lua (Classic branch). Keyed
-- by Blizzard's class filename (the second return of UnitClass) so we can
-- filter to the player's own class.
local CLASS_TRAINER_IDS = {
    WARRIOR = {911,912,913,914,985,1229,1901,2119,2131,3041,3042,3043,3059,
               3063,3153,3169,3353,3354,3408,3593,3598,4087,4089,4593,4594,
               4595,5113,5114,5479,5480,7315,8141,16387},
    PALADIN = {925,926,927,928,1232,5147,5148,5149,5491,5492,8140},
    HUNTER  = {895,987,1231,1404,3038,3039,3040,3061,3065,3154,3171,3352,
               3406,3407,3596,3601,3963,4138,4146,4205,5115,5116,5117,5501,
               5515,5516,5517,8308,10930,
               -- Pet Trainers (also useful to hunters)
               543,2878,2879,3306,3545,3620,3622,3624,3688,3698,4320,10086,
               10088,10089,10090},
    ROGUE   = {915,916,917,918,1234,1411,2122,2130,3155,3170,3327,3328,
               3401,3594,3599,4163,4214,4215,4582,4583,4584,5165,5166,5167,
               13283},
    PRIEST  = {375,376,377,837,1226,2123,2129,3044,3045,3046,3595,3600,3706,
               3707,4090,4091,4092,4606,4607,4608,5141,5142,5143,5484,5489,
               5994,6014,6018,11397,11401,11406},
    SHAMAN  = {986,3030,3031,3032,3062,3066,3157,3173,3344,3403,13417},
    MAGE    = {198,313,328,331,944,1228,2124,2128,3047,3048,3049,4566,4567,
               4568,5144,5145,5146,5497,5498,5880,5882,5883,5884,5885,7311,
               7312},
    WARLOCK = {459,460,461,906,988,2126,2127,3156,3172,3324,3325,3326,4563,
               4564,4565,5171,5172,5173,5495,5496,5612,
               -- Demon Trainers (also useful to warlocks)
               5520,5749,5750,5753,5815,6027,6328,6373,6374,6376,6382,
               12776,12807},
    DRUID   = {3033,3034,3036,3060,3064,3597,3602,4217,4218,4219,5504,5505,
               5506,8142,9465,12042},
}

-- Profession-trainer NPC IDs for Classic Era, ported verbatim from
-- Questie's Modules/QuestieMenu/ProfessionTrainers.lua (Classic branch).
local PROFESSION_TRAINER_IDS = {
    223,514,812,908,957,1103,1215,1218,1241,1246,1292,1300,1317,1346,1355,
    1382,1383,1385,1386,1430,1458,1466,1470,1473,1632,1651,1676,1680,1681,
    1683,1699,1700,1701,1702,1703,2114,2132,2326,2327,2329,2367,2390,2391,
    2399,2627,2704,2737,2798,2818,2834,2836,2837,2855,2856,2857,2998,3001,
    3004,3007,3008,3009,3011,3013,3026,3028,3067,3069,3087,3136,3137,3174,
    3175,3179,3181,3184,3185,3290,3332,3345,3347,3355,3357,3363,3365,3373,
    3399,3404,3412,3478,3484,3494,3523,3530,3531,3549,3555,3557,3603,3604,
    3605,3606,3607,3703,3704,3964,3965,3967,4156,4159,4160,4193,4204,4210,
    4211,4212,4213,4254,4258,4552,4573,4576,4578,4586,4588,4591,4596,4598,
    4605,4609,4611,4614,4616,4898,4900,5127,5137,5150,5153,5157,5159,5161,
    5164,5174,5177,5392,5482,5493,5499,5500,5502,5511,5513,5518,5564,5566,
    5567,5690,5695,5759,5784,5811,5938,5939,5941,5943,6094,6286,6287,6288,
    6289,6290,6291,6292,6295,6297,6299,6306,6387,7087,7088,7089,7230,7231,
    7232,7406,7866,7867,7868,7869,7870,7871,7944,7946,7948,7949,8126,8128,
    8144,8146,8153,8306,8736,8738,9584,10266,10276,10277,10278,10993,11017,
    11025,11026,11028,11029,11031,11037,11041,11042,11044,11046,11047,
    11048,11049,11050,11051,11052,11065,11066,11067,11068,11070,11071,
    11072,11073,11074,11081,11083,11084,11096,11097,11098,11146,11177,
    11178,11865,11866,11867,11868,11869,11870,12025,12030,12032,12920,
    12939,12961,13084,14401,14740,
}

-- Build per-class sets for O(1) membership. Player's own class set is
-- resolved at OnEnable time (when UnitClass("player") is reliable) into
-- `_PLAYER_CLASS_TRAINER_SET`.
local _CLASS_TRAINER_SETS = {}
for class, ids in pairs(CLASS_TRAINER_IDS) do
    local set = {}
    for _, id in ipairs(ids) do set[id] = true end
    _CLASS_TRAINER_SETS[class] = set
end
local _PLAYER_CLASS_TRAINER_SET = {}   -- populated in OnEnable

local _PROFESSION_TRAINER_SET = {}
for _, id in ipairs(PROFESSION_TRAINER_IDS) do _PROFESSION_TRAINER_SET[id] = true end


-- Filter spec: each key in MUI_DB.settings.minimapTracker.filters maps here.
-- `match(npc)`   — returns true if this NPC is tracked by the filter.
-- `icon`         — MUI_MinimapPinIcons type name applied to each pin.
-- NPC-only filters iterate MUI_NpcDB:GetAll(); object filters iterate MUI_ObjectDB:GetAll().
local FILTERS = {
    Auctioneer = {
        source = "npcs",
        icon   = "Auctioneer",
        match  = function(e) return hasFlag(e.npcFlags, NPC_FLAG_AUCTIONEER) end,
    },
    Banker = {
        source = "npcs",
        icon   = "Banker",
        match  = function(e) return hasFlag(e.npcFlags, NPC_FLAG_BANKER) end,
    },
    Innkeeper = {
        source = "npcs",
        icon   = "Innkeeper",
        match  = function(e) return hasFlag(e.npcFlags, NPC_FLAG_INNKEEPER) end,
    },
    FlightMaster = {
        source = "npcs",
        icon   = "FlightMaster",
        match  = function(e) return hasFlag(e.npcFlags, NPC_FLAG_FLIGHTMASTER) end,
    },
    Repair = {
        source = "npcs",
        icon   = "Repair",
        match  = function(e) return hasFlag(e.npcFlags, NPC_FLAG_REPAIR) end,
    },
    Mailbox = {
        source = "objects",
        icon   = "Mailbox",
        match  = function(e) return e.name == "Mailbox" end,
    },
    -- Subname-based heuristics misclassify — profession trainers and class
    -- trainers often share TRAINER flag and similar subName wording. Questie
    -- keeps explicit NPC-ID lists for each category; we port those lists.
    ProfessionTrainer = {
        source = "npcs",
        icon   = "ProfessionTrainer",
        match  = function(e, id) return _PROFESSION_TRAINER_SET[id] == true end,
    },
    ClassTrainer = {
        source = "npcs",
        icon   = "ClassTrainer",
        match  = function(e, id) return _PLAYER_CLASS_TRAINER_SET[id] == true end,
    },
    LowLevelQuests = {
        -- TODO: requires iterating quests, not NPCs/objects. Deferred —
        -- placeholder that produces zero pins for now so the filter toggle
        -- doesn't error out.
        source = "none",
        icon   = "QuestAvailable",
        match  = function() return false end,
    },
}


object "MinimapTracker" : extends "Module" {
    __init = function(self)
        Module.__init(self, "MinimapTracker")
        -- pins[filterKey] = { [entityId] = MinimapPin, ... }
        self.pins = {}
        -- Last top-level areaId we built pins for; re-used to decide whether
        -- a zone change actually needs a rebuild.
        self.currentAreaId = nil
    end;

    OnEnable = function(self)
        -- UnitClass is reliable by PLAYER_ENTERING_WORLD (when Module
        -- dispatches OnEnable). Pick up the player's class-trainer set.
        local _, classFile = UnitClass("player")
        _PLAYER_CLASS_TRAINER_SET = _CLASS_TRAINER_SETS[classFile] or {}
        self:_WireEvents()
        self:Rebuild()
    end;

    _WireEvents = function(self)
        local driver = Frame("Frame", nil, "MUI_MinimapTrackerDriver")
        driver:RegisterEventHandler("ZONE_CHANGED_NEW_AREA", function()
            self:_MaybeRebuildForZone()
        end)
        driver:RegisterEventHandler("ZONE_CHANGED", function()
            self:_MaybeRebuildForZone()
        end)
        driver:RegisterEventHandler("PLAYER_ENTERING_WORLD", function()
            self:_MaybeRebuildForZone()
        end)
    end;

    -- Called externally (by the tracker menu) whenever the user toggles a
    -- filter checkbox. Only rebuilds the affected filter rather than the
    -- whole pin set.
    OnFilterChanged = function(self, filterKey, enabled)
        if enabled then
            self:_BuildFilter(filterKey)
        else
            self:_DestroyFilter(filterKey)
        end
    end;

    -- Full rebuild: destroy all pins, then re-add for each currently-enabled
    -- filter. Called on zone change and at OnEnable. FlightMaster is built
    -- unconditionally — it has no menu checkbox, the player always needs
    -- to see where to fly from.
    Rebuild = function(self)
        self:_DestroyAll()
        local filters = MUI_DB.settings.minimapTracker.filters or {}
        for key, enabled in pairs(filters) do
            if enabled then self:_BuildFilter(key) end
        end
        if not filters.FlightMaster then
            self:_BuildFilter("FlightMaster")
        end
    end;

    -- ---- internal helpers ------------------------------------------------

    _MaybeRebuildForZone = function(self)
        local areaId = self:_CurrentAreaId()
        if areaId == self.currentAreaId then return end
        self.currentAreaId = areaId
        self:Rebuild()
    end;

    _CurrentAreaId = function(self)
        local uiMapId = C_Map.GetBestMapForUnit("player")
        if not uiMapId then return nil end
        return MUI_ZoneDB:GetAreaForUiMap(uiMapId)
    end;

    _BuildFilter = function(self, key)
        local spec = FILTERS[key]
        if not spec or spec.source == "none" then return end

        local areaId = self:_CurrentAreaId()
        if not areaId then return end
        local uiMapId = MUI_ZoneDB:GetUiMapForArea(areaId)
        if not uiMapId then return end

        -- Already built? Rebuild idempotently.
        self:_DestroyFilter(key)
        local bucket = {}
        self.pins[key] = bucket

        local dbTable = (spec.source == "npcs") and MUI_NpcDB:GetAll() or MUI_ObjectDB:GetAll()
        if not dbTable then return end

        for id, entry in pairs(dbTable) do
            if spec.match(entry, id) then
                local spawns = entry.spawns and entry.spawns[areaId]
                if spawns then
                    for i, coord in ipairs(spawns) do
                        local pinName = "MUI_Tracker_" .. key .. "_" .. id .. "_" .. i
                        local pin = MinimapPin(pinName, 12)
                        pin:SetIconType(spec.icon)
                        pin:SetWorldPosition(uiMapId, coord[1] / 100, coord[2] / 100)
                        -- Click-through: hover detection is purely geometric
                        -- via MUI_MinimapTooltip; capturing mouse focus would
                        -- make WoW auto-hide the shared tooltip.
                        pin:EnableMouse(false)

                        local npcName = entry.name
                        local npcSub  = entry.subName
                        -- Per-filter tooltip style:
                        --   ClassTrainer / ProfessionTrainer: the subName
                        --     ("Warrior Trainer", "Expert Leatherworker")
                        --     is the meaningful label; drop the name.
                        --   Innkeeper / FlightMaster: the name is enough
                        --     ("Innkeeper Farley", "Gryth Thurden"); the
                        --     subName repeats the category icon.
                        --   Everything else: name + subName as line 2.
                        local subAsTitle = (key == "ClassTrainer"
                                         or key == "ProfessionTrainer")
                        local nameOnly   = (key == "Innkeeper"
                                         or key == "FlightMaster"
                                         or key == "Repair")
                        MUI_MinimapTooltip:Register(pinName, {
                            isHovered = function()
                                return MouseIsOver(Minimap)
                                   and pin:IsShown()
                                   and pin:GetAlpha() > 0.05
                                   and pin:IsMouseOver()
                            end,
                            build = function()
                                -- Dedup against existing tooltip lines: cursor jitter
                                -- while WoW's native blip tooltip is open can trigger
                                -- append-mode re-augmentation of the same pin.
                                local titleText
                                if subAsTitle and npcSub and npcSub ~= "" then
                                    titleText = npcSub
                                else
                                    titleText = npcName or "?"
                                end
                                if not MUI_Tooltip:HasLine(titleText) then
                                    MUI_Tooltip:AddTitle(titleText)
                                end
                                if not subAsTitle and not nameOnly
                                   and npcSub and npcSub ~= ""
                                   and not MUI_Tooltip:HasLine(npcSub) then
                                    MUI_Tooltip:AddLine(npcSub, 0.7, 0.7, 0.7)
                                end
                            end,
                        })

                        bucket[#bucket + 1] = { pin = pin, tooltipId = pinName }
                    end
                end
            end
        end
    end;

    _DestroyFilter = function(self, key)
        local bucket = self.pins[key]
        if not bucket then return end
        for _, e in ipairs(bucket) do
            if e.tooltipId then
                MUI_MinimapTooltip:Unregister(e.tooltipId)
            end
            e.pin:Destroy()
        end
        self.pins[key] = nil
    end;

    _DestroyAll = function(self)
        for key in pairs(self.pins) do
            self:_DestroyFilter(key)
        end
    end;
}
