-- MUI_AchievementEngine: the achievement system's state and rules — Era has
-- no backend for it. Definitions come from MUI_AchievementDB; progress lives
-- in MUI_DB.data.achievements, per character:
--   earned[id] = { t = epoch, bf = true | nil }   bf: granted by the silent first sweep
--   counters[name] = number        forward-only tallies the trackers feed
--   sets[name][key] = true         "different X" collections
--   tallies[name][kind] = number   per-kind counts ("X used most")
--   kills[npcId] = epoch           boss and rare kills with credit
--   lockout[npcId] = epoch         raid boss kills, for one-lockout clears
--   qdone[questId] = true          countable quests found complete
--   bg[key] = { cols = {} }        a battleground's scoreboard columns, summed
--   day = { stamp, n, best }       quests turned in today, and the record
--   tracked = { id, ... }          on the objective tracker, 10 at most
--   backfilled = true              the first sweep has run
--   statsSince = epoch             when the statistics started counting
--   schema = SCHEMA                the definitions this store was built for
--
-- Criteria evaluators (CRIT) each answer (done, rows) for a definition's
-- `crit`. The rows describe the objectives pane: { label, done } is a check
-- line, `bar = { cur, max, text }` makes it a progress bar, `meta = id`
-- marks a member of a meta achievement. CRIT_GROUP maps a criteria type to
-- the dirty group a tracker marks when its inputs change; Dirty(group)
-- re-evaluates the group's unearned achievements and awards what is met.
-- "Live" criteria read the character (level, quest flags, reputation,
-- skills, spells, bags) and so backfill on every login's sweep; tally
-- criteria accumulate from the trackers, forward from install.
--
-- Query methods follow retail's GetAchievementInfo and friends, so the
-- panel can be a transcription of Blizzard_AchievementUI.

local L = MUI.L

local SCHEMA = 2         -- the first store held a mock-up; this one NewEra's set
local MAX_TRACKED = 10
local DAY = 86400

local function barRow(label, cur, max)
    cur = math.min(cur or 0, max)
    return { label = label, done = cur >= max, bar = { cur = cur, max = max, text = cur .. " / " .. max } }
end

