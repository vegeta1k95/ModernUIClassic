-- MUI_AchievementTrackers: the event side of the achievement system. One
-- frame listens for what the criteria depend on and marks the engine's
-- dirty groups, which re-evaluate and award. Criteria that read live state
-- (level, quests, reputation, skills, spells, bags) need only the nudge;
-- tally criteria get their counters and sets written here first. The
-- Statistics tab's trackers (MUI_StatisticsTrackers) feed the tallies the
-- two share — deaths, kills, honor, loot, money, fishing, books, food,
-- emotes, battlegrounds — and nudge the engine too; this frame covers what
-- only an achievement wants: named kills, items, casts, auras, visits,
-- pets, rolls, the battleground flag stopwatch, and the like.
--
-- Everything here observes: the combat log, chat lines, the spellbook.
-- Nothing protected is touched.

local HOME_CITIES = {
    Alliance = { ["Stormwind City"] = true, ["Ironforge"] = true, ["Darnassus"] = true },
    Horde    = { ["Orgrimmar"] = true, ["Thunder Bluff"] = true, ["Undercity"] = true },
}
local ARMOR_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10 }   -- head, shoulder, chest, waist, legs, feet, wrist, hands
local ITEM_CLASS_TRADEGOODS, ITEM_CLASS_MISC = 7, 15
local SUB_MOUNT, SUB_COMPANION = 5, 2
local SUB_METAL, SUB_HERB, SUB_LEATHER = 7, 9, 6

-- GlobalString -> capture pattern ("You receive loot: %s." -> "^You receive loot: (.+)%.$");
-- a string this client lacks gives a pattern that never matches.
local function ToPattern(gs)
    if not gs then return "^%z" end
    gs = gs:gsub("%%%d%$s", "\1"):gsub("%%%d%$d", "\2"):gsub("%%s", "\1"):gsub("%%d", "\2")
    gs = gs:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    gs = gs:gsub("\1", "(.+)"):gsub("\2", "(%%d+)")
    return "^" .. gs .. "$"
end

local function NpcId(guid)
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" then return tonumber(id) end
    return nil
end

local function IsNaked()
    for _, slot in ipairs(ARMOR_SLOTS) do
        if GetInventoryItemID("player", slot) then return false end
    end
    return true
end

class "AchievementTrackers" : extends "Frame" {
    __init = function(self, engine)
        Frame.__init(self, "Frame", nil, "MUI_AchievementTrackers")
        self.engine = engine
        self.playerGUID = UnitGUID("player")
        self.playerName = UnitName("player")
        self.faction = UnitFactionGroup("player")
        self.lastCombat = 0
        self.lastAttacker, self.lastAttackerAt = nil, 0
        self.timedKillTimes = {}
        self.stratEnter = nil
        self.runDeathSeen, self.selfDied = false, false
        self.flagPickupAt, self.capsThisMatch = nil, 0
        self.roll100At = 0
        self.pendingInfo = {}     -- itemId -> handlers waiting for its info
        self.bagScanQueued = false
        self.lootSelf    = ToPattern(LOOT_ITEM_SELF)
        self.lootSelfN   = ToPattern(LOOT_ITEM_SELF_MULTIPLE)
        self.lootPushed  = ToPattern(LOOT_ITEM_PUSHED_SELF)
        self.lootPushedN = ToPattern(LOOT_ITEM_PUSHED_SELF_MULTIPLE)
        self.createSelf  = ToPattern(LOOT_ITEM_CREATED_SELF)
        self.createSelfN = ToPattern(LOOT_ITEM_CREATED_SELF_MULTIPLE)
        self.rollNeed    = ToPattern(LOOT_ROLL_ROLLED_NEED)
        self.rollGreed   = ToPattern(LOOT_ROLL_ROLLED_GREED)
        self.rollWon     = ToPattern(LOOT_ROLL_YOU_WON)

