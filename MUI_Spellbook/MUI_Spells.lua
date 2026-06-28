
local SPEC_ANCHORS = {
    [1] = {
        [772]   = 1,    -- Rend
        [6673]  = 2,    -- Battle Shout (Rank 1)
        [2687]  = 3,    -- Bloodrage
    },
    [2] = {
        [639]   = 1,    -- Holy Light (Rank 2)
        [465]   = 2,    -- Devotion Aura
        [20271] = 3,    -- Judgement
    },
    [3] = {
        [13163] = 1,    -- Aspect of Monkey
        [1978]  = 2,    -- Serpent Sting (Rank 1)
        [1494]  = 3,    -- Track Beasts
    },
    [4] = {
        [6760]  = 1,    -- Eviscerate (Rank 2)
        [53]    = 2,    -- Backstab (Rank 1)
        [1784]  = 3,    -- Stealth (Rank 1)
    },
    [5] = {
        [1243]  = 1,    -- Power Word: Fortitude (Rank 1)
        [2052]  = 2,    -- Lesser Heal (Rank 2)
        [589]   = 3,    -- Shadow Word: Pain
    },
    [7] = {
        [8042]  = 1,    -- Earth Shock (Rank 1)
        [8017]  = 2,    -- Rockbiter Weapon (Rank 1)
        [332]   = 3,    -- Healing Wave (Rank 2)
    },
    [8] = {
        [1459]  = 1,    -- Arcane Intellect (Rank 1)
        [143]   = 2,    -- Fireball (Rank 2)
        [116]   = 3,    -- Frostbolt (Rank 1),
        [3561]  = 1,    -- Teleport: Stormwind
        [3562]  = 1,    -- Teleport: Ironforge
        [3565]  = 1,    -- Teleport: Darnassus 
        [3567]  = 1,    -- Teleport: Orgrimmar
        [3563]  = 1,    -- Teleport: Undercity 
        [3566]  = 1,    -- Teleport: Thunder Bluff 
    },
    [9] = {
        [172]   = 1,    -- Corruption (Rank 1)
        [696]   = 2,    -- Demon Skin (Rank 2)
        [348]   = 3,    -- Immolate (Rank 1)
    },
    [11] = {
        [8921]  = 1,    -- Moonfire (Rank 1)
        [99]    = 2,    -- Demoralizing Roar (Rank 1)
        [1126]  = 3,    -- Mark of the Wild (Rank 1)
    },
}

local SPELLTAB_ICON_TO_SPEC = {
    [1] = {   -- WARRIOR 
        [132292] = 1,   -- Arms
        [132347] = 2,   -- Fury
        [132341] = 3,   -- Protection
    },
    [2] = {   -- PALADIN
        [135920] = 1,   -- Holy
        [135893] = 2,   -- Protection
        [135873] = 3,   -- Retribution
    },
    [3] = {   -- HUNTER
        [132164] = 1,   -- Beast Mastery
        [132222] = 2,   -- Marksmanship
        [132215] = 3,   -- Survival
    },
    [4] = {   -- ROGUE 
        [132292] = 1,   -- Assassination
        [132090] = 2,   -- Combat
        [132320] = 3,   -- Subtlety
    },
    [5] = {   -- PRIEST
        [135987] = 1,   -- Discipline
        [135920] = 2,   -- Holy
        [136207] = 3,   -- Shadow
    },
    [7] = {   -- SHAMAN
        [136048] = 1,   -- Elemental
        [136051] = 2,   -- Enhancement
        [136052] = 3,   -- Restoration
    },
    [8] = {   -- MAGE
        [135932] = 1,   -- Arcane
        [135810] = 2,   -- Fire
        [135846] = 3,   -- Frost
    },
    [9] = {   -- WARLOCK
        [136145] = 1,   -- Affliction
        [136172] = 2,   -- Demonology
        [136186] = 3,   -- Destruction
    },
    [11] = {  -- DRUID
        [136096] = 1,   -- Balance
        [132276] = 2,   -- Feral Combat
        [136041] = 3,   -- Restoration
    },
}