-- Check lines for a list of entries, each judged by `isDone(entry)`.
local function listRows(list, isDone)
    local rows, all = {}, true
    for _, entry in ipairs(list) do
        local done = isDone(entry)
        if not done then all = false end
        rows[#rows + 1] = { label = entry.label, done = done }
    end
    return all, rows
end

local function anyItemOwned(ids)
    for _, id in ipairs(ids) do
        if (C_Item.GetItemCount(id, true) or 0) > 0 then return true end
    end
    return false
end

-- A spell the game replaced with its successor (Bear Form) still counts.
local function anySpellKnown(ids)
    for _, id in ipairs(ids) do
        if C_SpellBook.IsSpellKnown(id) or MUI_Spells:IsReplaced(id) then return true end
    end
    return false
end

-- Check lines for an item set's pieces, by name.
local function itemSetRows(set)
    if not set then return false, nil end
    local rows, all = {}, true
    for _, id in ipairs(set.items) do
        local owned = (C_Item.GetItemCount(id, true) or 0) > 0
        if not owned then all = false end
        rows[#rows + 1] = { label = C_Item.GetItemInfo(id) or RETRIEVING_ITEM_INFO, done = owned }
    end
    return all, rows
end

-- standing 1..8 for a faction id, nil when the character has never met it
local function repStanding(factionId)
    local name, _, standing = GetFactionInfoByID(factionId)
    if name then return standing end
    return nil
end

local function exaltedCount()
    local n = 0
    for i = 1, GetNumFactions() do
        local _, _, standing, _, _, _, _, _, isHeader = GetFactionInfo(i)
        if not isHeader and standing == 8 then n = n + 1 end
    end
    return n
end

-- skill line categories (MUI_SkillLineDB)
local WEAPON_SKILLS, SECONDARY_SKILLS, PROFESSIONS = 6, 9, 11
local MINING, SMELTING = 186, 2656

-- skill lines by id, with their category: a row names its line in the
-- client's language and MUI_SkillLineDB tells which it is; modifier is the
-- temporary bonus from gear and enchants
local function skillScan()
    local out = {}
    for i = 1, GetNumSkillLines() do
        local name, isHeader, _, rank, _, modifier = GetSkillLineInfo(i)
        local id, cat = MUI_SkillLineDB:GetByName(name)
        if id and not isHeader then
            out[id] = { rank = rank or 0, cat = cat, modifier = modifier or 0 }
        end
    end
    return out
end

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
-- UnitRace's race tokens by ChrRaces id, which the client names.
local RACE_ID = { Human = 1, Orc = 2, Dwarf = 3, NightElf = 4, Scourge = 5, Tauren = 6, Gnome = 7, Troll = 8 }
local EPIC_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
-- the class mounts are spells, not bag items: Felsteed, Summon Warhorse,
-- Dreadsteed, Summon Charger
local CLASS_MOUNTS      = { 5784, 13819, 23161, 23214 }
local CLASS_MOUNTS_EPIC = { 23161, 23214 }

-- criteria type -> dirty group, or a list of them
local CRIT_GROUP = {
    level = "level", mount = { "bags", "spells" }, skillCount = "skills", skill = "skills",
    banks = "banks", companions = "bags", fall = "fall", use = "use", book = "book",
    emoteLove = "emote", kill = { "kills", "quests" }, quest = "quests", meta = "meta", speed = "speed",
    qcount = "quests", qzone = "quests", qstory = "quests", questAll = "quests",
    questMoney = "quests", questsDay = "quests", explore = "explore", killAll = { "kills", "quests" },
    killTimed = "kills", aura = "aura", timedBoss = "kills", nodeaths = "kills",
    questOrItem = "quests", invAll = "bags", killLockout = "kills",
    rep = "rep", repCount = "rep", repAll = "rep", repAny = "rep", repAndItem = "rep",
    profAny = "skills", profBoth = "skills", recipes = "recipes", create = "loot",
    bandage = "bandage", fishSchool = "loot", fish = "loot", loot = "loot", gather = "loot",
    castSpell = "cast", createQuality = "loot", moneyLoot = "money", moneyHeld = "money",
    lootQuality = "loot", epicSlots = "equip", lootCount = "loot",
    killCount = "kills", lootOrInv = "loot", lootName = "loot", hk = "pvp", duel = "pvp",
    kb = "pvp", bgstat = "bg", rank = "pvp", inv = "bags", bgwin = "bg", bgcol = "bg",
    wsgcap = "bg", quickcap = "bg", perfection = "bg", ironman = "bg",
    spell = "spells", spellAll = "spells", petFamilies = "pet",
    petRare = "pet", castCount = "cast",
    critterHit = "critter", dmfTickets = "dmf", dmfDeck = "dmf", skillOver = "skills",
    auraAll = "aura", selfKill = "death", envDeath = "death", drunk = "drunk",
    nakedKill = "kills", roll1 = "roll", roll100 = "roll", bubbleHearth = "cast", clutchHeal = "bandage",
    pvpSet = "bags", ds1 = "bags",
    envDeathAll = "death", deathCount = "death", emoteCount = "emote", hugSet = "emote",
    interrupt = "interrupt", visit = "visit", visitInstance = "visit",
    killingSpell = "kills", healOther = "cast",
    castAll = "cast", blocks = "blocks", nakedDance = "emote", lowKill = "kills",
    slainBy = "death", questBurst = "quests", questCountOf = "quests", killAnyCount = { "kills", "quests" },
    talentGroups = "talents", flag = "count", soloKill = "count", count = "count", money = "count",
    countAll = "count", playedDays = "played", setCount = { "bags", "equip", "loot", "aura", "taxi" },
    setHas = "loot", lootAll = "loot", qdungeon = "quests", mountCount = { "bags", "spells" },
    taxiAll = "taxi", bags16 = "bags", ds2 = "bags",
}

local CRIT = {}

-- ---- the character --------------------------------------------------

CRIT.level = function(engine, c)
    local level = math.max(UnitLevel("player") or 1, engine.level or 1)
    return level >= c.n, { barRow(GUILD_RECRUITMENT_LEVEL, level, c.n) }
end

CRIT.mount = function(engine, c)
    local epic = c.q >= 4
    local done = engine:SetCount(epic and "mountsEpic" or "mounts") > 0
        or anySpellKnown(epic and CLASS_MOUNTS_EPIC or CLASS_MOUNTS)
    return done, { { label = epic and L.ACH_OWN_EPIC_MOUNT or L.ACH_OWN_MOUNT, done = done } }
end

CRIT.skill = function(engine, c)
    local sk = skillScan()
    local rank = sk[c.line] and sk[c.line].rank or 0
    return rank >= c.n, { barRow(MUI_SkillLineDB:GetName(c.line), rank, c.n) }
end

CRIT.skillCount = function(engine, c)
    local sk = skillScan()
    if c.weapon then
        local n = 0
        for _, info in pairs(sk) do
            if info.cat == WEAPON_SKILLS and info.rank >= c.at then n = n + 1 end
        end
        return n >= c.n, { barRow(L.ACH_WEAPON_SKILLS_AT:format(c.at), n, c.n) }
    end
    local rows, all = {}, true
    for _, line in ipairs(c.lines) do
        local rank = sk[line] and sk[line].rank or 0
        local done = rank >= c.at
        if not done then all = false end
        rows[#rows + 1] = { label = string.format("%s (%d)", MUI_SkillLineDB:GetName(line), c.at), done = done }
    end
    return all, rows
end

CRIT.profAny = function(engine, c)
    local sk, best = skillScan(), 0
    for _, info in pairs(sk) do
        if info.cat == PROFESSIONS and info.rank > best then best = info.rank end
    end
    return best >= c.n, { barRow(L.ACH_PRIMARY_PROFESSION_SKILL, best, c.n) }
end

CRIT.profBoth = function(engine, c)
    local sk, n = skillScan(), 0
    for _, info in pairs(sk) do
        if info.cat == PROFESSIONS and info.rank >= c.n then n = n + 1 end
    end
    return n >= 2, { barRow(L.ACH_PROFESSIONS_AT:format(c.n), n, 2) }
end

CRIT.skillOver = function(engine, c)
    local sk, best = skillScan(), 0
    for _, info in pairs(sk) do
        if info.cat == PROFESSIONS or info.cat == SECONDARY_SKILLS then
            best = math.max(best, info.rank + info.modifier)
        end
    end
    return best > c.n, { barRow(L.ACH_HIGHEST_SKILL, best, c.n + 1) }
end

-- recipes_<skill line id>: the most the trade skill window has listed
CRIT.recipes = function(engine, c)
    local n = engine:Counter("recipes_" .. c.prof)
    return n >= c.n, { barRow(L.ACH_RECIPES_KNOWN:format(MUI_SkillLineDB:GetName(c.prof)), n, c.n) }
end

CRIT.banks = function(engine, c)
    local n = GetNumBankSlots() or 0
    return n >= c.n, { barRow(L.ACH_BANK_SLOTS, n, c.n) }
end

CRIT.companions = function(engine, c)
    local n = engine:SetCount("companions")
    return n >= c.n, { barRow(L.ACH_COMPANIONS, n, c.n) }
end

CRIT.fall = function(engine)
    return engine:Counter("fallsSurvived") > 0, nil
end

CRIT.use = function(engine, c)
    local food = c.kind == "food"
    local n = engine:TallyKinds(food and "foodKinds" or "drinkKinds")
    return n >= c.n, { barRow(food and L.ACH_FOODS or L.ACH_DRINKS, n, c.n) }
end

CRIT.book = function(engine, c)
    local n = engine:SetCount("books")
    return n >= c.n, { barRow(L.ACH_BOOKS, n, c.n) }
end

CRIT.emoteLove = function(engine, c)
    local n = engine:SetCount("loved")
    return n >= c.n, { barRow(L.ACH_CRITTERS_LOVED, n, c.n) }
end

CRIT.emoteCount = function(engine, c)
    local n = engine:Counter(c.kind)
    local label = c.kind == "dance" and L.ACH_DANCES or c.kind == "silly" and L.ACH_JOKES or c.kind
    return n >= c.n, { barRow(label, n, c.n) }
end

CRIT.hugSet = function(engine, c)
    local n = engine:SetCount("hugged")
    return n >= c.n, { barRow(L.ACH_HUGS, n, c.n) }
end

-- base run speed is 7 yards a second
CRIT.speed = function(engine, c)
    local done = engine:Counter("speedTop") >= 7 * c.mult
    return done, { { label = L.ACH_FASTER_THAN_EPIC_MOUNT, done = done } }
end

CRIT.critterHit = function(engine, c)
    local done = engine:Counter("critterTop") >= c.n
    return done, { { label = L.ACH_CRITTER_HIT:format(c.n), done = done } }
end

CRIT.drunk = function(engine) return engine:Counter("drunk") > 0, nil end
CRIT.roll1 = function(engine) return engine:Counter("roll1") > 0, nil end
CRIT.roll100 = function(engine) return engine:Counter("roll100") > 0, nil end
CRIT.nakedKill = function(engine) return engine:Counter("nakedKill") > 0, nil end
CRIT.nakedDance = function(engine) return engine:Counter("nakedDance") > 0, nil end
CRIT.lowKill = function(engine) return engine:Counter("lowKill") > 0, nil end

CRIT.interrupt = function(engine, c)
    local n = engine:Counter("interrupts")
    return n >= c.n, { barRow(L.ACH_INTERRUPTS, n, c.n) }
end

CRIT.blocks = function(engine, c)
    local n = engine:Counter("blocks")
    return n >= c.n, { barRow(L.ACH_BLOCKS, n, c.n) }
end

CRIT.clutchHeal = function(engine)
    local done = engine:Counter("clutchHeal") > 0
    return done, { { label = L.ACH_CLUTCH_HEAL, done = done } }
end

CRIT.bandage = function(engine) return engine:Counter("triage") > 0, nil end

-- ---- deaths ---------------------------------------------------------

CRIT.deathCount = function(engine, c)
    local n = engine:Counter("deaths")
    return n >= c.n, { barRow(DEATHS, n, c.n) }
end

CRIT.envDeath = function(engine, c)
    return engine:Counter("death" .. c.kind) > 0, nil
end

CRIT.envDeathAll = function(engine, c)
    local rows, all = {}, true
    for i, kind in ipairs(c.kinds) do
        local done = engine:Counter("death" .. kind) > 0
        if not done then all = false end
        rows[#rows + 1] = { label = c.labels[i] or kind, done = done }
    end
    return all, rows
end

CRIT.selfKill = function(engine)
    local done = engine:Counter("selfKill") > 0
    return done, { { label = L.ACH_SELF_KILL, done = done } }
end

CRIT.slainBy = function(engine, c)
    local done = engine:Counter("slain" .. c.npc[1]) > 0
    return done, { { label = c.label, done = done } }
end

-- ---- kills ----------------------------------------------------------

CRIT.kill = function(engine, c)
    local done = engine:Slew(c.npc, c.quests)
    return done, { { label = c.label, done = done } }
end

CRIT.killAll = function(engine, c)
    return listRows(c.list, function(entry) return engine:Slew(entry.npc, entry.quests) end)
end

CRIT.killAnyCount = function(engine, c)
    local rows, n = {}, 0
    for _, entry in ipairs(c.list) do
        local done = engine:Slew(entry.npc, entry.quests)
        if done then n = n + 1 end
        rows[#rows + 1] = { label = entry.label, done = done }
    end
    return n >= c.n, rows
end

CRIT.killCount = function(engine, c)
    local n = engine:Counter("creaturesKilled")
    return n >= c.n, { barRow(L.ACH_CREATURES_KILLED, n, c.n) }
end

CRIT.killTimed = function(engine, c)
    local done = engine:Counter("leeroy") > 0
    return done, { { label = L.ACH_KILL_WITHIN:format(c.n, c.secs), done = done } }
end

-- Every boss killed inside one rolling window, which stands in for the
-- shared raid lockout.
CRIT.killLockout = function(engine, c)
    local now, n = GetServerTime(), 0
    for _, npc in ipairs(c.npcs) do
        local t = engine.store.lockout[npc]
        if t and now - t <= c.days * DAY then n = n + 1 end
    end
    return n >= #c.npcs, { barRow(L.ACH_BOSSES_THIS_LOCKOUT, n, #c.npcs) }
end

CRIT.timedBoss = function(engine, c)
    local done = engine:Counter("deadmansprint") > 0
    local boss = MUI_NpcDB:Get(c.npc[1])
    return done, { { label = L.ACH_BOSS_WITHIN:format(boss and boss.name or UNKNOWN, c.mins), done = done } }
end

CRIT.nodeaths = function(engine)
    local done = engine:Counter("untouchable") > 0
    return done, { { label = L.ACH_FLAWLESS_END_BOSS, done = done } }
end

CRIT.killingSpell = function(engine, c)
    local n = engine:Counter("ks" .. c.spell[1])
    if c.n <= 1 then return n >= 1, { { label = c.label, done = n >= 1 } } end
    return n >= c.n, { barRow(c.label, n, c.n) }
end

-- ---- quests ---------------------------------------------------------

CRIT.quest = function(engine, c)
    local done = engine:AnyQuestDone(c.any)
    return done, { { label = c.label, done = done } }
end

CRIT.questAll = function(engine, c)
    return listRows(c.list, function(entry)
        if entry.all then return engine:AllQuestsDone(entry.any) end
        return engine:AnyQuestDone(entry.any)
    end)
end

CRIT.questOrItem = function(engine, c)
    local done = (#c.quest > 0 and engine:AnyQuestDone(c.quest)) or anyItemOwned(c.item)
    return done, { { label = c.label, done = done } }
end

CRIT.questCountOf = function(engine, c)
    local n = 0
    for _, id in ipairs(c.ids) do
        if engine:QuestDone(id) then n = n + 1 end
    end
    return n >= c.n, { barRow(c.label, n, c.n) }
end

CRIT.qcount = function(engine, c)
    local n = engine:Counter("qcount")
    return n >= c.n, { barRow(L.ACH_QUESTS_COMPLETED, n, c.n) }
end

CRIT.qzone = function(engine, c)
    local need = engine:ForFaction(c.n)
    if not need or need == 0 then return false, nil end
    local n = engine:Counter("qz" .. c.zos)
    return n >= need, { barRow(L.ACH_QUESTS_COMPLETED, n, need) }
end

-- Every story chapter of the zone, as the map's zone story banner counts
-- them (QuestAvailability:GetZoneChapters): a check line per chapter.
CRIT.qstory = function(engine, c)
    local avail = MUI_QuestHelper and MUI_QuestHelper.availability
    local chapters = avail and avail:GetZoneChapters(c.zos)
    if not chapters or #chapters == 0 then return false, nil end
    local rows, all = {}, true
    for _, ch in ipairs(chapters) do
        if not ch.complete then all = false end
        rows[#rows + 1] = { label = ch.name, done = ch.complete }
    end
    return all, rows
end

CRIT.questMoney = function(engine, c)
    local n = engine:Counter("goldQuest")
    return n >= c.n, { barRow(L.ACH_GOLD_FROM_QUESTS, math.floor(n / 10000), math.floor(c.n / 10000)) }
end

CRIT.questsDay = function(engine, c)
    local n = engine.store.day.best or 0
    return n >= c.n, { barRow(L.ACH_QUESTS_IN_A_DAY, n, c.n) }
end

CRIT.questBurst = function(engine, c)
    local done = engine:Counter("questBurst") > 0
    return done, { { label = L.ACH_QUESTS_WITHIN:format(c.n, math.floor(c.secs / 60)), done = done } }
end

-- ---- the world ------------------------------------------------------

CRIT.explore = function(engine, c)
    local base = MUI_AchievementDB:GetExploreBase(c.map)
    local textures = C_MapExplorationInfo.GetExploredMapTextures(c.map)
    local n = textures and #textures or 0
    return base > 0 and n >= base, { barRow(L.ACH_AREAS_EXPLORED, n, math.max(base, 1)) }
end

-- areas by id, named by the client
CRIT.visit = function(engine, c)
    local set = engine:Set("visited")
    local rows, all = {}, true
    for _, area in ipairs(c.areas) do
        local done = set[area] == true
        if not done then all = false end
        rows[#rows + 1] = { label = C_Map.GetAreaInfo(area), done = done }
    end
    return all, rows
end

-- instances by id (GetInstanceInfo's), named by the client
CRIT.visitInstance = function(engine, c)
    local set = engine:Set("visitedInstances")
    local rows, all = {}, true
    for _, map in ipairs(c.maps) do
        local done = set[map] == true
        if not done then all = false end
        rows[#rows + 1] = { label = GetRealZoneText(map), done = done }
    end
    return all, rows
end

-- ---- reputation -----------------------------------------------------

CRIT.rep = function(engine, c)
    local done = (repStanding(c.fid) or 0) >= c.standing
    return done, { { label = c.label .. " — " .. _G["FACTION_STANDING_LABEL" .. c.standing], done = done } }
end

CRIT.repCount = function(engine, c)
    local n = exaltedCount()
    return n >= c.n, { barRow(L.ACH_EXALTED_REPUTATIONS, n, c.n) }
end

CRIT.repAll = function(engine, c)
    return listRows(c.list, function(entry) return (repStanding(entry.fid) or 0) >= c.standing end)
end

CRIT.repAny = function(engine, c)
    local done = false
    for _, fid in ipairs(c.fids) do
        if (repStanding(fid) or 0) >= c.standing then done = true break end
    end
    return done, { { label = c.label, done = done } }
end

CRIT.repAndItem = function(engine, c)
    local repDone = (repStanding(c.fid) or 0) >= c.standing
    local itemDone = anyItemOwned(c.item)
    return repDone and itemDone, {
        { label = c.label .. " — " .. _G["FACTION_STANDING_LABEL" .. c.standing], done = repDone },
        { label = C_Item.GetItemInfo(c.item[1]) or RETRIEVING_ITEM_INFO, done = itemDone },
    }
end

-- ---- spells ---------------------------------------------------------

CRIT.spell = function(engine, c)
    local done = anySpellKnown(c.any)
    return done, { { label = c.label, done = done } }
end

CRIT.spellAll = function(engine, c)
    return listRows(c.list, function(entry) return anySpellKnown(entry.any) end)
end

CRIT.castSpell = function(engine, c)
    local done = engine:Counter("cast" .. c.spell[1]) > 0
    return done, { { label = c.label, done = done } }
end

CRIT.castCount = function(engine, c)
    local n = engine:Counter("cast" .. c.spell[1])
    return n >= c.n, { barRow(c.label, n, c.n) }
end

-- Each entry is one talent tree's capstone, cast once, or seen as an aura
-- for passives.
CRIT.castAll = function(engine, c)
    local auras = engine:Set("costumes")
    return listRows(c.list, function(entry)
        if entry.aura then return auras[entry.label] == true end
        return engine:Counter("cast" .. entry.spells[1]) > 0
    end)
end

CRIT.healOther = function(engine, c)
    local done = engine:Counter("ho" .. c.spell[1]) > 0
    return done, { { label = c.label, done = done } }
end

CRIT.bubbleHearth = function(engine)
    local done = engine:Counter("bubbleHearth") > 0
    return done, { { label = L.ACH_BUBBLE_HEARTH, done = done } }
end

CRIT.aura = function(engine, c)
    local done = engine:Counter("gordok") > 0
    return done, { { label = C_Spell.GetSpellName(c.spell[1]), done = done } }
end

CRIT.auraAll = function(engine, c)
    local set = engine:Set("costumes")
    return listRows(c.list, function(entry) return set[entry.label] == true end)
end

-- ---- loot, crafting, wealth -----------------------------------------

CRIT.create = function(engine, c)
    local n = 0
    for _, id in ipairs(c.item) do n = n + engine:Counter("create" .. id) end
    if c.n <= 1 then return n >= 1, { { label = c.label, done = n >= 1 } } end
    return n >= c.n, { barRow(c.label, n, c.n) }
end

CRIT.createQuality = function(engine)
    local done = engine:Counter("createEpic") > 0
    return done, { { label = L.ACH_CRAFT_EPIC, done = done } }
end

CRIT.fishSchool = function(engine) return engine:Counter("fishSchool") > 0, nil end

CRIT.fish = function(engine, c)
    local n = engine:Counter("fishAll")
    return n >= c.n, { barRow(L.ACH_FISH_CAUGHT, n, c.n) }
end

CRIT.loot = function(engine, c)
    local set = engine:Set("lootItems")
    local done = false
    for _, id in ipairs(c.item) do if set[id] then done = true break end end
    return done, { { label = c.label, done = done } }
end

CRIT.lootOrInv = function(engine, c)
    local done = anyItemOwned(c.item)
    if not done then
        local set = engine:Set("lootItems")
        for _, id in ipairs(c.item) do if set[id] then done = true break end end
    end
    return done, { { label = c.label, done = done } }
end

CRIT.lootName = function(engine, c)
    local done = engine:Set("lootNames")[c.name] == true
    return done, { { label = c.name, done = done } }
end

CRIT.lootQuality = function(engine, c)
    local n = engine:Counter("epicsLooted")
    if c.n <= 1 then return n >= 1, { { label = L.ACH_LOOT_EPIC, done = n >= 1 } } end
    return n >= c.n, { barRow(L.ACH_EPICS_LOOTED, n, c.n) }
end

CRIT.lootCount = function(engine, c)
    local n = engine:Counter("itemsLooted")
    return n >= c.n, { barRow(L.ACH_ITEMS_LOOTED, n, c.n) }
end

CRIT.gather = function(engine, c)
    local n = engine:Counter("gather_" .. c.kind)
    local label = c.kind == "mining" and L.ACH_ORES_MINED or c.kind == "herbs" and L.ACH_HERBS_GATHERED or L.ACH_CREATURES_SKINNED
    return n >= c.n, { barRow(label, n, c.n) }
end

CRIT.moneyLoot = function(engine, c)
    local n = engine:Counter("goldLoot")
    return n >= c.n, { barRow(L.ACH_GOLD_LOOTED, math.floor(n / 10000), math.floor(c.n / 10000)) }
end

CRIT.moneyHeld = function(engine, c)
    local n = GetMoney() or 0
    return n >= c.n, { barRow(L.ACH_GOLD_HELD, math.floor(n / 10000), math.floor(c.n / 10000)) }
end

-- Every slot at `q` quality or better: 4 epic (the default), 3 superior.
CRIT.epicSlots = function(engine, c)
    local want = c.q or 4
    local n = 0
    for _, slot in ipairs(EPIC_SLOTS) do
        local link = GetInventoryItemLink("player", slot)
        local quality = link and select(3, C_Item.GetItemInfo(link))
        if quality and quality >= want then n = n + 1 end
    end
    return n >= #EPIC_SLOTS, { barRow(want >= 4 and L.ACH_EPIC_SLOTS or L.ACH_SUPERIOR_SLOTS, n, #EPIC_SLOTS) }
end

CRIT.inv = function(engine, c)
    local done = anyItemOwned(c.any)
    return done, { { label = c.label, done = done } }
end

CRIT.invAll = function(engine, c)
    return listRows(c.list, function(entry) return anyItemOwned(entry.any) end)
end

CRIT.pvpSet = function(engine)
    return itemSetRows(MUI_AchievementDB:GetPvpSet(engine.class, engine.faction == "Horde" and "H" or "A"))
end

CRIT.ds1 = function(engine)
    return itemSetRows(MUI_AchievementDB:GetDungeonSet(engine.class))
end

CRIT.dmfTickets = function(engine, c)
    local n = engine:Counter("dmfTickets")
    return n >= c.n, { barRow(L.ACH_TICKETS_SPENT, n, c.n) }
end

CRIT.dmfDeck = function(engine, c)
    local done = engine:Counter("dmfDeck") > 0 or anyItemOwned(c.item)
    return done, { { label = c.label, done = done } }
end

-- ---- player versus player -------------------------------------------

CRIT.hk = function(engine, c)
    local n = math.max(GetPVPLifetimeStats() or 0, engine:Counter("hk"))
    return n >= c.n, { barRow(HONORABLE_KILLS, n, c.n) }
end

-- The lifetime stats' highest rank is offset by four (rank 1 reads 5).
CRIT.rank = function(engine, c)
    local _, _, highest = GetPVPLifetimeStats()
    local done = (highest or 0) - 4 >= c.n
    return done, { { label = L.ACH_ATTAIN_RANK:format(c.n), done = done } }
end

CRIT.duel = function(engine, c)
    local n = engine:Counter("duelsWon")
    if c.n <= 1 then return n >= 1, { { label = L.ACH_WIN_DUEL, done = n >= 1 } } end
    return n >= c.n, { barRow(L.ACH_DUELS_WON, n, c.n) }
end

CRIT.kb = function(engine, c)
    if c.kind == "class" then
        local set = engine:Set("kbClass")
        local rows, all = {}, true
        for _, class in ipairs(CLASSES) do
            local done = set[class] == true
            if not done then all = false end
            rows[#rows + 1] = { label = LOCALIZED_CLASS_NAMES_MALE[class] or class, done = done }
        end
        return all, rows
    elseif c.kind == "race" then
        local races = engine.faction == "Horde"
            and { "Human", "Dwarf", "NightElf", "Gnome" }
            or  { "Orc", "Scourge", "Tauren", "Troll" }
        local set = engine:Set("kbRace")
        local rows, all = {}, true
        for _, race in ipairs(races) do
            local done = set[race] == true
            if not done then all = false end
            rows[#rows + 1] = { label = C_CreatureInfo.GetRaceInfo(RACE_ID[race]).raceName, done = done }
        end
        return all, rows
    end
    local n = engine:Counter("kbCity")
    return n >= c.n, { barRow(L.ACH_CITY_KILLING_BLOWS, n, c.n) }
end

CRIT.bgwin = function(engine, c)
    local n = engine:Counter("bgwin_" .. c.bg)
    if c.n <= 1 then return n >= 1, { { label = L.ACH_WIN_BATTLE, done = n >= 1 } } end
    return n >= c.n, { barRow(L.ACH_VICTORIES, n, c.n) }
end

CRIT.bgcol = function(engine, c)
    local n = engine:BattlegroundColumn(c.bg, c.col)
    return n >= c.n, { barRow(c.label, n, c.n) }
end

CRIT.bgstat = function(engine, c)
    local n = engine:Counter(c.stat .. (c.bg or "") .. "Best")
    local label = c.stat == "hk" and L.ACH_MOST_KILLS_BATTLE
        or c.stat == "damage" and L.ACH_MOST_DAMAGE_BATTLE or L.ACH_FLAWLESS_KILLING_BLOWS
    return n >= c.n, { barRow(label, n, c.n) }
end

CRIT.wsgcap = function(engine, c)
    local n = engine:Counter("wsgCaps")
    return n >= c.n, { { label = L.ACH_CAPTURE_FLAG, done = n >= c.n } }
end

CRIT.quickcap = function(engine, c)
    local done = engine:Counter("quickcap") > 0
    return done, { { label = L.ACH_CAPTURE_UNDER:format(c.secs), done = done } }
end

CRIT.ironman = function(engine)
    local done = engine:Counter("ironman") > 0
    return done, { { label = L.ACH_IRONMAN_CAPTURES, done = done } }
end

CRIT.perfection = function(engine, c)
    local done = engine:Counter("perfect_" .. c.bg) > 0
    return done, { { label = L.ACH_PERFECT_WIN, done = done } }
end

-- ---- hunter pets ----------------------------------------------------

CRIT.petFamilies = function(engine, c)
    local n = engine:SetCount("petFams")
    return n >= c.n, { barRow(L.ACH_PET_FAMILIES, n, c.n) }
end

-- the beasts by the creature a pet was tamed from (its GUID's)
CRIT.petRare = function(engine, c)
    local set = engine:Set("petNpcs")
    local done = false
    for _, npc in ipairs(c.npcs) do if set[npc] then done = true break end end
    return done, { { label = L.ACH_TAME_RARE, done = done } }
end

-- ---- metas ----------------------------------------------------------

-- Every member achievement earned; members this character can't have are skipped.
CRIT.meta = function(engine, c)
    local rows, all = {}, true
    for _, id in ipairs(c.ids) do
        local def = engine.byId[id]
        if def then
            local done = engine:IsEarned(id)
            if not done then all = false end
            rows[#rows + 1] = { label = def.name, done = done, meta = id }
        end
    end
    return #rows > 0 and all, rows
end


-- ---- ours -----------------------------------------------------------

CRIT.talentGroups = function(engine)
    local done = (GetNumSpecGroups() or 1) >= 2
    return done, { { label = L.ACH_SECOND_TALENT_GROUP, done = done } }
end

-- A deed done once: the trackers set its counter.
CRIT.flag = function(engine, c)
    local done = engine:Counter(c.key) > 0
    return done, { { label = c.label, done = done } }
end

CRIT.soloKill = function(engine)
    local done = engine:Counter("soloBoss") > 0
    return done, { { label = L.ACH_SOLO_END_BOSS, done = done } }
end

CRIT.count = function(engine, c)
    local n = engine:Counter(c.key)
    return n >= c.n, { barRow(c.label, n, c.n) }
end

CRIT.money = function(engine, c)
    local n = engine:Counter(c.key)
    return n >= c.n, { barRow(c.label, math.floor(n / 10000), math.floor(c.n / 10000)) }
end

CRIT.countAll = function(engine, c)
    local rows, all = {}, true
    for _, entry in ipairs(c.list) do
        local n = engine:Counter(entry.key)
        if n < entry.n then all = false end
        if entry.money then
            rows[#rows + 1] = barRow(entry.label, math.floor(n / 10000), math.floor(entry.n / 10000))
        else
            rows[#rows + 1] = barRow(entry.label, n, entry.n)
        end
    end
    return all, rows
end

CRIT.setCount = function(engine, c)
    local n = engine:SetCount(c.set)
    return n >= c.n, { barRow(c.label, n, c.n) }
end

-- A set holding every map (`maps`, named by the client) or item id
-- (`items`, with labels).
CRIT.setHas = function(engine, c)
    local set = engine:Set(c.set)
    local rows, all = {}, true
    for _, map in ipairs(c.maps or {}) do
        local done = set[map] == true
        if not done then all = false end
        rows[#rows + 1] = { label = C_Map.GetMapInfo(map).name, done = done }
    end
    for _, item in ipairs(c.items or {}) do
        local done = set[item.id] == true
        if not done then all = false end
        rows[#rows + 1] = { label = item.label, done = done }
    end
    return all, rows
end

CRIT.lootAll = function(engine, c)
    local set = engine:Set("lootItems")
    return listRows(c.list, function(entry)
        for _, id in ipairs(entry.item) do
            if set[id] or (C_Item.GetItemCount(id, true) or 0) > 0 then return true end
        end
        return false
    end)
end

CRIT.qdungeon = function(engine, c)
    local n = engine:Counter("qdungeon")
    return n >= c.n, { barRow(L.ACH_DUNGEON_QUESTS, n, c.n) }
end

-- Mounts in the bags, plus the class mounts known.
CRIT.mountCount = function(engine, c)
    local n = engine:SetCount("mounts")
    for _, id in ipairs(CLASS_MOUNTS) do
        if C_SpellBook.IsSpellKnown(id) then n = n + 1 end
    end
    return n >= c.n, { barRow(L.ACH_MOUNTS_OWNED, n, c.n) }
end

CRIT.playedDays = function(engine, c)
    local days = math.floor(engine:Counter("played") / DAY)
    return days >= c.n, { barRow(L.ACH_DAYS_PLAYED, days, c.n) }
end

-- Every flight path of a continent known; the flight master's map gave
-- the totals.
CRIT.taxiAll = function(engine, c)
    local rows, all = {}, true
    for i, map in ipairs(c.maps) do
        local total = engine:Counter("taxiTotal" .. map)
        local known = engine:SetCount("taxi" .. map)
        if total == 0 or known < total then all = false end
        rows[#rows + 1] = barRow(c.labels[i], known, math.max(total, 1))
    end
    return all, rows
end

CRIT.bags16 = function(engine)
    local n = 0
    for bag = 1, 4 do
        if (C_Container.GetContainerNumSlots(bag) or 0) >= 16 then n = n + 1 end
    end
    return n >= 4, { barRow(L.ACH_BIG_BAGS, n, 4) }
end

CRIT.ds2 = function(engine)
    return itemSetRows(MUI_AchievementDB:GetDungeonSet2(engine.class))
end


class "AchievementEngine" {
    __init = function(self)
        self.store = MUI_DB.data.achievements
        local store = self.store
        store.tallies = store.tallies or {}
        store.kills = store.kills or {}
        store.lockout = store.lockout or {}
        store.qdone = store.qdone or {}
        store.bg = store.bg or {}
        store.day = store.day or { stamp = "", n = 0, best = 0 }
        store.statsSince = store.statsSince or GetServerTime()
        -- a store built for other definitions starts over, quietly
        if store.schema ~= SCHEMA then
            wipe(store.earned)
            wipe(store.tracked)
            store.backfilled = false
            store.schema = SCHEMA
        end
        if not store.keysById then
            self:_KeysToIds()
            store.keysById = true
        end

        self.faction = UnitFactionGroup("player")
        self.class = select(2, UnitClass("player"))
        self.hardcore = C_GameRules.IsHardcoreActive()
        self.byId  = {}     -- id -> definition
        self.list  = {}     -- definitions this character can earn, DB order
        self.byCat = {}     -- category id -> its definitions
        self._groups = {}   -- dirty group -> definitions
        self._countKeys = {}  -- counters a flag or count achievement reads
        self._dirtyListeners = {}
        self._trackListeners = {}
        self._quiet = false
        self._burst = {}

        for _, def in ipairs(MUI_AchievementDB:GetAll()) do
            local forFaction = not def.facOnly or ((def.facOnly == "A") == (self.faction == "Alliance"))
            local forRealm = not (self.hardcore and def.noHardcore) and (not def.hardcoreOnly or self.hardcore)
            -- one class, or a list of them
            local only = def.classOnly
            local forClass = not only or only == self.class or (type(only) == "table" and tContains(only, self.class))
            if forFaction and forRealm and forClass then
                self.byId[def.id] = def
                self.list[#self.list + 1] = def
                local cat = def.sub or def.cat
                self.byCat[cat] = self.byCat[cat] or {}
                table.insert(self.byCat[cat], def)
                local groups = CRIT_GROUP[def.crit.t]
                if type(groups) == "string" then groups = { groups } end
                for _, group in ipairs(groups or {}) do
                    self._groups[group] = self._groups[group] or {}
                    table.insert(self._groups[group], def)
                end
                local t = def.crit.t
                if t == "flag" or t == "count" or t == "money" then
                    self._countKeys[def.crit.key] = true
                elseif t == "countAll" then
                    for _, entry in ipairs(def.crit.list) do self._countKeys[entry.key] = true end
                elseif t == "soloKill" then
                    self._countKeys.soloBoss = true
                end
            end
        end
        -- the categories with something in them for this character (a
        -- Hardcore realm has no Player vs. Player)
        self.categories = {}
        for _, cat in ipairs(MUI_AchievementDB:GetCategories()) do
            if self:GetCategoryNum(cat.id) > 0 then table.insert(self.categories, cat) end
        end
    end;

    -- What the store kept by name until the criteria went by id, moved to
    -- the ids once: places visited, instances entered, rare beasts tamed and
    -- scoreboard columns by their English names (which only an English
    -- client recorded), and the cities fished in and the skills' tallies by
    -- the client's own names.
    _KeysToIds = function(self)
        local store, old = self.store, MUI_AchievementDB:GetKeysByName()
        local function move(from, to, ids)
            for name, id in pairs(ids) do
                if from[name] ~= nil then
                    to[id] = from[name]
                    from[name] = nil
                end
            end
        end
        move(self:Set("visited"), self:Set("visited"), old.visited)
        move(self:Set("visitedInstances"), self:Set("visitedInstances"), old.visitedInstances)
        move(self:Set("petNames"), self:Set("petNpcs"), old.petNames)
        for bg, columns in pairs(old.bg) do
            if store.bg[bg] then move(store.bg[bg].cols, store.bg[bg].cols, columns) end
        end

        local cities = {}
        for _, def in ipairs(MUI_AchievementDB:GetAll()) do
            for _, map in ipairs(def.crit.t == "setHas" and def.crit.maps or {}) do
                cities[C_Map.GetMapInfo(map).name] = map
            end
        end
        move(self:Set("fishedZones"), self:Set("fishedZones"), cities)

        -- skillmax_<line> and recipes_<line> (the Smelting window's under Mining)
        local smelting, renamed = C_Spell.GetSpellName(SMELTING), {}
        for key in pairs(store.counters) do
            local kind, name = key:match("^(%a+)_(.+)$")
            if (kind == "skillmax" or kind == "recipes") and not tonumber(name) then
                local line = MUI_SkillLineDB:GetByName(name) or (name == smelting and MINING)
                if line then renamed[key] = kind .. "_" .. line end
            end
        end
        for from, to in pairs(renamed) do
            store.counters[to] = math.max(store.counters[to] or 0, store.counters[from])
            store.counters[from] = nil
        end
    end;

    -- ---- helpers the evaluators share --------------------------------

    -- A value that may be faction-specific: { A = ..., H = ... } or plain.
    ForFaction = function(self, v)
        if type(v) == "table" and (v.A ~= nil or v.H ~= nil) then
            return self.faction == "Horde" and v.H or v.A
        end
        return v
    end;

    QuestDone = function(self, id)
        return self.store.qdone[id] == true or C_QuestLog.IsQuestFlaggedCompleted(id) == true
    end;

    AnyQuestDone = function(self, ids)
        for _, id in ipairs(ids) do
            if self:QuestDone(id) then return true end
        end
        return false
    end;

    AllQuestsDone = function(self, ids)
        for _, id in ipairs(ids) do
            if not self:QuestDone(id) then return false end
        end
        return true
    end;

    AnyKill = function(self, npcs)
        for _, npc in ipairs(npcs) do
            if self.store.kills[npc] then return true end
        end
        return false
    end;

    -- A kill with credit, or a completed quest that required the kill (the
    -- definition names those), so a deed done before the addon still counts.
    Slew = function(self, npcs, quests)
        return self:AnyKill(npcs) or (quests ~= nil and self:AnyQuestDone(quests))
    end;

    -- ---- queries -------------------------------------------------------

    IconPath = function(self, def)
        return MUI.TEX_BASE .. "achievementicons\\" .. tostring(def.icon)
    end;

    IsEarned = function(self, id)
        return self.store.earned[id] ~= nil
    end;

    GetDef = function(self, id)
        return self.byId[id]
    end;

    -- Like GetAchievementInfo: id, name, points, completed, month, day, year,
    -- description, icon path, reward text, granted by the first sweep.
    GetInfo = function(self, id)
        local def = self.byId[id]
        if not def then return nil end
        local e = self.store.earned[id]
        local month, day, year
        if e and e.t then
            local t = date("*t", e.t)
            month, day, year = t.month, t.day, t.year
        end
        return def.id, def.name, def.pts, e ~= nil, month, day, year, def.desc,
               self:IconPath(def), def.reward, e and e.bf
    end;

    GetPrevious = function(self, id)
        local def = self.byId[id]
        return def and def.prev and self.byId[def.prev] and def.prev or nil
    end;

    -- A progressive achievement shows its chain's total.
    GetProgressivePoints = function(self, id)
        local def, pts = self.byId[id], 0
        while def do
            pts = pts + def.pts
            def = def.prev and self.byId[def.prev] or nil
        end
        return pts
    end;

    -- Objectives pane rows (see CRIT) and whether the criteria are met. An
    -- earned achievement's check lines read as done even if their source
    -- has since regressed.
    GetCriteria = function(self, id)
        local def = self.byId[id]
        local fn = def and CRIT[def.crit.t]
        if not fn then return nil end
        local ok, done, rows = pcall(fn, self, def.crit)
        if not ok then return nil end
        if rows and self:IsEarned(id) then
            for _, row in ipairs(rows) do
                if not row.bar then row.done = true end
            end
        end
        return rows, done or self:IsEarned(id)
    end;

    -- total, earned in a category, its sub-categories included.
    GetCategoryNum = function(self, catId)
        local total, done = 0, 0
        for _, def in ipairs(self.byCat[catId] or {}) do
            total = total + 1
            if self:IsEarned(def.id) then done = done + 1 end
        end
        for _, cat in ipairs(MUI_AchievementDB:GetCategories()) do
            if cat.parent == catId then
                local t, d = self:GetCategoryNum(cat.id)
                total, done = total + t, done + d
            end
        end
        return total, done
    end;

    GetTotalPoints = function(self)
        local pts = 0
        for id in pairs(self.store.earned) do
            local def = self.byId[id]
            if def then pts = pts + def.pts end
        end
        return pts
    end;

    GetNumEarned = function(self)
        local n = 0
        for id in pairs(self.store.earned) do
            if self.byId[id] then n = n + 1 end
        end
        return n
    end;

    -- Earned achievements, newest first: { { id, t }, ... }
    GetRecent = function(self)
        local out = {}
        for id, e in pairs(self.store.earned) do
            if self.byId[id] then out[#out + 1] = { id = id, t = e.t or 0 } end
        end
        table.sort(out, function(a, b) return a.t > b.t end)
        return out
    end;

    -- Substring match over name and description, by name.
    Search = function(self, text)
        local out = {}
        if not text or #text < 2 then return out end
        text = MUI.Fold(text)
        for _, def in ipairs(self.list) do
            if MUI.Fold(def.name):find(text, 1, true) or MUI.Fold(def.desc):find(text, 1, true) then
                out[#out + 1] = def
            end
        end
        table.sort(out, function(a, b) return strcmputf8i(a.name, b.name) < 0 end)
        return out
    end;

    -- ---- tallies the trackers feed -------------------------------------

    -- A counter an achievement reads re-evaluates it on the spot.
    Bump = function(self, name, by)
        self.store.counters[name] = (self.store.counters[name] or 0) + (by or 1)
        if self._countKeys[name] then self:Dirty("count") end
        return self.store.counters[name]
    end;

    Counter = function(self, name)
        return self.store.counters[name] or 0
    end;

    -- Keep the highest value seen.
    Max = function(self, name, value)
        if value and value > (self.store.counters[name] or 0) then
            self.store.counters[name] = value
        end
    end;

    Set = function(self, name)
        self.store.sets[name] = self.store.sets[name] or {}
        return self.store.sets[name]
    end;

    SetCount = function(self, name)
        local n = 0
        for _ in pairs(self.store.sets[name] or {}) do n = n + 1 end
        return n
    end;

    Tally = function(self, name)
        self.store.tallies[name] = self.store.tallies[name] or {}
        return self.store.tallies[name]
    end;

    TallyBump = function(self, name, kind, by)
        local t = self:Tally(name)
        t[kind] = (t[kind] or 0) + (by or 1)
    end;

    TallyKinds = function(self, name)
        local n = 0
        for _ in pairs(self.store.tallies[name] or {}) do n = n + 1 end
        return n
    end;

    -- The kind with the highest tally, and its count.
    TallyTop = function(self, name)
        local top, best
        for kind, n in pairs(self.store.tallies[name] or {}) do
            if not best or n > best then top, best = kind, n end
        end
        return top, best
    end;

    -- A kill with credit: remembered for the kill criteria, and for the
    -- lockout clears when the boss is one.
    RecordKill = function(self, npc)
        local now = GetServerTime()
        self.store.kills[npc] = now
        self.store.lockout[npc] = now
    end;

    -- A battleground's scoreboard column, summed over its matches.
    -- A scoreboard column's total, by its place on the board (the names
    -- are the client's language).
    BattlegroundColumn = function(self, bg, column)
        local t = self.store.bg[bg]
        return t and t.cols[column] or 0
    end;

    AddBattlegroundColumn = function(self, bg, column, value)
        self.store.bg[bg] = self.store.bg[bg] or { cols = {} }
        local cols = self.store.bg[bg].cols
        cols[column] = (cols[column] or 0) + value
    end;

    -- ---- the Statistics tab --------------------------------------------

    -- A MUI_StatisticsDB row's value, formatted for its line; `coinSize` is
    -- the money rows' coin icon height.
    GetStatValue = function(self, def, coinSize)
        local kind, v = def.kind, nil
        if kind == "top" then
            local name, n = self:TallyTop(def.key)
            return name and string.format("%s (%d)", name, n) or "--"
        elseif kind == "kinds" then
            v = self:TallyKinds(def.key)
        elseif kind == "set" then
            v = self:SetCount(def.key)
        elseif kind == "hk" then
            v = math.max(GetPVPLifetimeStats() or 0, self:Counter("hk"))
        elseif kind == "skill" then
            v = self:_SkillRank(def.skill)
            if not v then return "--" end
        elseif kind == "skillmax" then
            v = math.max(self:Counter(def.key), self:_SkillRank(def.skill) or 0)
            if v == 0 then return "--" end
        elseif kind == "perday" then
            local days = math.max(1, math.ceil((GetServerTime() - self.store.statsSince) / DAY))
            v = self:Counter(def.key) / days
        else
            v = self:Counter(def.key)
        end
        if def.fmt == "money" then return C_CurrencyInfo.GetCoinTextureString(math.floor(v), coinSize or 12) end
        if def.fmt == "pct" then return v > 0 and string.format("%d%%", v / 7 * 100) or "--" end
        if kind == "perday" then return string.format("%.1f", v) end
        return tostring(v)
    end;

    _SkillRank = function(self, line)
        for i = 1, GetNumSkillLines() do
            local skillName, isHeader, _, rank = GetSkillLineInfo(i)
            if not isHeader and MUI_SkillLineDB:GetByName(skillName) == line then return rank end
        end
        return nil
    end;

    -- ---- quests --------------------------------------------------------

    -- A countable quest found complete: once into the total and its zone's
    -- count.
    _BucketQuest = function(self, id)
        if self.store.qdone[id] then return false end
        local zone = MUI_AchievementDB:GetQuestZone(id)
        if zone == nil then return false end
        self.store.qdone[id] = true
        self:Bump("qcount")
        self:Bump("qz" .. zone)
        if MUI_AchievementDB:IsInstanceZone(zone) then self:Bump("qdungeon") end
        return true
    end;

    -- A quest turned in: the counts, the turn-in burst, the day's record,
    -- the Darkmoon prizes and decks.
    OnQuestTurnIn = function(self, id)
        local now = GetTime()
        local kept = {}
        for _, t in ipairs(self._burst) do
            if now - t <= 120 then kept[#kept + 1] = t end
        end
        kept[#kept + 1] = now
        self._burst = kept
        if #kept >= 8 and self:Counter("questBurst") == 0 then self:Bump("questBurst") end

        local tickets = MUI_AchievementDB:GetDarkmoonTickets(id)
        if tickets then
            self:Bump("dmfTickets", tickets)
            self:Dirty("dmf")
        end
        if MUI_AchievementDB:IsDarkmoonDeck(id) then
            self:Bump("dmfDeck")
            self:Dirty("dmf")
        end

        self:_BucketQuest(id)
        if GetGameTime() < 6 then self:Bump("nightTurnIns") end     -- the server's small hours
        local day = self.store.day
        local stamp = date("%Y%j")
        if day.stamp ~= stamp then day.stamp, day.n = stamp, 0 end
        day.n = day.n + 1
        if day.n > (day.best or 0) then day.best = day.n end
        self:Dirty("quests")
        -- the server's completed flag lands a moment after the turn-in, and
        -- the zone chapters read the flag: look again once it is there
        if not C_QuestLog.IsQuestFlaggedCompleted(id) then
            local tries, ticker = 0, nil
            ticker = C_Timer.NewTicker(0.5, function()
                tries = tries + 1
                if C_QuestLog.IsQuestFlaggedCompleted(id) or tries >= 20 then
                    ticker:Cancel()
                    self:Dirty("quests")
                end
            end)
        end
    end;

    -- /played without the chat line: the chat frames showing it stop
    -- listening for the one answer and listen again once it came.
    RequestPlayed = function(self)
        local wanted = false
        for _, def in ipairs(self._groups.played or {}) do
            if not self:IsEarned(def.id) then wanted = true end
        end
        if not wanted then return end
        self._playedMuted = {}
        for i = 1, Constants.ChatFrameConstants.MaxChatWindows do
            local chat = _G["ChatFrame" .. i] and Frame(_G["ChatFrame" .. i])
            if chat and chat:IsEventRegistered("TIME_PLAYED_MSG") then
                chat:UnregisterEvent("TIME_PLAYED_MSG")
                table.insert(self._playedMuted, chat)
            end
        end
        RequestTimePlayed()
    end;

    OnPlayed = function(self, total)
        for _, chat in ipairs(self._playedMuted or {}) do chat:RegisterEvent("TIME_PLAYED_MSG") end
        self._playedMuted = nil
        self.store.counters.played = total
        self:Dirty("played")
    end;

    -- PLAYER_LEVEL_UP carries the new level; UnitLevel still reads the old
    -- one while the event is handled.
    OnLevelUp = function(self, level)
        self.level = level
        self:Dirty("level")
    end;

    -- ---- evaluation and award ------------------------------------------

    Evaluate = function(self, def)
        if self:IsEarned(def.id) then return true end
        local fn = CRIT[def.crit.t]
        if not fn then return false end
        local ok, done = pcall(fn, self, def.crit)
        if ok and done then
            self:_Award(def)
            return true
        end
        return false
    end;

    _Award = function(self, def)
        self.store.earned[def.id] = { t = GetServerTime(), bf = self._quiet or nil }
        if not self._quiet then
            MUI_ModuleToasts:ShowAchievement({ id = def.id, name = def.name, pts = def.pts, icon = self:IconPath(def) })
            -- retail's own earn line in chat
            DEFAULT_CHAT_FRAME:AddMessage(ACHIEVEMENT_BROADCAST_SELF:format("[" .. def.name .. "]"), 1, 1, 0)
        end
        self:Untrack(def.id)
        self:_NotifyDirty(def.id)
        self:Dirty("meta")
    end;

    -- A tracker calls this when a group's inputs changed; every unearned
    -- achievement in the group is re-evaluated. Metas settle in a loop,
    -- since one award can complete another.
    Dirty = function(self, group)
        local defs = self._groups[group]
        if not defs then return end
        -- before the first sweep, nothing is awarded: it covers everything, quietly
        if not self.store.backfilled and not self._sweeping then return end
        if group == "meta" then
            if self._metaPass then return end
            self._metaPass = true
            local changed = true
            while changed do
                changed = false
                for _, def in ipairs(defs) do
                    if not self:IsEarned(def.id) and self:Evaluate(def) then changed = true end
                end
            end
            self._metaPass = false
        else
            for _, def in ipairs(defs) do
                if not self:IsEarned(def.id) then self:Evaluate(def) end
            end
        end
        self:_NotifyDirty()
    end;

    -- Every login: rebuild the quest counts from the server's flags, then
    -- re-evaluate everything, so deeds done with the addon off still count.
    -- Spread over frames; the very first sweep is silent — no toast storm
    -- for a veteran.
    Backfill = function(self)
        if self._sweeping then return end
        self._sweeping = true
        self._quiet = not self.store.backfilled
        local store = self.store
        local ids = {}
        for id in pairs(MUI_AchievementDB:GetQuestZones()) do ids[#ids + 1] = id end

        local co = coroutine.create(function()
            wipe(store.qdone)
            store.counters.qcount, store.counters.qdungeon = 0, 0
            for k in pairs(store.counters) do
                if type(k) == "string" and k:sub(1, 2) == "qz" then store.counters[k] = 0 end
            end
            for i, id in ipairs(ids) do
                if C_QuestLog.IsQuestFlaggedCompleted(id) then self:_BucketQuest(id) end
                if i % 250 == 0 then coroutine.yield() end
            end
            self:RequestPlayed()
            for i, def in ipairs(self.list) do
                if not self:IsEarned(def.id) then self:Evaluate(def) end
                if i % 40 == 0 then coroutine.yield() end
            end
            self:Dirty("meta")
        end)

        local ticker
        ticker = C_Timer.NewTicker(0.03, function()
            if coroutine.status(co) ~= "dead" then
                local ok, err = coroutine.resume(co)
                if ok then return end
                MUI.Print("ModernUI: achievement sweep failed: " .. tostring(err))
            end
            ticker:Cancel()
            if self._quiet then
                store.backfilled = true
                local n = self:GetNumEarned()
                if n > 0 then
                    DEFAULT_CHAT_FRAME:AddMessage(L.ACH_GRANTED:format(n, self:GetTotalPoints()), 1, 0.82, 0)
                end
            end
            self._quiet = false
            self._sweeping = false
            self:_NotifyDirty()
        end)
    end;

    -- Testing: forget every achievement and tally, then sweep again — this
    -- time with the toasts.
    Reset = function(self)
        local store = self.store
        wipe(store.earned)
        wipe(store.counters)
        wipe(store.sets)
        wipe(store.tallies)
        wipe(store.tracked)
        wipe(store.kills)
        wipe(store.lockout)
        wipe(store.qdone)
        wipe(store.bg)
        store.day = { stamp = "", n = 0, best = 0 }
        store.statsSince = GetServerTime()
        store.backfilled = true
        self:_NotifyTrack()
        self:Backfill()
    end;

    -- fn(id | nil): an award (id) or a sweep (nil) changed the state.
    RegisterDirty = function(self, fn)
        table.insert(self._dirtyListeners, fn)
    end;

    _NotifyDirty = function(self, id)
        for _, fn in ipairs(self._dirtyListeners) do fn(id) end
    end;

    -- ---- tracking (retail's content tracking, 10 at most) --------------

    IsTracked = function(self, id)
        for _, t in ipairs(self.store.tracked) do
            if t == id then return true end
        end
        return false
    end;

    GetTracked = function(self)
        return self.store.tracked
    end;

    -- true, or false and "max" | "completed"
    Track = function(self, id)
        if self:IsTracked(id) then return true end
        if self:IsEarned(id) then return false, "completed" end
        if #self.store.tracked >= MAX_TRACKED then return false, "max" end
        table.insert(self.store.tracked, id)
        self:_NotifyTrack(id, true)
        return true
    end;

    Untrack = function(self, id)
        local removed = false
        for i = #self.store.tracked, 1, -1 do
            if self.store.tracked[i] == id then
                table.remove(self.store.tracked, i)
                removed = true
            end
        end
        if removed then self:_NotifyTrack(id, false) end
    end;

    -- fn(id, tracked): an achievement was tracked or untracked; fn() when
    -- the whole list changed.
    RegisterTrackListener = function(self, fn)
        table.insert(self._trackListeners, fn)
    end;

    _NotifyTrack = function(self, id, tracked)
        for _, fn in ipairs(self._trackListeners) do fn(id, tracked) end
    end;
}