        self:_BuildWatches()
        self:_Register()
        -- OnEnable runs from the first PLAYER_ENTERING_WORLD: do its work now
        self:_EnterWorld()
        self:_ScanBags()
        self:_Tabard()
    end;

    -- What the definitions ask the events to watch for: npcs, items,
    -- spells, aura names, places.
    _BuildWatches = function(self)
        local kills, lockouts, loots, lootNames, creates = {}, {}, {}, {}, {}
        local casts, auras, costumes, selfKills, bubbles, killSpells, heals = {}, {}, {}, {}, {}, {}, {}
        local visits, instances, slain, endBosses, timedKills, timedBosses = {}, {}, {}, {}, {}, {}
        local soloBosses, allAuras = {}, {}
        local function auraName(id)
            local info = C_Spell.GetSpellInfo(id)
            return info and info.name
        end
        for _, def in ipairs(self.engine.list) do
            local c = def.crit
            if c.t == "kill" then
                for _, n in ipairs(c.npc) do kills[n] = true end
            elseif c.t == "killTimed" then
                for _, n in ipairs(c.npc) do timedKills[n] = c end
            elseif c.t == "timedBoss" then
                for _, n in ipairs(c.npc) do kills[n] = true; timedBosses[n] = c.mins end
            elseif c.t == "killAll" or c.t == "killAnyCount" then
                for _, e in ipairs(c.list) do
                    for _, n in ipairs(e.npc) do kills[n] = true end
                end
            elseif c.t == "killLockout" then
                for _, n in ipairs(c.npcs) do kills[n] = true; lockouts[n] = true end
            elseif c.t == "nodeaths" then
                for _, n in ipairs(c.npcs) do kills[n] = true; endBosses[n] = true end
            elseif c.t == "loot" or c.t == "lootOrInv" then
                for _, i in ipairs(c.item) do loots[i] = true end
            elseif c.t == "create" then
                for _, i in ipairs(c.item) do creates[i] = true end
            elseif c.t == "lootName" then
                lootNames[c.name] = true
            elseif c.t == "castSpell" or c.t == "castCount" then
                local key = "cast" .. c.spell[1]
                for _, s in ipairs(c.spell) do casts[s] = key end
            elseif c.t == "aura" then
                for _, s in ipairs(c.spell) do
                    local name = auraName(s)
                    if name then auras[name] = "gordok" end
                end
            elseif c.t == "auraAll" then
                for _, e in ipairs(c.list) do
                    for _, s in ipairs(e.spells) do
                        local name = auraName(s)
                        if name then costumes[name] = e.label end
                    end
                end
            elseif c.t == "selfKill" then
                for _, s in ipairs(c.spell) do selfKills[s] = true end
            elseif c.t == "bubbleHearth" then
                for _, s in ipairs(c.hearth) do bubbles[s] = c.shield end
            elseif c.t == "killingSpell" then
                local key = "ks" .. c.spell[1]
                for _, s in ipairs(c.spell) do killSpells[s] = key end
            elseif c.t == "healOther" then
                local key = "ho" .. c.spell[1]
                for _, s in ipairs(c.spell) do heals[s] = key end
            elseif c.t == "visit" then
                for _, a in ipairs(c.areas) do visits[a] = true end
            elseif c.t == "visitInstance" then
                for _, n in ipairs(c.names) do instances[n:lower()] = true end
            elseif c.t == "slainBy" then
                local key = "slain" .. c.npc[1]
                for _, n in ipairs(c.npc) do slain[n] = key end
            elseif c.t == "lootAll" then
                for _, e in ipairs(c.list) do
                    for _, i in ipairs(e.item) do loots[i] = true end
                end
            elseif c.t == "soloKill" then
                for _, n in ipairs(c.npcs) do soloBosses[n] = true end
            elseif c.t == "flag" and c.auras then
                allAuras[c.key] = c.auras
            elseif c.t == "blocks" then
                self.watchBlocks = true
            elseif c.t == "castAll" then
                for _, e in ipairs(c.list) do
                    if e.aura then
                        for _, s in ipairs(e.spells) do
                            local name = auraName(s)
                            if name then costumes[name] = e.label end
                        end
                    else
                        local key = "cast" .. e.spells[1]
                        for _, s in ipairs(e.spells) do casts[s] = key end
                    end
                end
            end
        end
        self.killWatch, self.lockoutWatch, self.lootWatch = kills, lockouts, loots
        self.lootNameWatch, self.createWatch, self.castWatch = lootNames, creates, casts
        self.auraWatch, self.costumeWatch, self.selfKillWatch = auras, costumes, selfKills
        self.bubbleWatch, self.killSpellWatch, self.healWatch = bubbles, killSpells, heals
        self.visitWatch, self.instanceWatch, self.slainWatch, self.endBosses = visits, instances, slain, endBosses
        self.timedKills, self.timedBosses = timedKills, timedBosses
        self.soloBosses, self.allAuras = soloBosses, allAuras
    end;