local QUEST_SPELLS = {

    [1] = {           -- WARRIOR
        {},
        {
            {2458}    -- Berserker Stance
        },
        {
            {71}      -- Defensive Stance
        },
    },
    [2] = {           -- PALADIN
        {
            {7328},   -- Redemption (Rank 1)
            {13819},  -- Summon Warhorse
            {23214},  -- Summon Charger
        },
        {},
        {},
    },
    [3] = {           -- HUNTER
        {
            {1515},   -- Tame Beast
            --{6991},   -- Feed Pet
            --{982},    -- Revive Pet
            --{2641},   -- Dismiss Pet
        },
        {},
        {},
    },
    [4] = {           -- ROGUES
        {},
        {},
        {},
        {
            {2842},   -- Poisons
        },
    },
    [5] = {           -- PRIEST
        {
            {10797, race=4},    -- (Night Elf) Starshards (Rank 1)
            {2651,  race=4},    -- (Night Elf) Elune's Grace (Rank 1)
            {13896, race=1},    -- (Human) Feedback (Rank 1)
        },
        {
            {13908, race=1},    -- (Human) Desperate Prayer (Rank 1)
            {13908, race=3},    -- (Dwarf) Desperate Prayer (Rank 1)
            {6346,  race=3},    -- (Dwarf) Fear Ward
        },
        {
            {9035,  race=8},    -- (Troll) Hex of Weakness (Rank 1)
            {2652,  race=5},    -- (Undead) Touch of Weakness (Rank 1)
            {18137, race=8},    -- (Troll) Shadowguard (Rank 1)
            {2944,  race=5},    -- (Undead) Devouring Plague (Rank 1)
        }
    },
    [7] = {           -- SHAMAN
        {
            {3599},   -- Searing Totem (Rank 1)
        },
        {
            {8071},   -- Stoneskin Totem (Rank 1)
        },
        {
            {5394}    -- Healing Stream Totem (Rank 1)
        },
    },
    [8] = {           -- MAGE
        {
            {10140},  -- Conjure Water (Rank 7)
        },
        {},
        {},
    },
    [9] = {           -- WARLOCK
        {},
        {
            {688},    -- Summon Imp
            {697},    -- Summon Voidwalker
            {712},    -- Summon Succubus
            {691},    -- Summon Felhunter
            {1122},   -- Inferno
            {18540},  -- Ritual of Doom
            {5784},   -- Summon Felstead
            {23161}   -- Summon Dreadstead
        },
        {},
    },
    [11] = {          -- DRUID
        {
            {18960}   -- Teleport: Moonglade
        },
        {
            {5487},   -- Bear Form
            {6807},   -- Maul (learned together with Bear Form)
            {1066},   -- Aquatic Form
        },
        {
            {8946},    -- Cure Poison
        },
    }

}

-- Per-class starter spells (auto-granted at level 1, NOT trainer-bought),
-- split per spec the same way QUEST_SPELLS is. Merged in by their own
-- pass before the spellbook scan, because for some classes (rogue,
-- warrior) the rank-1 starter form vanishes from the spellbook once a
-- higher rank is learned AND it's not offered by the trainer either —
-- our scans would never see it.
local DEFAULT_SPELLS = {
    [1] = {                 -- WARRIOR
        {2457, 78},         -- Arms:          Battle Stance, Heroic Strike
        {},                 -- Fury:
        {},                 -- Protection:
    },
    [2] = {                 -- PALADIN
        {635, 20154, 21084},-- Holy:          Holy Light, Seal of Righteousness
        {},                 -- Protection:
        {},                 -- Retribution:   
    },
    [3] = {                 -- HUNTER
        {},                 -- Beast Mastery:
        {75},               -- Marksmanship:  Auto Shot
        {2973},             -- Survival:      Raptor Strike
    },
    [4] = {                 -- ROGUE
        {2098},             -- Assassination: Eviscerate
        {1752},             -- Combat:        Sinister Strike, 
        {},                 -- Subtlety:
    },
    [5] = {                 -- PRIEST
        {},                 -- Discipline:
        {585, 2050},        -- Holy:           Smite, Lesser Heal
        {},                 -- Shadow
    },
    [6] = {{}, {}, {}},     -- (none — DK reserved)
    [7] = {                 -- SHAMAN
        {403},              -- Elemental:      Lightning Bolt
        {},                 -- Enhancement:
        {331},              -- Restoration:    Healing Wave
    },
    [8] = {                 -- MAGE
        {},                 -- Arcane:
        {133},              -- Fire:           Fireball
        {168},              -- Frost:          Frost Armor
    },
    [9] = {                 -- WARLOCK
        {},                 -- Affliction:     
        {687},              -- Demonology:     Demon Skin
        {686},              -- Destruction:    Shadow Bolt
    },
    [11] = {                -- DRUID
        {5176},             -- Balance:        Wrath
        {},                 -- Feral:
        {5185},             -- Restoration:    Healing Touch
    },
}

