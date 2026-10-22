-- MUI_StatisticsTrackers: the event side of the Statistics tab. Era keeps no
-- statistics of its own, so one frame watches what retail's client would
-- count — money, consumables, kills, deaths, quests, skills, travel,
-- emotes, bosses, battlegrounds — and writes MUI_AchievementEngine's
-- tallies that MUI_StatisticsDB's rows read. Counting starts the first time
-- the addon runs; what the client can tell retroactively (skill ranks,
-- lifetime honorable kills, the purse) is read live instead.
--
-- Everything here observes: chat lines, the combat log, hooks on the API
-- the UI already calls. Nothing protected is touched.

local L = MUI.L

-- battlegrounds by instance id (GetInstanceInfo)
local BG_BY_INSTANCE = { [30] = "av", [529] = "ab", [489] = "wsg" }
-- the counters a scoreboard column feeds, by its place on the board
local BG_COLUMNS = {
    wsg = { [1] = "wsgCaps", [2] = "wsgReturns" },                -- Flags Captured, Flags Returned
    av  = { [3] = "avTowersCaptured", [4] = "avTowersDefended" },  -- Towers Assaulted, Towers Defended
}
local HEARTHSTONE = 8690
local DISENCHANT  = 13262
local RES_CLASS = { PRIEST = "resPriest", PALADIN = "resPaladin", SHAMAN = "resShaman", DRUID = "resDruid" }
local ENV_DEATH = {
    Drowning = "deathDrowning", Fatigue = "deathFatigue", Falling = "deathFalling",
    Fire = "deathFireLava", Lava = "deathFireLava",
}
-- our emotes by token (C_ChatInfo.PerformEmote)
local EMOTES = {
    HUG = "hugs", CHEER = "cheers", WAVE = "waves", BYE = "waves", LAUGH = "lols",
    FACEPALM = "facepalms", VIOLIN = "violins", DANCE = "dance", JOKE = "silly",
}
-- fish that mostly come out of schools (The Old Gnome and the Sea): Oily
-- Blackmouth, Firefin Snapper, Stonescale Eel
local SCHOOL_FISH = { [6358] = true, [6359] = true, [13422] = true }
-- a battleground's single-match bests the achievements want
local BG_BESTS = { hk = "hkBest", kb = "kbNoDeathBest", damage = "damageBest" }
-- the skill lines whose highest rank is kept: the professions, Cooking,
-- First Aid and Fishing
local SKILLS = {
    [171] = true, [164] = true, [333] = true, [202] = true, [182] = true,
    [165] = true, [186] = true, [393] = true, [197] = true,
    [185] = true, [129] = true, [356] = true,
}
local MINING, ENCHANTING, SMELTING = 186, 333, 2656
local ITEM_CLASS_CONSUMABLE, ITEM_CLASS_TRADEGOODS = 0, 7
-- food and drink cast spells all named alike: the client's names for one
local FOOD, DRINK = 433, 430
local CRITTER = 8                  -- creature type
-- a Soulstone's aura, still on the dead; the shaman's Reincarnation aside
local SOULSTONES = { 20707, 20762, 20763, 20764, 20765 }
local REINCARNATION = { [20608] = true, [20613] = true, [21169] = true, [27740] = true }