    _Register = function(self)
        local e = self.engine
        self:RegisterEventHandler("PLAYER_ENTERING_WORLD", function() self:_EnterWorld() end)
        self:RegisterEventHandler("PLAYER_REGEN_DISABLED", function() self.lastCombat = GetTime() end)
        self:RegisterEventHandler("COMBAT_LOG_EVENT_UNFILTERED", function() self:_CombatLog() end)
        self:RegisterEventHandler("QUEST_TURNED_IN", function(_, _, id) e:OnQuestTurnIn(id) end)
        self:RegisterEventHandler("PLAYER_LEVEL_UP", function() e:Dirty("level") end)
        -- The map's explored areas changed. (On the "Discovered" info message
        -- instead, a zone's last area was only counted at the next zone change.)
        self:RegisterEventHandler("MAP_EXPLORATION_UPDATED", function() e:Dirty("explore") end)
        self:RegisterEventHandler("UPDATE_FACTION", function() e:Dirty("rep") end)
        self:RegisterEventHandler("SKILL_LINES_CHANGED", function() e:Dirty("skills") end)
        self:RegisterEventHandler("SPELLS_CHANGED", function() e:Dirty("spells") end)
        self:RegisterEventHandler("LEARNED_SPELL_IN_SKILL_LINE", function() e:Dirty("spells") end)
        self:RegisterEventHandler("CHAT_MSG_LOOT", function(_, _, msg) self:_Loot(msg) end)
        self:RegisterEventHandler("CHAT_MSG_SYSTEM", function(_, _, msg) self:_System(msg) end)
        self:RegisterEventHandler("CHAT_MSG_TEXT_EMOTE", function(_, _, msg, sender) self:_Emote(msg, sender) end)
        self:RegisterUnitEventHandler("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, _, _, spellId)
            self:_Cast(spellId)
        end)
        self:RegisterUnitEventHandler("UNIT_AURA", "player", function() self:_Auras() end)
        self:RegisterUnitEventHandler("UNIT_PET", "player", function() self:_Pet() end)
        self:RegisterEventHandler("PLAYER_DEAD", function() self:_Died() end)
        self:RegisterEventHandler("PLAYER_EQUIPMENT_CHANGED", function()
            self:_Tabard()
            e:Dirty("equip")
        end)
        self:RegisterEventHandler("PLAYER_TALENT_UPDATE", function() e:Dirty("talents") end)
        self:RegisterEventHandler("ACTIVE_TALENT_GROUP_CHANGED", function() e:Dirty("talents") end)
        self:RegisterEventHandler("TAXIMAP_OPENED", function() self:_TaxiMap() end)
        self:RegisterEventHandler("TIME_PLAYED_MSG", function(_, _, total) e:OnPlayed(total or 0) end)
        hooksecurefunc("ConfirmTalentWipe", function() e:Bump("respecs") end)
        self:RegisterEventHandler("BAG_UPDATE_DELAYED", function()
            if self.bagScanQueued then return end
            self.bagScanQueued = true
            C_Timer.After(1.5, function() self:_ScanBags() end)
        end)
        self:RegisterEventHandler("BANKFRAME_OPENED", function()
            e:Dirty("banks")
            e:Dirty("bags")
        end)
        self:RegisterEventHandler("GET_ITEM_INFO_RECEIVED", function(_, _, itemId) self:_ItemInfoArrived(itemId) end)
        self:RegisterEventHandler("ZONE_CHANGED", function() self:_Visit() end)
        self:RegisterEventHandler("ZONE_CHANGED_INDOORS", function() self:_Visit() end)
        self:RegisterEventHandler("ZONE_CHANGED_NEW_AREA", function()
            self:_Visit()
            e:Dirty("explore")
        end)
        self:RegisterEventHandler("CHAT_MSG_BG_SYSTEM_ALLIANCE", function(_, _, msg) self:_Battleground(msg) end)
        self:RegisterEventHandler("CHAT_MSG_BG_SYSTEM_HORDE", function(_, _, msg) self:_Battleground(msg) end)
        self:RegisterEventHandler("CHAT_MSG_BG_SYSTEM_NEUTRAL", function(_, _, msg) self:_Battleground(msg) end)
    end;