local SPELL_GROUPS = {

    -- Soulstones
    [693]   = 20755,
    [20752] = 20755,
    [20754] = 20755,
    [20756] = 20755,
    [20757] = 20755,

    -- Healthstones
    [6201]  = 5699,
    [6202]  = 5699,
    [11729] = 5699,
    [11730] = 5699,

    -- Firestone
    [6366]  = 17951,
    [17952] = 17951,
    [17953] = 17951,

    -- Spellstone  
    [17727] = 2362,
    [17728] = 2362,

    -- Teleport
    [3561]  = "Teleport",   -- Stormwind
    [3562]  = "Teleport",   -- Ironforge
    [3565]  = "Teleport",   -- Darnassus
    [3563]  = "Teleport",   -- Undercity
    [3567]  = "Teleport",   -- Orgrimmar
    [3566]  = "teleport",   -- Thunder Bluff

    -- Portal
    [10059] = "Portal",    -- Stormwind
    [11416] = "Portal",    -- Ironforge
    [11419] = "Portal",    -- Darnassus
    [11417] = "Portal",    -- Orgrimmar
    [11418] = "Portal",    -- Undercity
    [11420] = "Portal",    -- Thunder Bluff

    -- Detect Invisibility
    [11743] = 2970,
    [132]   = 2970,

    -- Conjure Mana Gems
    [3552]  = 759,
    [10053] = 759,
    [10054] = 759,

    -- Greater Blessings
    [25782] = 19740,
    [25916] = 19740,
    [25890] = 19977,
    [25894] = 19742,
    [25918] = 19742,
    [25895] = 1038,
    [25898] = 20217,
    [25899] = 20911,

    -- Prayer of Spirit
    [27681] = 14752
    
}

class "SpellGroup" {

    __init = function(self, name, spells)
        self._name = name
        self._spells = spells
        table.sort(self._spells, function(a, b)
            return (a.levelReq or 0) < (b.levelReq or 0)
        end)
    end;

    GetSpells = function(self)
        return self._spells
    end;

    GetName = function(self)
        return self._name
    end;

    GetTotalRanks = function(self)
        local last = nil
        local ranks = 0
        for _, spell in pairs(self._spells) do
            if not last or
               (spell.levelReq > last.levelReq) or
               (spell.levelReq == last.levelReq and spell.source ~= last.source) then
                ranks = ranks + 1
                last = spell
            end
        end
        return ranks
    end;

    GetLastKnown = function(self)
        local rank, spell = self:GetKnownRank()
        return spell
    end;

    GetKnownRank = function(self)
        local last       = nil
        local spellKnown = nil
        local rank       = 0
        local rankKnown  = 0
        for i, spell in pairs(self._spells) do
            if not last or
               (spell.levelReq > last.levelReq) or
               (spell.levelReq == last.levelReq and spell.source ~= last.source) then
                rank = rank + 1
                last = spell
            end

            if spell.isKnown then
               rankKnown = rank
               spellKnown = spell
            end
        end
        return rankKnown, spellKnown
    end;

    GetMinimalLevel = function(self)
        return self:GetLowestRank().levelReq
    end;

    GetDisplayRank = function(self)

        local firstKnown = nil
        for _, spell in ipairs(self._spells) do
            if spell.isKnown then firstKnown = spell; break end
        end
        if not firstKnown then return self._spells[1] end

        for _, spell in ipairs(self._spells) do
            if not spell.isKnown and (spell.levelReq or 0) > (firstKnown.levelReq or 0) then
                return spell
            end
        end

        local highestKnown = firstKnown
        for _, spell in ipairs(self._spells) do
            if spell.isKnown then highestKnown = spell end
        end
        return highestKnown
    end;

    GetLowestRank = function(self)
        local lowestRank = self._spells[1]
        local lowestLvl = lowestRank.levelReq

