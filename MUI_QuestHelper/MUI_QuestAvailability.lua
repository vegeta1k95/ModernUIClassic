-- MUI_QuestAvailability: ports Questie's AvailableQuests._CheckAvailability
-- + QuestieDB.IsDoable + IsLevelRequirementsFulfilled + pre-quest logic
-- onto MUI_QuestDB. Maintains `_available[questId]=true` for every DB
-- quest the player is currently eligible to accept, recomputed on level-
-- up / zone change / quest-log change. Consumers (the minimap pin manager)
-- subscribe via RegisterChangeListener and redraw.
--
-- Checks mirrored from Questie (all Classic Era fields on the quest record
-- are named; see MUI_QuestDB.lua):
--   * not already completed  (C_QuestLog.IsQuestFlaggedCompleted)
--   * not already in the quest log
--   * requiredRaces bitmask  (bit.band with 2^(raceIdx-1))
--   * requiredClasses bitmask
--   * requiredLevel ≤ playerLevel ≤ requiredMaxLevel
--   * trivial filter: questLevel ≥ playerLevel − GetQuestGreenRange
--   * preQuestSingle: at least one must be completed
--   * preQuestGroup:  all must be completed (negative ids skip exclusiveTo
--                     alt; positive ids allow any exclusiveTo alt)
--   * parentQuest must be in the log
--   * nextQuestInChain not completed / active
--   * exclusiveTo: none of them completed or active
--   * breadcrumbForQuestId target not completed / active
--   * active breadcrumbs in log block the quest
--   * availableUntilCompleted / availableStartingWith
--
-- Retail-only Questie checks (achievements, IsleOfQuelDanas, SoD runes,
-- daily/weekly/raid/PvP filters, specialization/spell requirements,
-- reputation, profession skill/rank) are not ported — Classic Era has
-- almost none and the ones it does have (rep, skill) are rare enough to
-- live with false positives in v1.

local _TRIVIAL_RANGE_FALLBACK = 5

-- Questie's portable bit-flag test: `(value % (2*flag)) >= flag` returns
-- true iff `flag`'s bit is set in `value`, without needing the bit lib.
-- flag  = 2^(idx-1), flagX2 = 2*flag. Lua 5.1's `%` on integer-valued
-- floats works exactly; avoids fragile bit.band coercion on Classic Era.
local _raceFlag, _raceFlagX2     = nil, nil
local _classFlag, _classFlagX2   = nil, nil
local function _ensurePlayerFlags()
    if not _raceFlag then
        local _, _, idx = UnitRace("player")
        if idx then
            _raceFlag   = 2 ^ (idx - 1)
            _raceFlagX2 = 2 * _raceFlag
        end
    end
    if not _classFlag then
        local _, _, idx = UnitClass("player")
        if idx then
            _classFlag   = 2 ^ (idx - 1)
            _classFlagX2 = 2 * _classFlag
        end
    end
end
local function _hasRace(requiredRaces)
    if not requiredRaces or requiredRaces == 0 then return true end
    if not _raceFlag then return true end  -- pre-login caller; let it pass
    return (requiredRaces % _raceFlagX2) >= _raceFlag
end
local function _hasClass(requiredClasses)
    if not requiredClasses or requiredClasses == 0 then return true end
    if not _classFlag then return true end
    return (requiredClasses % _classFlagX2) >= _classFlag
end

local function _trivialThreshold(playerLevel)
    local range = GetQuestGreenRange and GetQuestGreenRange("player")
                  or _TRIVIAL_RANGE_FALLBACK
    return playerLevel - range
end

-- Quest-flag bits from Questie (QuestieDB.lua):
--   daily = 4096, weekly = 32768. Tested via the bit-flag modulo trick.
local _QUEST_FLAG_DAILY   = 4096
local _QUEST_FLAG_WEEKLY  = 32768
-- specialFlags bit 0 (value 1) = repeatable; see QuestieDB.IsRepeatable.
local _SPECIAL_FLAG_REPEATABLE = 1
local function _isDailyQuest(q)
    local f = q and q.questFlags
    return f and (f % (_QUEST_FLAG_DAILY * 2)) >= _QUEST_FLAG_DAILY or false
end
local function _isWeeklyQuest(q)
    local f = q and q.questFlags
    return f and (f % (_QUEST_FLAG_WEEKLY * 2)) >= _QUEST_FLAG_WEEKLY or false