    -- ---- the world -----------------------------------------------------

    _EnterWorld = function(self)
        self.runDeathSeen, self.selfDied = false, false
        self.capsThisMatch, self.flagPickupAt = 0, nil
        self.timedKillTimes = {}
        local name, kind = GetInstanceInfo()
        self.stratEnter = name == "Stratholme" and GetTime() or nil
        if name and (kind == "party" or kind == "raid") then
            local key = name:lower()
            if self.instanceWatch[key] and not self.engine:Set("visitedInstances")[key] then
                self.engine:Set("visitedInstances")[key] = true
                self.engine:Dirty("visit")
            end
        end
        self:_Visit()
    end;

    -- Any zone transition re-checks the three name surfaces.
    _Visit = function(self)
        local visited = self.engine:Set("visited")
        local changed = false
        for _, name in ipairs({ GetSubZoneText(), GetRealZoneText(), GetMinimapZoneText() }) do
            if name and name ~= "" and self.visitWatch[name] and not visited[name] then
                visited[name] = true
                changed = true
            end
        end
        if changed then self.engine:Dirty("visit") end
    end;

    -- "Did I take part": in combat now, or within the last fifteen seconds.
    _InRecentCombat = function(self)
        return UnitAffectingCombat("player") or GetTime() - self.lastCombat < 15
    end;

    -- ---- the combat log ------------------------------------------------

    _CombatLog = function(self)
        local _, sub, _, sourceGUID, _, _, _, destGUID, _, _, _, a1, a2, a3, a4 = C_CombatLog.GetCurrentEventInfo()
        local e = self.engine
        if sourceGUID == self.playerGUID or destGUID == self.playerGUID then
            self.lastCombat = GetTime()
        end
        if destGUID == self.playerGUID then
            if sub:find("_DAMAGE$") then
                local npc = NpcId(sourceGUID)
                if npc and self.slainWatch[npc] then
                    self.lastAttacker, self.lastAttackerAt = npc, GetTime()
                end
            end
            if self.watchBlocks and sub == "SWING_MISSED" and a1 == "BLOCK" then
                e:Bump("blocks")
                e:Dirty("blocks")
            end
        end