        for _, spell in pairs(self._spells) do
            if spell.levelReq < lowestLvl then
                lowestRank = spell
            end
        end

        return lowestRank
    end;

    GetHighestRank = function(self)
        local highestRank = self._spells[#self._spells]
        local highestLvl = highestRank.levelReq

        for _, spell in pairs(self._spells) do
            if spell.levelReq > highestLvl then
                highestRank = spell
            end
        end
        return highestRank
    end;

    IsTalentGroup = function(self)
        return self:GetLowestRank().source == "talent"
    end;

    IsKnown = function(self)
        for _, spell in pairs(self._spells) do
            if spell.isKnown then return true end
        end
        return false
    end;

    IsFullyKnown = function(self)
        return self:GetHighestRank().isKnown
    end;

    ResetIsKnown = function(self)
        for _, spell in pairs(self._spells) do
            if spell.spellID then
                spell.isKnown = IsPlayerSpell(spell.spellID)
            else
                spell.isKnown = false
            end
        end
    end

}

object "Spells" : extends "Module" {

    __init = function(self)
        Module.__init(self, "Spells")

        -- Hidden GameTooltip used purely to extract spell descriptions
        -- from the spellbook. Kept off-screen, never shown. Raw CreateFrame
        -- is fine here — this is a non-rendering scan helper, not UI.
        self._scanTooltip = CreateFrame("GameTooltip", "MUI_SpellScanTooltip", nil, "GameTooltipTemplate")
        self._scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

        -- Event sink. Module itself isn't a Frame; we own one for events.
        self._eventFrame = Frame("Frame", nil, "MUI_SpellsEvents")

        self._classID = 1
        self._raceID = 1

        self._skillLineToSpec = {}
    end;

    OnEnable = function(self)

        -- Fetch class ID
        local _, _, classID = UnitClass("player")
        self._classID = classID

        -- Force on the Blizzard preview-talents mode so left/right click on
        -- a talent stages the change via AddPreviewTalentPoints instead of
        -- committing immediately via LearnTalent. ApplyStashed flushes;
        -- ClearStashed resets the preview.
        C_CVar.SetCVar("previewTalentsOption", 1)

        self:UpdateFromCharacter()

        self._eventFrame:RegisterEventHandler("LEARNED_SPELL_IN_TAB", function() self:UpdateFromCharacter() end)
        self._eventFrame:RegisterEventHandler("CHARACTER_POINTS_CHANGED", function() self:UpdateFromCharacter() end)
        self._eventFrame:RegisterEventHandler("ACTIVE_TALENT_GROUP_CHANGED", function() self:UpdateFromCharacter() end)
        self._eventFrame:RegisterEventHandler("TRAINER_SHOW", function()
            C_Timer.After(0.0, function()
                self:UpdateFromTrainer()
            end)
        end)

        -- /muispells reset — wipe the saved catalogue. Useful after a bad
        -- scan (e.g. trainer-header detection regressed and everything
        -- ended up under "General"); the next spellbook event repopulates.
        ChatCommand("muispells", function(_, msg)
            local cmd = msg and string.lower(msg) or ""
            cmd = string.gsub(cmd, "^%s+", "")
            cmd = string.gsub(cmd, "%s+$", "")
            if cmd == "reset" or cmd == "clear" or cmd == "wipe" then
                self.Reset()
                DEFAULT_CHAT_FRAME:AddMessage("|cffffd200MUI:|r spell DB cleared.")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cffffd200MUI:|r /muispells reset — wipe the spell DB and re-scan.")
            end
        end)
    end;

    GetSpellGroup = function(self, name, specIndex)
        local db = specIndex and MUI_DB.data.spells.class[specIndex] or MUI_DB.data.general
        local spells = db[name]
        return spells and SpellGroup(name, spells) or nil
    end;

    Reset = function()
        MUI_DB.data.spells.general = {}
        MUI_DB.data.spells.class = {{}, {}, {}}
        MUI_DB.data.spells.trainerServiceCount = 0
    end;

    _GetGroupName = function(spellID)
        if not spellID then return nil end
        local conflated = SPELL_GROUPS[spellID] or spellID
        if type(conflated) == "string" then
            return conflated
        elseif type(conflated) == "number" then
            return C_Spell.GetSpellName(conflated)
        end
        return nil
    end;