end
local function _isRepeatableQuest(q)
    local f = q and q.specialFlags
    return f and (f % (_SPECIAL_FLAG_REPEATABLE * 2)) >= _SPECIAL_FLAG_REPEATABLE or false
end

-- Per-profession rank-spell table (mirrors Questie's rankKeys, trimmed to
-- Classic Era ranks 1-4: Apprentice / Journeyman / Expert / Artisan).
-- requiredRanks[i] = {professionId, rankLevel}. We resolve rankLevel → the
-- spell that grants that rank, then check IsSpellKnown.
local _PROF_RANK_SPELLS = {
    [129] = {3273, 3274, 7924, 10846},                     -- First Aid
    [164] = {2018, 3100, 3538,  9785},                     -- Blacksmithing
    [165] = {2108, 3104, 3811, 10662},                     -- Leatherworking
    [171] = {2259, 3101, 3464, 11611},                     -- Alchemy
    [182] = {2366, 2368, 3570, 11993},                     -- Herbalism
    [185] = {2550, 3102, 3413, 18260},                     -- Cooking
    [186] = {2575, 2576, 3564, 10248},                     -- Mining
    [197] = {3908, 3909, 3910, 12180},                     -- Tailoring
    [202] = {4036, 4037, 4038, 12656},                     -- Engineering
    [333] = {7411, 7412, 7413, 13920},                     -- Enchanting
    [356] = {7620, 7731, 7732, 18248},                     -- Fishing
    [393] = {8613, 8617, 8618, 10768},                     -- Skinning
}
local function _hasRequiredRanks(req)
    if not req then return true end
    if type(req) ~= "table" then return true end
    if not IsSpellKnown then return true end
    -- Shape: list of {profId, rankLevel}. Any single failure → false.
    for _, pair in ipairs(req) do
        if type(pair) == "table" and pair[1] and pair[2] then
            local ranks = _PROF_RANK_SPELLS[pair[1]]
            if ranks then
                local found = false
                -- Accept the requested rank OR any higher rank (if the
                -- player has Artisan Alchemy they satisfy rank-3 Expert).
                for r = pair[2], #ranks do
                    if IsSpellKnown(ranks[r]) then found = true; break end
                end
                if not found then return false end
            end
        end
    end
    return true
end

-- Profession specialization: stored as a single spell id that the player
-- must know (e.g. Goblin Engineering ID). Mirrors
-- QuestieProfessions.HasSpecialization which is just IsSpellKnown.
local function _hasRequiredSpecialization(spec)
    if not spec or spec == 0 then return true end
    if not IsSpellKnown then return true end
    return IsSpellKnown(spec) and true or false
end

-- requiredSpell: positive id = must know the spell; negative id = must
-- NOT know it. Mirrors QuestieDB.IsDoable's check that uses
-- IsSpellKnown(math.abs(requiredSpell)) with opposite conditionals based
-- on sign.
local function _hasRequiredSpell(req)
    if not req or req == 0 then return true end
    if not IsSpellKnown then return true end
    local known = IsSpellKnown(math.abs(req)) and true or false
    if req > 0 then
        return known       -- must know
    else
        return not known   -- must NOT know (negative id)
    end
end

-- Reputation check. `requiredMinRep` / `requiredMaxRep` are each
-- `{factionID, barValue}` — "at least X rep with faction Y" and/or
-- "strictly below X rep". GetFactionInfoByID returns nil for factions
-- the player hasn't discovered yet; Questie treats that as a hard fail
-- (you can't be above a rep threshold with a faction you haven't met).
-- Matches QuestieReputation.HasReputation.
local function _hasRequiredRep(requiredMinRep, requiredMaxRep)
    if not GetFactionInfoByID then return true end
    if requiredMinRep and requiredMinRep[1] then
        local name, _, _, _, _, barValue = GetFactionInfoByID(requiredMinRep[1])
        if not name then return false end
        if (barValue or 0) < (requiredMinRep[2] or 0) then return false end
    end
    if requiredMaxRep and requiredMaxRep[1] then
        local name, _, _, _, _, barValue = GetFactionInfoByID(requiredMaxRep[1])
        if not name then return false end
        if (barValue or 0) >= (requiredMaxRep[2] or 0) then return false end
    end
    return true
end