        if sub == "UNIT_DIED" then
            self:_UnitDied(destGUID)
        elseif sub == "PARTY_KILL" and sourceGUID == self.playerGUID then
            self:_KillingBlow(destGUID)
        elseif sub == "SWING_DAMAGE" and sourceGUID == self.playerGUID then
            self:_CritterHit(destGUID, a1)
        elseif (sub == "SPELL_DAMAGE" or sub == "RANGE_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE")
                and sourceGUID == self.playerGUID then
            self:_CritterHit(destGUID, a4)
            -- a watched spell's lethal hit: the killing-blow spells
            local key = a1 and self.killSpellWatch[a1]
            if key then
                local overkill = select(16, C_CombatLog.GetCurrentEventInfo())
                if overkill and overkill > 0 then
                    e:Bump(key)
                    e:Dirty("kills")
                end
            end
            -- our own engineering killing us
            if destGUID == self.playerGUID and self.selfKillWatch[a1] then
                local overkill = select(16, C_CombatLog.GetCurrentEventInfo())
                if overkill and overkill > 0 then
                    e:Bump("selfKill")
                    e:Dirty("death")
                end
            end
        elseif sub == "SPELL_INTERRUPT" and sourceGUID == self.playerGUID then
            e:Bump("interrupts")
            e:Dirty("interrupt")
        elseif sub == "SPELL_HEAL" and sourceGUID == self.playerGUID then
            self:_Heal(destGUID, a1, a2, a4, select(16, C_CombatLog.GetCurrentEventInfo()))
        end
    end;