    _MergeSpell = function(db, name, spell, overwriteSource)
        if db[name] then
            for _, other in pairs(db[name]) do
                -- Merging into existing
                if (other.spellID and spell.spellID and (other.spellID == spell.spellID)) or
                   (other.talentID and spell.talentID and (other.talentID == spell.talentID))
                then
                    if spell.spellID then
                        other.spellID  = spell.spellID
                    end

                    if spell.talentID then
                        other.talentID = spell.talentID
                    end

                    if spell.spellReq then
                        other.spellReq = spell.spellReq
                    end

                    if spell.cost then
                        other.cost = spell.cost
                    end

                    if overwriteSource and other.source ~= "quest" then
                        other.source = spell.source
                    end

                    if other.levelReq == 1 then
                        other.levelReq = spell.levelReq
                    end

                    other.isKnown  = spell.isKnown
                    other.spec = spell.spec

                    return
                end
            end
            -- If didn't merge - append new

            if not spell.source then
                spell.source = "trainer"
            end

            table.insert(db[name], spell)
        else

            if not spell.source then
                spell.source = "trainer"
            end

            db[name] = {spell}
        end

    end;

    -- =========================================================
    -- Spellbook + Talent scan
    -- =========================================================

    _ExtractTalentSpellId = function(self, talentID)
        self._scanTooltip:ClearLines()
        self._scanTooltip:SetTalent(talentID, false, false, nil)
        self._scanTooltip:Show()
        local _, spellID = self._scanTooltip:GetSpell()
        self._scanTooltip:ClearLines()
        return spellID
    end;

    _ResetIsKnown = function()
        for name, group in pairs(MUI_DB.data.spells.general) do
            SpellGroup(name, group):ResetIsKnown()
        end
        for _, spec in pairs(MUI_DB.data.spells.class) do
            for name, group in pairs(spec) do
                SpellGroup(name, group):ResetIsKnown()
            end
        end
    end;

    UpdateFromCharacter = function(self)

        -- Reset known state for spells - we may have unlearned spells.
        self._ResetIsKnown()

        local db = MUI_DB.data.spells

        -- Merge quest spells.
        local _, _, classID = UnitClass("player")
        local questSpells = QUEST_SPELLS[classID]
        if questSpells then
            for specIndex, spells in ipairs(questSpells) do
                for _, spell in ipairs(spells) do

                    local spellID = spell[1]
                    local raceID = spell.race

                    if not raceID or raceID == self._raceID then
                        local name = C_Spell.GetSpellName(spellID)
                        local rank = C_Spell.GetSpellSubtext(spellID) or ""
                        local levelReq = GetSpellLevelLearned(spellID) or 1
                        local isKnown = IsPlayerSpell(spellID) or false
                        local isPassive = IsPassiveSpell(spellID)
                        local def = {
                            spellID   = spellID,
                            name      = name,
                            spec      = (specIndex == 4) and nil or specIndex,
                            rank      = rank,
                            levelReq  = levelReq,
                            isKnown   = isKnown,
                            isPassive = isPassive,
                            source    = "quest"
                        }

                        if specIndex == 4 then
                            self._MergeSpell(db.general, self._GetGroupName(spellID), def)
                        else
                            self._MergeSpell(db.class[specIndex], self._GetGroupName(spellID), def)
                        end

                    end
                end
            end
        end

        -- Merge default (auto-granted starter) spells. Runs BEFORE the
        -- spellbook scan because some classes' rank-1 starters disappear
        -- from the spellbook once a higher rank is learned, and they're
        -- never offered at the trainer either — we'd otherwise miss them.
        local defaultSpells = DEFAULT_SPELLS[classID]
        if defaultSpells then
            for specIndex, spells in ipairs(defaultSpells) do
                for _, spellID in ipairs(spells) do
                    local name = C_Spell.GetSpellName(spellID)
                    local rank = C_Spell.GetSpellSubtext(spellID) or ""
                    local levelReq = GetSpellLevelLearned(spellID) or 1
                    local isKnown = IsPlayerSpell(spellID) or false
                    local isPassive = IsPassiveSpell(spellID)
                    local def = {
                        spellID   = spellID,
                        name      = name,
                        spec      = specIndex,
                        rank      = rank,
                        levelReq  = levelReq,
                        isKnown   = isKnown,
                        isPassive = isPassive,
                        source    = "default",
                    }
                    self._MergeSpell(db.class[specIndex], self._GetGroupName(spellID), def)
                end
            end
        end