-- Profession-skill check. `req` is `{skillLineID, requiredRank}` from the
-- Questie DB (e.g. {171, 210} = Alchemy skill 210). GetProfessionInfo
-- returns (name, icon, rank, maxRank, _, _, skillLine, …) — `skillLine` is
-- the dbc id that matches req[1]. Missing profession or insufficient rank
-- → false. Missing API / nil req → true (pass-through). Quests like
-- "Badlands Reagent Run II" (needs Alchemy 210) become unavailable when
-- the player doesn't have the profession, preventing false-positive pins.
local function _hasRequiredSkill(req)
    if not req or type(req) ~= "table" or not req[1] then return true end
    if not GetProfessions or not GetProfessionInfo then return true end
    local reqId   = req[1]
    local reqRank = req[2] or 0
    local prof1, prof2, arch, fish, cook, firstAid = GetProfessions()
    local slots = { prof1, prof2, arch, fish, cook, firstAid }
    for _, slot in ipairs(slots) do
        if slot then
            local _, _, rank, _, _, _, skillLine = GetProfessionInfo(slot)
            if skillLine == reqId then
                return rank and rank >= reqRank
            end
        end
    end
    return false
end

class "QuestAvailability" : extends "Frame" {
    __init = function(self)
        Frame.__init(self, "Frame", nil, "MUI_QuestAvailabilityDriver")

        self._available  = {}        -- [questId] = true
        self._trivial    = {}        -- [questId] = true   (subset of _available)
        self._repeatable = {}        -- [questId] = true   (subset of _available)
        -- Trivial filtering moved to consumers — both world map and
        -- minimap have their own toggle and decide per-surface whether
        -- to render trivial pins. This layer always returns the full
        -- set with `isTrivial` flagged on each starter row.
        self._listeners          = {}
        self._recomputeScheduled = false

        -- Daily / weekly hidden quests: an NPC's gossip that doesn't
        -- include a daily/weekly we know they can give means the quest
        -- isn't offered today. Stored in MUI_DB so the flag persists
        -- through /reload within the same server day; wiped when the
        -- next daily reset is crossed.
        self._dailyHidden = self:_LoadDailyHidden()

        -- Level / quest-log / skill changes that can flip any quest's
        -- availability. SKILL_LINES_CHANGED covers profession-skill
        -- level-ups which unlock skill-gated quests (e.g. Alchemy 210).
        -- Side-cache for just-turned-in quest IDs. IsQuestFlaggedCompleted
        -- reads from the QuestsCompleted query cache, which isn't refreshed
        -- synchronously when QUEST_TURNED_IN fires — so a quest can stay
        -- Available on the map for a tick until QUEST_QUERY_COMPLETE comes
        -- back. We bridge the gap by recording the questID from the event
        -- payload and treating it as completed in Recompute.
        self._justCompleted = {}

        self:RegisterEventHandler("PLAYER_ENTERING_WORLD", function() self:_Schedule() end)
        self:RegisterEventHandler("PLAYER_LEVEL_UP",       function() self:_Schedule() end)
        self:RegisterEventHandler("QUEST_TURNED_IN", function(_, _, questID)
            if questID then self._justCompleted[questID] = true end
            self:_Schedule()
        end)
        self:RegisterEventHandler("SKILL_LINES_CHANGED",   function() self:_Schedule() end)
        -- UPDATE_FACTION fires on rep gain / new-faction discovery, which
        -- can unlock quests gated on "Honored with X" and similar.
        self:RegisterEventHandler("UPDATE_FACTION",        function() self:_Schedule() end)
        -- SPELLS_CHANGED lets us pick up newly-learned spec / requiredSpell
        -- conditions without a reload.
        self:RegisterEventHandler("SPELLS_CHANGED",        function() self:_Schedule() end)
        -- Gossip / quest-dialog paths tell us which daily/weekly the NPC
        -- is actually offering today; those not listed get hidden.
        self:RegisterEventHandler("GOSSIP_SHOW",           function() self:_HideUnofferedDailies() end)
        self:RegisterEventHandler("QUEST_GREETING",        function() self:_HideUnofferedDailies() end)
    end;

    -- Daily-hidden persistence. Keyed by realm, with a `resetAt` unix
    -- second stored alongside the set so we auto-wipe across daily reset
    -- without relying on an exact event. Questie uses the same "wipe on
    -- day boundary" approach in AvailableQuests.Initialize.
    _LoadDailyHidden = function(self)
        MUI_DB.settings.questHelper = MUI_DB.settings.questHelper or {}
        local root = MUI_DB.settings.questHelper.dailyHidden or {}
        MUI_DB.settings.questHelper.dailyHidden = root
        local realm = GetRealmName() or "?"
        local slot  = root[realm]
        local now   = time()
        if not slot or not slot.resetAt or now >= slot.resetAt then
            slot = { resetAt = now + 24 * 3600, ids = {} }
            root[realm] = slot
        end
        return slot.ids
    end;