    -- A watched creature died: a kill with credit when we fought; a group
    -- member died: the run is no longer flawless.
    _UnitDied = function(self, guid)
        local e = self.engine
        local npc = NpcId(guid)
        if not npc then
            local unit = guid ~= self.playerGUID and UnitTokenFromGUID(guid)
            if unit and (unit:find("^party") or unit:find("^raid")) then self.runDeathSeen = true end
            return
        end
        local timed = self.timedKills[npc]
        if timed then
            local now = GetTime()
            local kept = {}
            for _, t in ipairs(self.timedKillTimes) do
                if now - t <= timed.secs then kept[#kept + 1] = t end
            end
            kept[#kept + 1] = now
            self.timedKillTimes = kept
            if #kept >= timed.n then
                e:Bump("leeroy")
                e:Dirty("kills")
            end
        end
        if not self.killWatch[npc] or not self:_InRecentCombat() then return end
        e:RecordKill(npc)
        if self.soloBosses[npc] and GetNumGroupMembers() == 0 and (UnitLevel("player") or 0) >= 60
                and e:Counter("soloBoss") == 0 then
            e:Bump("soloBoss")
        end
        local mins = self.timedBosses[npc]
        if mins and self.stratEnter and GetTime() - self.stratEnter <= mins * 60 then
            e:Bump("deadmansprint")
        end
        if self.endBosses[npc] and not self.runDeathSeen then
            e:Bump("untouchable")
        end
        e:Dirty("kills")
    end;

    -- Our killing blow: on a creature, the naked and the near-death deeds;
    -- on a player, their class and race, and the home-city tally.
    _KillingBlow = function(self, guid)
        local e = self.engine
        if guid:find("^Creature") then
            if e:Counter("nakedKill") == 0 and IsNaked() then e:Bump("nakedKill") end
            if e:Counter("lowKill") == 0
                    and UnitHealth("player") / math.max(UnitHealthMax("player"), 1) < 0.05 then
                e:Bump("lowKill")
            end
            e:Dirty("kills")
            return
        end
        if not guid:find("^Player") then return end
        local _, class, _, race = GetPlayerInfoByGUID(guid)
        if class then e:Set("kbClass")[class] = true end
        if race then e:Set("kbRace")[race] = true end
        local zone = GetRealZoneText()
        if self.faction and zone and HOME_CITIES[self.faction] and HOME_CITIES[self.faction][zone] then
            e:Bump("kbCity")
        end
        e:Dirty("pvp")
    end;

    -- One hit on our targeted level-1 critter: the Overkill series. The log
    -- carries no creature type, so the check rides the target.
    _CritterHit = function(self, guid, amount)
        if not amount or amount <= self.engine:Counter("critterTop") then return end
        if UnitGUID("target") ~= guid then return end
        if UnitLevel("target") ~= 1 or UnitIsPlayer("target") or UnitCreatureType("target") ~= "Critter" then return end
        self.engine:Max("critterTop", amount)
        self.engine:Dirty("critter")
    end;

    -- Our heal landing: a bandage on someone under 5% (triage), a spell on
    -- someone at 1% or less (the clutch heal), a watched spell on an ally.
    _Heal = function(self, destGUID, spellId, spellName, amount, overheal)
        local e = self.engine
        if not amount then return end
        local unit = UnitTokenFromGUID(destGUID)
        if unit then
            local before = (UnitHealth(unit) - (amount - (overheal or 0))) / math.max(UnitHealthMax(unit), 1)
            if spellName == "First Aid" then
                if before < 0.05 then
                    e:Bump("triage")
                    e:Dirty("bandage")
                end
            elseif before > 0 and before <= 0.01 and destGUID ~= self.playerGUID then
                e:Bump("clutchHeal")
                e:Dirty("bandage")
            end
        end
        local key = spellId and self.healWatch[spellId]
        if key and destGUID ~= self.playerGUID then
            e:Bump(key)
            e:Dirty("cast")
        end
    end;

    _Died = function(self)
        local e = self.engine
        self.runDeathSeen, self.selfDied = true, true
        if self.lastAttacker and GetTime() - self.lastAttackerAt < 5 then
            e:Bump(self.slainWatch[self.lastAttacker])
            self.lastAttacker = nil
        end
        e:Dirty("death")
    end;

    -- ---- casts and auras -----------------------------------------------

    _Cast = function(self, spellId)
        local e = self.engine
        local key = spellId and self.castWatch[spellId]
        if key then
            e:Bump(key)
            e:Dirty("cast")
        end
        local shield = spellId and self.bubbleWatch[spellId]
        if shield and self:_HasAura(shield) then
            e:Bump("bubbleHearth")
            e:Dirty("cast")
        end
    end;

    _HasAura = function(self, wanted)
        for i = 1, 40 do
            local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
            if not aura then return false end
            if aura.name == wanted then return true end
        end
        return false
    end;

    -- One pass over our buffs: the Gordok crown, the costumes.
    _Auras = function(self)
        local e = self.engine
        local have = {}
        for i = 1, 40 do
            local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
            if not aura then break end
            have[aura.name] = true
        end
        for name, counter in pairs(self.auraWatch) do
            if have[name] and e:Counter(counter) == 0 then
                e:Bump(counter)
                e:Dirty("aura")
            end
        end
        local costumes
        for name, label in pairs(self.costumeWatch) do
            if have[name] then
                costumes = costumes or e:Set("costumes")
                if not costumes[label] then
                    costumes[label] = true
                    e:Dirty("aura")
                end
            end
        end
        -- every buff of a list at once
        for key, names in pairs(self.allAuras) do
            if e:Counter(key) == 0 then
                local all = true
                for _, name in ipairs(names) do
                    if not have[name] then all = false break end
                end
                if all then e:Bump(key) end
            end
        end
        -- a Well Fed day
        if have["Well Fed"] then
            local days = e:Set("wellFedDays")
            local stamp = date("%Y%j")
            if not days[stamp] then
                days[stamp] = true
                e:Dirty("aura")
            end
        end
    end;

    _Pet = function(self)
        if not UnitExists("pet") then return end
        local e = self.engine
        local family = UnitCreatureFamily("pet")
        if family then e:Set("petFams")[family] = true end
        local name = UnitName("pet")
        if name then e:Set("petNames")[name] = true end
        e:Dirty("pet")
    end;

    -- The tabard worn: owned, and worn at least once.
    _Tabard = function(self)
        local id = GetInventoryItemID("player", 19)
        if not id then return end
        local e = self.engine
        e:Set("tabards")[id] = true
        if e:Counter("tabardWorn") == 0 then e:Bump("tabardWorn") end
        e:Dirty("equip")
    end;

    -- The flight master's map: every node of the continent, found or not,
    -- the found ones into the continent's set.
    _TaxiMap = function(self)
        local map = C_Map.GetBestMapForUnit("player")
        while map do
            local info = C_Map.GetMapInfo(map)
            if not info then return end
            if info.mapType == Enum.UIMapType.Continent then break end
            map = info.parentMapID
        end
        if not map then return end
        local nodes = C_TaxiMap.GetAllTaxiNodes(map)
        if not nodes or #nodes == 0 then return end
        local e = self.engine
        local known = e:Set("taxi" .. map)
        for _, node in ipairs(nodes) do
            if node.state ~= Enum.FlightPathState.Unreachable then known[node.nodeID] = true end
        end
        e:Max("taxiTotal" .. map, #nodes)
        e:Dirty("taxi")
    end;

    -- ---- loot ----------------------------------------------------------

    -- Our own loot lines: items picked up, pushed into the bags or
    -- created, by id.
    _Loot = function(self, msg)
        local link, n = msg:match(self.createSelfN)
        if not link then link = msg:match(self.createSelf) end
        if link then
            self:_Created(tonumber(msg:match("|Hitem:(%d+)")), tonumber(n) or 1)
            return
        end
        link, n = msg:match(self.lootSelfN)
        if not link then link = msg:match(self.lootSelf) end
        if not link then link, n = msg:match(self.lootPushedN) end
        if not link then link = msg:match(self.lootPushed) end
        if not link then return end
        self:_Looted(tonumber(msg:match("|Hitem:(%d+)")), tonumber(n) or 1)
    end;

    _Created = function(self, itemId, count)
        if not itemId then return end
        local e = self.engine
        if self.createWatch[itemId] then e:Bump("create" .. itemId, count) end
        self:_WithItemInfo(itemId, function(id)
            local quality = select(3, C_Item.GetItemInfo(id))
            if quality and quality >= 4 then e:Bump("createEpic") end
            e:Dirty("loot")
        end)
        e:Dirty("loot")
    end;

    _Looted = function(self, itemId, count)
        if not itemId then return end
        local e = self.engine
        if self.lootWatch[itemId] then e:Set("lootItems")[itemId] = true end
        self:_WithItemInfo(itemId, function(id)
            local name, _, _, _, _, _, _, _, _, _, _, classID, subClassID = C_Item.GetItemInfo(id)
            if not name then return end
            if self.lootNameWatch[name] then e:Set("lootNames")[name] = true end
            if classID == ITEM_CLASS_TRADEGOODS then
                if subClassID == SUB_METAL then e:Bump("gather_mining", count)
                elseif subClassID == SUB_HERB then e:Bump("gather_herbs", count)
                elseif subClassID == SUB_LEATHER then e:Bump("gather_skinning", count) end
            end
            e:Dirty("loot")
        end)
        e:Dirty("loot")
    end;

    -- Run `handler(itemId)` now if the item's info is cached, else when it arrives.
    _WithItemInfo = function(self, itemId, handler)
        if C_Item.GetItemInfo(itemId) then
            handler(itemId)
            return
        end
        self.pendingInfo[itemId] = self.pendingInfo[itemId] or {}
        table.insert(self.pendingInfo[itemId], handler)
    end;

    _ItemInfoArrived = function(self, itemId)
        local handlers = self.pendingInfo[itemId]
        if not handlers then return end
        self.pendingInfo[itemId] = nil
        for _, handler in ipairs(handlers) do handler(itemId) end
    end;

    -- The bags: mounts and companions owned, by item class.
    _ScanBags = function(self)
        self.bagScanQueued = false
        local e = self.engine
        for bag = 0, 4 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID then
                    self:_WithItemInfo(info.itemID, function(id)
                        local _, _, quality, _, _, _, _, _, equipLoc, _, _, classID, subClassID = C_Item.GetItemInfo(id)
                        if classID == ITEM_CLASS_MISC and subClassID == SUB_MOUNT then
                            e:Set("mounts")[id] = true
                            if quality and quality >= 4 then e:Set("mountsEpic")[id] = true end
                            e:Dirty("bags")
                        elseif classID == ITEM_CLASS_MISC and subClassID == SUB_COMPANION then
                            e:Set("companions")[id] = true
                            e:Dirty("bags")
                        elseif equipLoc == "INVTYPE_TABARD" then
                            e:Set("tabards")[id] = true
                            e:Dirty("equip")
                        end
                    end)
                end
            end
        end
        e:Dirty("bags")
    end;

    -- ---- chat ----------------------------------------------------------

    -- Loot rolls (a 1, a 100 that won) and the last drunkenness line.
    _System = function(self, msg)
        local e = self.engine
        local roll, _, who = msg:match(self.rollNeed)
        if not roll then roll, _, who = msg:match(self.rollGreed) end
        if roll and who == self.playerName then
            if tonumber(roll) == 100 then
                self.roll100At = GetTime()
            elseif tonumber(roll) == 1 then
                e:Bump("roll1")
                e:Dirty("roll")
            end
            return
        end
        if msg:match(self.rollWon) then
            if self.roll100At > 0 and GetTime() - self.roll100At < 30 then
                e:Bump("roll100")
                self.roll100At = 0
                e:Dirty("roll")
            end
            return
        end
        if DRUNK_MESSAGE_SELF4 and msg == DRUNK_MESSAGE_SELF4 then
            e:Bump("drunk")
            e:Dirty("drunk")
        end
    end;

    -- Our emotes at a target: /love on a critter, /hug on a player; dancing
    -- without armour.
    _Emote = function(self, msg, sender)
        sender = sender and sender:match("^([^%-]+)") or sender
        if sender ~= self.playerName or not msg then return end
        local e = self.engine
        if msg:find("^You love") then
            if UnitExists("target") and not UnitIsPlayer("target") and UnitCreatureType("target") == "Critter" then
                e:Set("loved")[UnitName("target") or "?"] = true
                e:Dirty("emote")
            end
        elseif msg:find("^You burst into dance") or msg:find("^You dance") then
            if e:Counter("nakedDance") == 0 and IsNaked() then e:Bump("nakedDance") end
            e:Dirty("emote")
        else
            local hugged = msg:match("^You hug (.+)%.$")
            if hugged and UnitExists("target") and UnitIsPlayer("target") then
                e:Set("hugged")[hugged] = true
                e:Dirty("emote")
                -- a fallen enemy, still at their corpse
                if UnitIsEnemy("player", "target") and UnitIsDead("target") and not UnitIsGhost("target")
                        and e:Counter("hugDeadEnemy") == 0 then
                    e:Bump("hugDeadEnemy")
                end
            end
        end
    end;

    -- Warsong Gulch's broadcast lines: the flag-carry stopwatch for the
    -- quick capture, and the flawless three for the ironman.
    _Battleground = function(self, msg)
        if not msg:find(self.playerName, 1, true) then return end
        local e = self.engine
        if msg:find("picked up the") and msg:find("[Ff]lag") then
            self.flagPickupAt = GetTime()
        elseif msg:find("captured the") and msg:find("[Ff]lag") then
            if self.flagPickupAt and GetTime() - self.flagPickupAt <= 75 then e:Bump("quickcap") end
            self.capsThisMatch = self.capsThisMatch + 1
            if self.capsThisMatch >= 3 and not self.selfDied then e:Bump("ironman") end
            self.flagPickupAt = nil
            e:Dirty("bg")
        elseif msg:find("dropped the") then
            self.flagPickupAt = nil
        end
    end;
}