        -- Merge talent spells
        for specIndex = 1, GetNumTalentTabs() do
            for i = 1, GetNumTalents(specIndex) do
                local info = C_SpecializationInfo.GetTalentInfo({
                    specializationIndex = specIndex,
                    talentIndex         = i,
                    isInspect           = false,
                    isPet               = false,
                })

                if info then

                    local talentID = info.talentID
                    local spellID = self:_ExtractTalentSpellId(talentID)

                    -- Talents which do not have a single point assigned
                    -- return nil for spellID.

                    -- Prefer the canonical spell name over the talent's
                    -- own name so any trainer-bought higher ranks (which
                    -- come in via the spellbook scan) merge into the same
                    -- DB bucket. Fall back to info.name for 0-point
                    -- talents (spellID nil).
                    local name = spellID and C_Spell.GetSpellName(spellID) or info.name
                    local rank = spellID and C_Spell.GetSpellSubtext(spellID) or ""
                    local levelReq = 10 + (info.tier - 1) * 5
                    local isKnown = info.rank > 0
                    local isPassive = true
                    local isExceptional = info.isExceptional

                    if spellID then
                        isPassive = IsPassiveSpell(spellID)
                    end

                    local def = {
                        spellID       = spellID,
                        name          = name,
                        spec          = specIndex,
                        talentID      = info.talentID,
                        rank          = rank,
                        levelReq      = levelReq,
                        isKnown       = isKnown,
                        isPassive     = isPassive,
                        isExceptional = isExceptional,
                        source        = "talent",
                        gridX         = info.column,
                        gridY         = info.tier,
                        maxRank       = info.maxRank,
                        icon          = info.icon,
                    }

                    self._MergeSpell(db.class[specIndex], self._GetGroupName(spellID) or name, def)
                end
            end
        end