-- The spells Era's bandages, potions, flasks, elixirs and healthstones cast
-- (the client's item effects, for the items so named): the counter each
-- bumps, and its tally of kinds, by the used bag item's name (bandages) or
-- the spell's.
local CONSUMABLES = {}
for counter, kind in pairs({
    bandages      = { "bandageKinds", { 746, 1159, 3267, 3268, 7926, 7927, 10838, 10839, 18608, 18610, 23567,
                                        23568, 23569, 23696, 24412, 24413, 24414, 30020 } },
    healthPotions = { "healthPotionKinds", { 439, 440, 441, 2024, 4042, 17534 } },
    manaPotions   = { "manaPotionKinds", { 437, 438, 2023, 11903, 17530, 17531 } },
    flasks        = { "flaskKinds", { 17624, 17626, 17627, 17628, 17629 } },
    elixirs       = { "elixirKinds", { 673, 2367, 2374, 2378, 3160, 3164, 3166, 3220, 3593, 6512, 7178, 7844,
                                       8212, 11319, 11328, 11334, 11348, 11349, 11389, 11390, 11396, 11403,
                                       11405, 11406, 11407, 11474, 12608, 16589, 17535, 17537, 17538, 17539,
                                       21920, 22807, 26276, 26677, 27652, 27653, 417627 } },
    healthstones  = { nil, { 5720, 5723, 6262, 6263, 11732, 23468, 23469, 23470, 23471, 23472, 23473, 23474,
                             23475, 23476, 23477 } },
}) do
    for _, spell in ipairs(kind[2]) do CONSUMABLES[spell] = { counter = counter, tally = kind[1] } end
end

local function NpcId(guid)
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" then return tonumber(id) end
    return nil
end

class "StatisticsTrackers" : extends "Frame" {
    __init = function(self, engine)
        Frame.__init(self, "Frame", nil, "MUI_StatisticsTrackers")
        self.engine = engine
        self.playerGUID = UnitGUID("player")
        self.playerName = UnitName("player")
        self.tooltip = Frame(GameTooltip)
        self.money = GetMoney()
        self.bg = nil                 -- "av" | "ab" | "wsg" while in one
        self.bgCounted = false
        self.sessionHK = 0
        self.merchantOpen = false
        self.pendingPostage = 0
        self.lastCombat = 0
        self.lastEnv, self.lastEnvAt = nil, 0
        self.lastUsed, self.lastUsedAt = nil, 0           -- the bag item last clicked
        self.lastDisenchantAt = 0
        self.pendingRes, self.pendingResAt = nil, 0       -- class of who offered a res
        self.pendingPortal, self.pendingPortalAt = nil, 0 -- "Portal to X" clicked
        self.finalBosses = {}
        for _, b in ipairs(MUI_StatisticsDB:GetFinalBosses()) do self.finalBosses[b[1]] = true end
        self.lootSelf    = MUI.FormatMatcher(LOOT_ITEM_SELF)
        self.lootSelfN   = MUI.FormatMatcher(LOOT_ITEM_SELF_MULTIPLE)
        self.lootPushed  = MUI.FormatMatcher(LOOT_ITEM_PUSHED_SELF)
        self.lootPushedN = MUI.FormatMatcher(LOOT_ITEM_PUSHED_SELF_MULTIPLE)
        self.duelKO      = MUI.FormatMatcher(DUEL_WINNER_KNOCKOUT)
        self.duelRetreat = MUI.FormatMatcher(DUEL_WINNER_RETREAT)
        self.gold        = MUI.FormatMatcher(GOLD_AMOUNT, true)
        self.silver      = MUI.FormatMatcher(SILVER_AMOUNT, true)
        self.copper      = MUI.FormatMatcher(COPPER_AMOUNT, true)
        -- a portal object's name ("Portal to Darnassus"): no id reaches the tooltip
        self.portalTo    = MUI.FormatMatcher(L.STAT_PORTAL_TO)
        self.auctionMail = AUCTION_SOLD_MAIL_SUBJECT:gsub("%%s.*$", "")
        self.food, self.drink = C_Spell.GetSpellName(FOOD), C_Spell.GetSpellName(DRINK)
        self.smelting = C_Spell.GetSpellName(SMELTING)
        self.critter = C_CreatureInfo.GetCreatureTypeInfo(CRITTER).name

        self:_Hook()
        self:_Register()
        C_Timer.NewTicker(0.5, function() self:_SampleSpeed() end)
        -- OnEnable runs from the first PLAYER_ENTERING_WORLD: do its work now
        self:_EnterWorld()
    end;

    -- ---- wiring --------------------------------------------------------

    _Register = function(self)
        local e = self.engine
        self:RegisterEventHandler("PLAYER_ENTERING_WORLD", function() self:_EnterWorld() end)
        self:RegisterEventHandler("PLAYER_REGEN_DISABLED", function() self.lastCombat = GetTime() end)
        self:RegisterEventHandler("COMBAT_LOG_EVENT_UNFILTERED", function() self:_CombatLog() end)
        self:RegisterEventHandler("PLAYER_MONEY", function() self:_Money() end)
        self:RegisterEventHandler("CHAT_MSG_MONEY", function(_, _, msg) self:_LootMoney(msg) end)
        self:RegisterEventHandler("CHAT_MSG_LOOT", function(_, _, msg) self:_LootItem(msg) end)
        self:RegisterEventHandler("LOOT_OPENED", function() self:_LootOpened() end)
        self:RegisterEventHandler("MERCHANT_SHOW", function() self.merchantOpen = true end)
        self:RegisterEventHandler("MERCHANT_CLOSED", function() self.merchantOpen = false end)
        self:RegisterEventHandler("MAIL_SEND_SUCCESS", function()
            e:Bump("goldPostage", self.pendingPostage)
            e:Bump("mailsSent")
            self.pendingPostage = 0
        end)
        self:RegisterEventHandler("UNIT_SPELLCAST_SUCCEEDED", function(_, _, unit, _, spellId)
            if unit == "player" then self:_Cast(spellId) end
        end)
        self:RegisterEventHandler("PLAYER_DEAD", function() self:_Died() end)
        self:RegisterEventHandler("RESURRECT_REQUEST", function(_, _, who) self:_ResOffered(who) end)
        self:RegisterEventHandler("PLAYER_ALIVE", function() self:_Alive() end)
        self:RegisterEventHandler("QUEST_TURNED_IN", function(_, _, _, _, money)
            e:Bump("quests")
            e:Bump("goldQuest", money or 0)
        end)
        self:RegisterEventHandler("SKILL_LINES_CHANGED", function() self:_Skills() end)
        self:RegisterEventHandler("TRADE_SKILL_SHOW", function() self:_TradeSkill() end)
        self:RegisterEventHandler("TRADE_SKILL_UPDATE", function() self:_TradeSkill() end)
        self:RegisterEventHandler("CRAFT_SHOW", function() self:_Craft() end)
        self:RegisterEventHandler("CRAFT_UPDATE", function() self:_Craft() end)
        self:RegisterEventHandler("CHAT_MSG_SYSTEM", function(_, _, msg) self:_System(msg) end)
        self:RegisterEventHandler("ITEM_TEXT_BEGIN", function()
            local title = ItemTextGetItem()
            if title and title ~= "" then
                e:Set("books")[title] = true
                e:Dirty("book")
            end
        end)
        self:RegisterEventHandler("PLAYER_PVP_KILLS_CHANGED", function() self:_HonorKills() end)
        self:RegisterEventHandler("UPDATE_BATTLEFIELD_SCORE", function() self:_BattlefieldScore() end)
        self:RegisterEventHandler("GLOBAL_MOUSE_DOWN", function(_, _, button)
            if button == "RightButton" then self:_PortalClick() end
        end)
    end;

    -- Hooks on what the UI calls for us: the bag click (to name the food,
    -- drink or bandage a cast then consumes), the flight, the mail, the
    -- auction house, the quest log, the summon, the self-resurrect and our
    -- emotes.
    _Hook = function(self)
        local e = self.engine
        hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot)
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local name = info and info.hyperlink and C_Item.GetItemInfo(info.hyperlink)
            if name then self.lastUsed, self.lastUsedAt = name, GetTime() end
        end)
        hooksecurefunc("TakeTaxiNode", function(index)
            e:Bump("flights")
            e:Bump("goldTaxi", TaxiNodeCost(index) or 0)
        end)
        hooksecurefunc("SendMail", function() self.pendingPostage = GetSendMailPrice() or 0 end)
        hooksecurefunc("TakeInboxMoney", function(index) self:_InboxMoney(index) end)
        hooksecurefunc("AutoLootMailItem", function(index) self:_InboxMoney(index) end)
        hooksecurefunc("PostAuction", function(_, _, _, _, numStacks) e:Bump("auctionsPosted", numStacks or 1) end)
        hooksecurefunc("PlaceAuctionBid", function(kind, index, bid) self:_Bid(kind, index, bid) end)
        hooksecurefunc("AbandonQuest", function() e:Bump("questsAbandoned") end)
        hooksecurefunc(C_SummonInfo, "ConfirmSummon", function() e:Bump("summons") end)
        hooksecurefunc(C_DeathInfo, "UseSelfResurrectOption", function(_, id) self:_SelfRes(id) end)
        hooksecurefunc(C_ChatInfo, "PerformEmote", function(token) self:_Emote(token) end)
    end;

    -- ---- the world -----------------------------------------------------

    _EnterWorld = function(self)
        local e = self.engine
        local _, kind, _, _, _, _, _, instanceID = GetInstanceInfo()
        self.bg = kind == "pvp" and BG_BY_INSTANCE[instanceID] or nil
        self.bgCounted = false
        self.sessionHK = GetPVPSessionStats() or 0
        self.money = GetMoney()
        e:Max("goldMax", self.money)
        self:_Skills()
        -- a portal clicked, then a loading screen: the portal was taken
        if self.pendingPortal and GetTime() - self.pendingPortalAt < 20 then
            e:Bump("portals")
            e:TallyBump("portalKinds", self.pendingPortal)
        end
        self.pendingPortal = nil
    end;

    -- A right click on a "Portal to X" object; _EnterWorld settles it.
    _PortalClick = function(self)
        if UnitExists("mouseover") or not self.tooltip:IsShown() then return end
        local text = FontString(GameTooltipTextLeft1):GetText()
        local dest = text and self.portalTo(text)
        if dest then self.pendingPortal, self.pendingPortalAt = dest, GetTime() end
    end;

    _SampleSpeed = function(self)
        if IsFalling() or UnitOnTaxi("player") then return end
        local speed = GetUnitSpeed("player") or 0
        if speed > self.engine:Counter("speedTop") then
            self.engine:Max("speedTop", speed)
            self.engine:Dirty("speed")
        end
    end;

    -- ---- money ---------------------------------------------------------

    -- Every gain counts as acquired; a gain with a merchant open is a sale.
    _Money = function(self)
        local e = self.engine
        local now = GetMoney()
        local delta = now - self.money
        self.money = now
        if delta > 0 then
            e:Bump("goldTotal", delta)
            if self.merchantOpen then e:Bump("goldVendor", delta) end
        elseif delta < 0 and self.merchantOpen then
            e:Bump("goldSpentVendor", -delta)
        end
        e:Max("goldMax", now)
        e:Dirty("money")
    end;

    -- The coins in a loot line, read by the client's own words for them.
    _LootMoney = function(self, msg)
        local copper = (tonumber(self.gold(msg)) or 0) * 10000 + (tonumber(self.silver(msg)) or 0) * 100
            + (tonumber(self.copper(msg)) or 0)
        if copper > 0 then
            self.engine:Bump("goldLoot", copper)
            self.engine:Dirty("money")
        end
    end;

    -- "Auction successful" mail: its money is auction income.
    _InboxMoney = function(self, index)
        local _, _, _, subject, money = GetInboxHeaderInfo(index)
        if money and money > 0 and subject and subject:find(self.auctionMail, 1, true) then
            self.engine:Bump("goldAuction", money)
            self.engine:Max("auctionSoldMax", money)
        end
    end;

    -- A bid at the buyout is a purchase.
    _Bid = function(self, kind, index, bid)
        local e = self.engine
        bid = bid or 0
        e:Max("auctionBidMax", bid)
        local buyout = select(10, GetAuctionItemInfo(kind, index))
        if buyout and buyout > 0 and bid >= buyout then e:Bump("auctionsBought") end
    end;

    -- ---- loot ----------------------------------------------------------

    -- Our own loot lines: items, and epics by the link's colour.
    _LootItem = function(self, msg)
        local link, n = self.lootSelfN(msg)
        if not link then link = self.lootSelf(msg) end
        if not link then link, n = self.lootPushedN(msg) end
        if not link then link = self.lootPushed(msg) end
        if not link then return end
        n = tonumber(n) or 1
        local e = self.engine
        e:Bump("itemsLooted", n)
        if link:find("|cffa335ee", 1, true) or link:find("|cffff8000", 1, true) then
            e:Bump("epicsLooted", n)
        end
        e:Dirty("loot")
    end;

    -- The loot window: a fishing catch, or the shards of a disenchant.
    _LootOpened = function(self)
        local e = self.engine
        if IsFishingLoot() then
            local map = C_Map.GetBestMapForUnit("player")
            if map then e:Set("fishedZones")[map] = true end
            for i = 1, GetNumLootItems() do
                local _, _, quantity = GetLootSlotInfo(i)
                quantity = quantity or 1
                e:Bump("fishAll", quantity)
                local link = GetLootSlotLink(i)
                local itemId = link and tonumber(link:match("|Hitem:(%d+)"))
                if itemId then
                    e:Set("fishKinds")[itemId] = true
                    if SCHOOL_FISH[itemId] then e:Bump("fishSchool") end
                end
                local classID = link and select(12, C_Item.GetItemInfo(link))
                if classID == ITEM_CLASS_CONSUMABLE or classID == ITEM_CLASS_TRADEGOODS then
                    e:Bump("fish", quantity)
                end
            end
            e:Dirty("loot")
        elseif GetTime() - self.lastDisenchantAt < 3 then
            self.lastDisenchantAt = 0
            local n = 0
            for i = 1, GetNumLootItems() do
                local _, _, quantity = GetLootSlotInfo(i)
                n = n + (quantity or 1)
            end
            e:Bump("disenchantMats", n)
        end
    end;

    -- ---- casts: consumables, hearth, disenchant ------------------------

    -- A consumable's use is a spell: CONSUMABLES knows the bandages',
    -- potions', flasks', elixirs' and healthstones'; food and drink cast
    -- "Food" / "Drink". Food, drink and bandages are told apart by the bag
    -- item clicked just before.
    _Cast = function(self, spellId)
        local e = self.engine
        if spellId == HEARTHSTONE then
            e:Bump("hearths")
            e:Dirty("cast")
            return
        end
        if spellId == DISENCHANT then
            e:Bump("disenchants")
            self.lastDisenchantAt = GetTime()
            return
        end
        local name = C_Spell.GetSpellName(spellId)
        if not name then return end
        local used = GetTime() - self.lastUsedAt < 3 and self.lastUsed or nil
        local consumable = CONSUMABLES[spellId]
        if consumable then
            e:Bump(consumable.counter)
            local kind = name
            if consumable.counter == "bandages" then kind = used end
            if consumable.tally and kind then e:TallyBump(consumable.tally, kind) end
        elseif name == self.food then
            e:Bump("foods")
            if used then e:TallyBump("foodKinds", used) end
        elseif name == self.drink then
            e:Bump("drinks")
            if used then e:TallyBump("drinkKinds", used) end
        end
        e:Dirty("use")
    end;

    -- ---- combat log: kills, deaths, environment ------------------------

    _CombatLog = function(self)
        local _, sub, _, sourceGUID, _, _, _, destGUID, _, _, _, a1, a2 = C_CombatLog.GetCurrentEventInfo()
        if sourceGUID == self.playerGUID or destGUID == self.playerGUID then
            self.lastCombat = GetTime()
        end
        if destGUID == self.playerGUID then
            if sub == "ENVIRONMENTAL_DAMAGE" then
                self.lastEnv, self.lastEnvAt = a1, GetTime()
                if a1 == "Falling" and a2 and a2 > UnitHealthMax("player") * 0.5 then
                    C_Timer.After(0.5, function()
                        if UnitIsDeadOrGhost("player") then return end
                        self.engine:Bump("fallsSurvived")
                        self.engine:Dirty("fall")
                    end)
                end
            elseif sub:find("_DAMAGE$") then
                self.lastEnv = nil
            end
        end
        if sub == "PARTY_KILL" then
            if destGUID:find("^Player") then
                if sourceGUID == self.playerGUID then self:_KillingBlow() end
            elseif destGUID:find("^Creature") then
                self:_CreatureKilled(destGUID)
            end
        elseif sub == "UNIT_DIED" then
            self:_UnitDied(destGUID)
        end
    end;

    -- Kill credit, as retail gives it: any kill of the group's.
    _CreatureKilled = function(self, guid)
        local e = self.engine
        e:Bump("creaturesKilled")
        local unit = UnitTokenFromGUID(guid)
        local kind = unit and UnitCreatureType(unit)
        if kind then
            e:TallyBump("creatureTypes", kind)
            if kind == self.critter then e:Bump("crittersKilled") end
        end
        e:Dirty("kills")
    end;

    _KillingBlow = function(self)
        local e = self.engine
        e:Bump("kb")
        if self.bg then
            e:Bump("kbBG")
            e:Bump("kb_" .. self.bg)
        else
            e:Bump("kbWorld")
        end
        e:Dirty("pvp")
    end;

    -- A group member's death, or a boss's: an instance's final boss, or a
    -- raid boss (rank 3 in the NPC data), while we fought.
    _UnitDied = function(self, guid)
        local e = self.engine
        if guid:find("^Player") then
            local unit = guid ~= self.playerGUID and UnitTokenFromGUID(guid)
            if unit and (unit:find("^party") or unit:find("^raid")) then e:Bump("groupDeaths") end
            return
        end
        local npc = NpcId(guid)
        if not npc then return end
        local final = self.finalBosses[npc]
        local data = not final and MUI_NpcDB:Get(npc)
        if not final and not (data and data.rank == 3) then return end
        if not UnitAffectingCombat("player") and GetTime() - self.lastCombat > 15 then return end
        e:Bump("bossesSlain")
        if final then e:Bump("boss_" .. npc) end
    end;

    -- Honorable kills land in the session count; the zone says where.
    _HonorKills = function(self)
        local hk = GetPVPSessionStats() or 0
        local delta = hk - self.sessionHK
        self.sessionHK = hk
        if delta <= 0 then return end
        local e = self.engine
        e:Bump("hk", delta)
        if self.bg then
            e:Bump("hkBG", delta)
            e:Bump("hk_" .. self.bg, delta)
        else
            e:Bump("hkWorld", delta)
        end
        e:Dirty("pvp")
    end;

    -- ---- deaths and resurrections --------------------------------------

    _Died = function(self)
        local e = self.engine
        e:Bump("deaths")
        if self.bg then e:Bump("deaths_" .. self.bg) end
        local cause = self.lastEnv and ENV_DEATH[self.lastEnv]
        if cause and GetTime() - self.lastEnvAt < 4 then
            e:Bump(cause)
            e:Bump("death" .. self.lastEnv)
        end
        self.lastEnv = nil
        e:Dirty("death")
    end;

    -- Someone offers a resurrection: remember their class for _Alive.
    _ResOffered = function(self, who)
        who = who and who:match("^([^%-]+)") or who
        local unit
        local n = GetNumGroupMembers()
        local prefix = IsInRaid() and "raid" or "party"
        for i = 1, n do
            local u = prefix .. i
            if UnitName(u) == who then unit = u break end
        end
        local _, class = unit and UnitClass(unit)
        self.pendingRes, self.pendingResAt = class, GetTime()
    end;

    -- PLAYER_ALIVE: resurrected (or released to a ghost, which isn't).
    _Alive = function(self)
        if UnitIsGhost("player") then return end
        local key = self.pendingRes and RES_CLASS[self.pendingRes]
        if key and GetTime() - self.pendingResAt < 120 then self.engine:Bump(key) end
        self.pendingRes = nil
    end;

    -- The self-resurrection taken with a Soulstone's aura on us.
    _SelfRes = function(self, id)
        if REINCARNATION[id] then return end
        for _, spell in ipairs(SOULSTONES) do
            if C_UnitAuras.GetPlayerAuraBySpellID(spell) then
                self.engine:Bump("resSoulstone")
                return
            end
        end
    end;

    -- ---- skills --------------------------------------------------------

    -- skillmax_<skill line id>
    _Skills = function(self)
        local e = self.engine
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank = GetSkillLineInfo(i)
            local line = MUI_SkillLineDB:GetByName(name)
            if not isHeader and SKILLS[line] then e:Max("skillmax_" .. line, rank or 0) end
        end
    end;

    -- The trade skill window: how many recipes the open profession knows,
    -- as recipes_<skill line id> (Mining's window is Smelting).
    _TradeSkill = function(self)
        local prof = GetTradeSkillLine()
        if not prof or prof == "UNKNOWN" then return end
        local line = MUI_SkillLineDB:GetByName(prof) or (prof == self.smelting and MINING)
        if not line then return end
        local n = 0
        for i = 1, GetNumTradeSkills() do
            local _, kind = GetTradeSkillInfo(i)
            if kind and kind ~= "header" then n = n + 1 end
        end
        if n > 0 then
            self.engine:Max("recipes_" .. line, n)
            self.engine:Dirty("recipes")
        end
    end;

    -- The craft window: Enchanting (Beast Training shares the frame).
    _Craft = function(self)
        if MUI_SkillLineDB:GetByName(GetCraftDisplaySkillLine()) ~= ENCHANTING then return end
        local n = 0
        for i = 1, GetNumCrafts() do
            local _, _, kind = GetCraftInfo(i)
            if kind and kind ~= "header" then n = n + 1 end
        end
        if n > 0 then
            self.engine:Max("recipes_" .. ENCHANTING, n)
            self.engine:Dirty("recipes")
        end
    end;

    -- ---- chat: duels, emotes -------------------------------------------

    _System = function(self, msg)
        local winner, loser = self.duelKO(msg)
        if not winner then winner, loser = self.duelRetreat(msg) end
        if not winner then return end
        if winner == self.playerName then
            self.engine:Bump("duelsWon")
        elseif loser == self.playerName then
            self.engine:Bump("duelsLost")
        end
        self.engine:Dirty("pvp")
    end;

    _Emote = function(self, token)
        local counter = EMOTES[token]
        if counter then
            self.engine:Bump(counter)
            self.engine:Dirty("emote")
        end
    end;

    -- ---- battlegrounds -------------------------------------------------

    -- The final scoreboard, once per match: played, won, our stat columns.
    _BattlefieldScore = function(self)
        if not self.bg or self.bgCounted then return end
        local winner = GetBattlefieldWinner()
        if winner == nil then return end
        self.bgCounted = true
        local e, bg = self.engine, self.bg
        e:Bump("bgPlayed")
        e:Bump("bg_" .. bg)
        local myRow, myFaction, myKills, myDeaths, myDamage
        local caps = { [0] = 0, [1] = 0 }     -- each side's flag captures (Warsong Perfection)
        local numStats = GetNumBattlefieldStats()
        for i = 1, GetNumBattlefieldScores() do
            local name, killingBlows, honorableKills, deaths, _, faction, _, _, _, _, damageDone = GetBattlefieldScore(i)
            if name then
                if bg == "wsg" and numStats >= 1 then
                    caps[faction or 0] = (caps[faction or 0] or 0) + (GetBattlefieldStatData(i, 1) or 0)
                end
                if name:match("^([^%-]+)") == self.playerName then
                    myRow, myFaction = i, faction
                    myKills, myDeaths, myDamage = honorableKills or 0, deaths or 0, damageDone or 0
                    e:Max(BG_BESTS.hk, myKills)
                    if bg == "ab" then e:Max("hkabBest", myKills) end
                    if myDeaths == 0 then e:Max(BG_BESTS.kb, killingBlows or 0) end
                    e:Max(BG_BESTS.damage, myDamage)
                end
            end
        end
        if not myRow then return end
        local won = winner == myFaction
        if won then
            e:Bump("bgWon")
            e:Bump("bgwin_" .. bg)
        end
        for col = 1, numStats do
            local v = GetBattlefieldStatData(myRow, col) or 0
            if v > 0 then
                e:AddBattlegroundColumn(bg, col, v)
                local key = BG_COLUMNS[bg] and BG_COLUMNS[bg][col]
                if key then e:Bump(key, v) end
            end
        end
        -- a 3-0 win: the losers never captured
        if bg == "wsg" and won then
            local enemy = myFaction == 0 and 1 or 0
            if (caps[enemy] or 0) == 0 and (caps[myFaction] or 0) >= 3 then e:Bump("perfect_wsg") end
        end
        -- a 1600-0 win: the losers' resources read zero on the score widgets
        if bg == "ab" and won and self:_ShutOut() then e:Bump("perfect_ab") end
        e:Dirty("bg")
        e:Dirty("pvp")
    end;

    -- Arathi Basin's score widgets at the end: one side's resources at 0,
    -- the other's at 1600 or more.
    _ShutOut = function(self)
        local low, high = false, false
        local function reading(v)
            if v == 0 then low = true elseif v >= 1600 then high = true end
        end
        local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(C_UIWidgetManager.GetTopCenterWidgetSetID()) or {}
        for _, w in ipairs(widgets) do
            if w.widgetType == Enum.UIWidgetVisualizationType.IconAndText then
                local info = C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo(w.widgetID)
                local v = info and info.text:match("^(%d+)/%d+")
                if v then reading(tonumber(v)) end
            elseif w.widgetType == Enum.UIWidgetVisualizationType.DoubleStatusBar then
                local info = C_UIWidgetManager.GetDoubleStatusBarWidgetVisualizationInfo(w.widgetID)
                if info then
                    reading(info.leftBarValue)
                    reading(info.rightBarValue)
                end
            end
        end
        return low and high
    end;
}