    _SaveDailyHidden = function(self)
        MUI_DB.settings.questHelper = MUI_DB.settings.questHelper or {}
        local root = MUI_DB.settings.questHelper.dailyHidden
        if not root then return end
        local realm = GetRealmName() or "?"
        local slot  = root[realm]
        if slot then slot.ids = self._dailyHidden end
    end;

    -- On gossip / quest-greeting with an NPC: compare the set of quest IDs
    -- the NPC is offering to the daily/weekly quests we know they CAN
    -- start. Every known daily/weekly that's NOT in today's offer gets
    -- pinned to the hidden set until the next reset. Mirrors Questie's
    -- ValidateAvailableQuestsFromGossipShow / QuestGreeting.
    _HideUnofferedDailies = function(self)
        local targetGuid = UnitGUID("target")
        if not targetGuid then return end
        local kind, _, _, _, _, idStr = strsplit("-", targetGuid)
        if kind ~= "Creature" and kind ~= "Vehicle" then return end
        local npcId = tonumber(idStr)
        if not npcId or not MUI_NpcDB then return end
        local npc = MUI_NpcDB:Get(npcId)
        if not npc or not npc.questStarts then return end

        -- Collect quest IDs offered by this NPC right now.
        local offered = {}
        if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
            for _, gq in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
                if gq.questID then offered[gq.questID] = true end
            end
            for _, gq in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
                if gq.questID then offered[gq.questID] = true end
            end
        end
        -- QUEST_GREETING path: iterate Blizzard's QuestTitleButton list.
        for i = 1, (MAX_NUM_QUESTS or 32) do
            local btn = _G["QuestTitleButton" .. i]
            if not btn then break end
            local b = Button(btn)
            if b:IsVisible() then
                local id = btn.questID or b:GetID()
                -- btn:GetID() returns a 1-based index, not a questId on
                -- Classic Era; the real id is only available via the
                -- GetAvailableTitle / GetActiveTitle API with that index.
                -- We can't resolve it reliably here, so this branch is
                -- best-effort: the C_GossipInfo path above covers most
                -- gossip NPCs.
                if type(id) == "number" and id > 1000 then
                    offered[id] = true
                end
            end
        end

        local quests = MUI_QuestDB:GetAll()
        local changed = false
        for _, qid in ipairs(npc.questStarts) do
            local q = quests and quests[qid]
            if q and (_isDailyQuest(q) or _isWeeklyQuest(q))
               and not offered[qid]
               and not self._dailyHidden[qid] then
                self._dailyHidden[qid] = true
                changed = true
            end
        end
        if changed then
            self:_SaveDailyHidden()
            self:_Schedule()
        end
    end;

    -- Notify all change listeners without recomputing the data set.
    -- Used by per-surface trivial-filter setters: the data layer is
    -- unchanged but consumers need to re-render pins under the new
    -- filter.
    NotifyListeners = function(self)
        self:_FireChanged()
    end;

    SetWatcher = function(self, watcher)
        self.watcher = watcher
        -- Quest-log membership flip recomputes availability (accept locks
        -- in exclusiveTo / unlocks parentQuest children, removal opens
        -- things back up).
        watcher:RegisterCallback("OnQuestAdded",   function() self:_Schedule() end)
        watcher:RegisterCallback("OnQuestRemoved", function() self:_Schedule() end)
        self:_Schedule()
    end;