        -- "Show all spell ranks" (the spellbook checkbox) MUST be ON for
        -- GetSpellBookItemInfo / GetSpellTabInfo to expose every learned
        -- rank — otherwise the scan only sees the highest rank and our
        -- DB would miss the rest. Force ON for the scan, restore after.
        -- (Bonus: this CVar being OFF also makes GetCurrentLevelSpells
        -- ACCESS_VIOLATION the client, which is one of several reasons
        -- we don't call it at all — see DEFAULT_SPELLS above.)
        local prevShowAllRanks = GetCVarBool("ShowAllSpellRanks")
        if not prevShowAllRanks then
            SetCVar("ShowAllSpellRanks", "1")
        end

        -- Returns the spec index a default spell belongs to (per
        -- DEFAULT_SPELLS), or nil if the spellID isn't a starter. Used
        -- in the spellbook scan to (a) tag the source as "default" and
        -- (b) route the merge into the SAME bucket the default-pass
        -- already placed it in, regardless of which spellbook tab it
        -- happens to live under.
        local function IsDefault(spellID)
            for specIndex, spells in ipairs(DEFAULT_SPELLS[self._classID] or {}) do
                for _, defaultID in ipairs(spells) do
                    if spellID == defaultID then
                        return specIndex
                    end
                end
            end
            return nil
        end

        -- Scan spellbook
	    for tab = 1, GetNumSpellTabs() do
		    local _, tabIcon, offset, count = GetSpellTabInfo(tab)

            local specIndex = SPELLTAB_ICON_TO_SPEC[self._classID][tabIcon]

            for i = offset + 1, offset + count do
                local _, spellID = GetSpellBookItemInfo(i, "spell")
                local name = C_Spell.GetSpellName(spellID)
                local rank = C_Spell.GetSpellSubtext(spellID) or ""
                local levelReq = GetSpellLevelLearned(spellID)
                local isPassive = IsPassiveSpell(spellID)
                local source

                if tab == 1 then
                    local isProfession = MUI_ModuleProfessions:IsProfessionSpell(spellID)
                    source = (isProfession and "profession") or
                             (levelReq <= 1 and "default") or
                             "trainer"
                else
                    source = IsDefault(spellID) and "default" or "trainer"
                end

                local routedSpec = defaultSpec or specIndex

                local def = {
                    spellID   = spellID,
                    name      = name,
                    spec      = specIndex,
                    rank      = rank,
                    levelReq  = levelReq,
                    isKnown   = true,
                    isPassive = isPassive,
                    source    = source,
                }

                if routedSpec then
                    self._MergeSpell(db.class[routedSpec], self._GetGroupName(spellID), def)
                else
                    self._MergeSpell(db.general, self._GetGroupName(spellID), def)
                end

            end

        end

        if not prevShowAllRanks then
            SetCVar("ShowAllSpellRanks", "0")
        end

        EventRegistry:TriggerEvent("MUI_SPELLS_UPDATED")

    end;

    -- =========================================================
    -- Trainer scan
    -- =========================================================

    _ExtractServiceSpellId = function(self, serviceIndex)
        self._scanTooltip:ClearLines()
        self._scanTooltip:SetTrainerService(serviceIndex)
        local _, spellID = self._scanTooltip:GetSpell()
        self._scanTooltip:ClearLines()
        return spellID
    end;

    UpdateFromTrainer = function(self)

        if IsTradeskillTrainer() then
            return
        end

        SetTrainerServiceTypeFilter("available",   true, false)
        SetTrainerServiceTypeFilter("unavailable", true, false)
        SetTrainerServiceTypeFilter("used",        true, false)
        ExpandTrainerSkillLine(0)

        C_Timer.After(0.0, function()

            local numServices = GetNumTrainerServices()
            if not numServices or numServices == 0 then return end
            if numServices == MUI_DB.data.spells.trainerServiceCount then return end
            if numServices > MUI_DB.data.spells.trainerServiceCount then
                MUI_DB.data.spells.trainerServiceCount = numServices
            end

            local spells = {}
            local anchors = SPEC_ANCHORS[self._classID]

            local processed = 0

            for i = 1, numServices do

                local name, rank, category = GetTrainerServiceInfo(i)

                if category ~= "header" then

                    local spellID = self:_ExtractServiceSpellId(i)

                    if spellID then
                        -- The trainer service name occasionally diverges
                        -- from the spell's canonical name (e.g. "Track
                        -- Humanoid" vs "Track Humanoids" for spellID 5225)
                        -- and the two would land in separate DB buckets.
                        -- Always prefer the canonical name.
                        name = C_Spell.GetSpellName(spellID) or name

                        local levelReq = GetTrainerServiceLevelReq(i)
                        local isKnown = IsPlayerSpell(spellID) or false -- category == "used"
                        local isPassive = IsPassiveSpell(spellID)
                        local cost = GetTrainerServiceCost(i)
                        local spellReq = GetTrainerServiceAbilityReq(i, 1)

                        -- Map skill-line to spec index
                        local skillLineName = GetTrainerServiceSkillLine(i)
                        local specIndex = anchors[spellID]
                        if specIndex then
                            self._skillLineToSpec[skillLineName] = specIndex
                        end

                        local groupName = self._GetGroupName(spellID) or name

                        if not spells[skillLineName] then spells[skillLineName] = {} end
                        if not spells[skillLineName][groupName] then spells[skillLineName][groupName] = {} end

                        local def = {
                            spellID    = spellID,
                            name       = name,
                            spec       = specIndex,
                            rank       = rank or "",
                            levelReq   = levelReq,
                            spellReq   = spellReq,
                            isKnown    = isKnown,
                            isPassive  = isPassive,
                            source     = "trainer",
                            cost       = cost
                        }

                        table.insert(spells[skillLineName][groupName], def)
                        processed = processed + 1
                    else
                        --print("Didn't manage to get spell ID for", name, "(" .. rank .. ")")
                    end
                end
            end

            for skillLine, spellsSpec in pairs(spells) do
                local spec = self._skillLineToSpec[skillLine]
                local db
                if spec then
                    db = MUI_DB.data.spells.class[spec]
                else
                    db = MUI_DB.data.spells.general
                end

                for name, group in pairs(spellsSpec) do
                    for _, spell in ipairs(group) do
                        spell.spec = spec
                        self._MergeSpell(db, name, spell, true)
                    end
                end
            end

            MUI.Print("|cff00ff00ModernUI: |cffffffff Updated spells DB with " .. processed .. " entries")

            EventRegistry:TriggerEvent("MUI_SPELLS_UPDATED")

        end)

    end;
}