    -- Collapse bursts of triggers (OnQuestAdded fires once per quest during
    -- the watcher's first full refresh) into a single recompute at end of
    -- frame via a 0-delay timer.
    _Schedule = function(self)
        if self._recomputeScheduled then return end
        self._recomputeScheduled = true
        C_Timer.After(0, function()
            self._recomputeScheduled = false
            self:Recompute()
        end)
    end;

    Recompute = function(self)
        local quests = MUI_QuestDB:GetAll()
        if not quests then return end

        _ensurePlayerFlags()

        local playerLevel = UnitLevel("player") or 1
        if playerLevel < 1 then return end   -- transition flicker

        local trivialMin = _trivialThreshold(playerLevel)
        local watched    = (self.watcher and self.watcher:GetWatched()) or {}

        local isCompleted = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
        local just        = self._justCompleted
        local function completed(id)
            if just[id] then return true end
            return isCompleted and isCompleted(id) or false
        end

        local newAvailable  = {}
        local newTrivial    = {}
        local newRepeatable = {}
        for questId, q in pairs(quests) do
            local ok, isTrivial = self:_IsAvailable(
                questId, q, playerLevel, trivialMin,
                watched, completed, quests)
            if ok then
                newAvailable[questId] = true
                if isTrivial then newTrivial[questId] = true end
                if _isRepeatableQuest(q) then newRepeatable[questId] = true end
            end
        end

        self._available  = newAvailable
        self._trivial    = newTrivial
        self._repeatable = newRepeatable
        self:_FireChanged()
    end;

    -- Returns (isAvailable, isTrivial). isTrivial only meaningful when
    -- isAvailable is true; always false otherwise.
    _IsAvailable = function(self, questId, q, playerLevel, trivialMin,
                            watched, completed, quests)
        -- Already done or accepted
        if completed(questId) or watched[questId] then return false, false end

        -- Race / class bitmasks. 0 or nil = "any".
        if not _hasRace(q.requiredRaces) then return false, false end
        if not _hasClass(q.requiredClasses) then return false, false end

        -- Profession skill requirement (e.g. Alchemy 210). Quests gated on
        -- a profession-skill level Questie filters out when the player
        -- doesn't have the profession at that rank.
        if not _hasRequiredSkill(q.requiredSkill) then return false, false end

        -- Profession-rank gate (e.g. "needs Artisan Alchemy"). Empty for
        -- base Classic Era quests but Questie data can add entries via
        -- SoD / future patches.
        if not _hasRequiredRanks(q.requiredRanks) then return false, false end

        -- Reputation gate (e.g. "Honored with Thorium Brotherhood"). Both
        -- the min and max bounds must be satisfied when set.
        if not _hasRequiredRep(q.requiredMinRep, q.requiredMaxRep) then
            return false, false
        end

        -- Profession specialization (spell-id that must be known).
        if not _hasRequiredSpecialization(q.requiredSpecialization) then
            return false, false
        end

        -- requiredSpell (positive = must know, negative = must NOT know).
        if not _hasRequiredSpell(q.requiredSpell) then
            return false, false
        end

        -- Daily / weekly quests hidden after a gossip-show confirmed the
        -- NPC isn't offering this quest today.
        if self._dailyHidden and self._dailyHidden[questId] then
            return false, false
        end

        -- Level bounds.
        if q.requiredLevel and q.requiredLevel > 0
           and playerLevel < q.requiredLevel then
            return false, false
        end
        if q.requiredMaxLevel and q.requiredMaxLevel > 0
           and playerLevel > q.requiredMaxLevel then
            return false, false
        end

        -- Trivial (quest gone grey). Always kept in the available set;
        -- consumers (minimap pin manager / world-map static pin
        -- manager) decide whether to render trivials based on their
        -- own per-surface setting.
        local isTrivial = false
        if q.questLevel and q.questLevel > 0 and q.questLevel < trivialMin then
            isTrivial = true
        end

        -- Tier chain: follow-up already done or accepted → we're past.
        if q.nextQuestInChain and q.nextQuestInChain ~= 0 then
            if completed(q.nextQuestInChain) or watched[q.nextQuestInChain] then
                return false, false
            end
        end

        -- Exclusive quests: if any in the exclusiveTo list is done or active
        -- the current quest is locked out (you picked the other branch).
        if q.exclusiveTo then
            for _, ex in ipairs(q.exclusiveTo) do
                if completed(ex) or watched[ex] then return false, false end
            end
        end

        -- Child quest: parent must be in the log.
        if q.parentQuest and q.parentQuest ~= 0 then
            if not watched[q.parentQuest] then return false, false end
        end

        -- preQuestSingle: at least one must be completed. Takes precedence
        -- over preQuestGroup (Questie.QuestieDB comment: "mutually exclusive").
        local preSingle = q.preQuestSingle
        if preSingle and next(preSingle) then
            local ok = false
            for _, p in ipairs(preSingle) do
                if completed(p) then ok = true; break end
            end
            if not ok then return false, false end
        elseif q.preQuestGroup and next(q.preQuestGroup) then
            for _, p in ipairs(q.preQuestGroup) do
                if p < 0 then
                    -- Negative = required literally, no exclusiveTo alt.
                    if not completed(-p) then return false, false end
                elseif not completed(p) then
                    -- Completed via exclusiveTo branch?
                    local pq = quests[p]
                    local anyAlt = false
                    if pq and pq.exclusiveTo then
                        for _, e in ipairs(pq.exclusiveTo) do
                            if completed(e) then anyAlt = true; break end
                        end
                    end
                    if not anyAlt then return false, false end
                end
            end
        end

        -- If this quest is a breadcrumb, skip it once the target is in
        -- progress or done.
        if q.breadcrumbForQuestId and q.breadcrumbForQuestId ~= 0 then
            local t = q.breadcrumbForQuestId
            if completed(t) or watched[t] then return false, false end
        end

        -- If this quest has active breadcrumbs in the log, the player is
        -- already on a breadcrumb path to it — don't double-offer.
        if q.breadcrumbs then
            for _, b in ipairs(q.breadcrumbs) do
                if watched[b] then return false, false end
            end
        end

        if q.availableUntilCompleted and q.availableUntilCompleted ~= 0
           and completed(q.availableUntilCompleted) then
            return false, false
        end
        if q.availableStartingWith and q.availableStartingWith ~= 0 then
            local s = q.availableStartingWith
            if not (completed(s) or watched[s]) then return false, false end
        end

        return true, isTrivial
    end;

    IsTrivial = function(self, questId)
        return self._trivial[questId] and true or false
    end;

    IsRepeatable = function(self, questId)
        return self._repeatable[questId] and true or false
    end;

    -- Returns the raw [questId]=true map of currently-available quests.
    -- Treat as read-only; mutations here will be overwritten on the next
    -- Recompute. Primarily used by the diagnostic slash command.
    GetAll = function(self)
        return self._available
    end;

    IsAvailable = function(self, questId)
        return self._available[questId] and true or false
    end;

    -- Returns a list of quest-starter spec records for every available
    -- quest whose starter NPC / object has a spawn in `areaId`:
    --   { questId, name, kind = "npc"|"object", targetId,
    --     uiMapId, normX, normY }
    -- Item-starters (quest triggered by looting an item) are skipped: the
    -- loot source could be anywhere, and the pin would misleadingly plant
    -- at the quest-giver instead. Can be added in a later pass.
    GetStartersInArea = function(self, areaId)
        if not areaId then return {} end
        local quests = MUI_QuestDB:GetAll()
        if not quests then return {} end
        local uiMapId = MUI_ZoneDB:GetUiMapForArea(areaId)
        local out = {}
        for questId in pairs(self._available) do
            local q = quests[questId]
            if q and q.startedBy then
                local trivial    = self._trivial[questId]    and true or false
                local repeatable = self._repeatable[questId] and true or false
                local npcs = q.startedBy[1]
                if npcs then
                    for _, npcId in ipairs(npcs) do
                        local npc = MUI_NpcDB:Get(npcId)
                        if npc and npc.spawns and npc.spawns[areaId] then
                            for _, c in ipairs(npc.spawns[areaId]) do
                                out[#out + 1] = {
                                    questId      = questId,
                                    name         = q.name,
                                    kind         = "npc",
                                    targetId     = npcId,
                                    areaId       = areaId,
                                    uiMapId      = uiMapId,
                                    normX        = c[1] / 100,
                                    normY        = c[2] / 100,
                                    isTrivial    = trivial,
                                    isRepeatable = repeatable,
                                }
                            end
                        end
                    end
                end
                local objs = q.startedBy[2]
                if objs then
                    for _, objId in ipairs(objs) do
                        local obj = MUI_ObjectDB:Get(objId)
                        if obj and obj.spawns and obj.spawns[areaId] then
                            for _, c in ipairs(obj.spawns[areaId]) do
                                out[#out + 1] = {
                                    questId      = questId,
                                    name         = q.name,
                                    kind         = "object",
                                    targetId     = objId,
                                    areaId       = areaId,
                                    uiMapId      = uiMapId,
                                    normX        = c[1] / 100,
                                    normY        = c[2] / 100,
                                    isTrivial    = trivial,
                                    isRepeatable = repeatable,
                                }
                            end
                        end
                    end
                end
            end
        end
        return out
    end;

    RegisterChangeListener = function(self, fn)
        self._listeners[#self._listeners + 1] = fn
    end;

    _FireChanged = function(self)
        for _, fn in ipairs(self._listeners) do
            local ok, err = pcall(fn)
            if not ok then
                MUI.Print(
                    "|cffff4040MUI_QuestAvailability|r listener error: "
                    .. tostring(err))
            end
        end
    end;
}
