-- Central data source and manager for everything profession-related.
-- Owns profession identification (locale-independent via spell IDs),
-- known/learned state, and is consumed by ProfessionsOverview /
-- ProfessionsTradeSkill / future UIs.

local PROFESSIONS = {
    -- Primary professions (the player is limited to two of these)
    ALCHEMY = {
        isGathering = false,
        isPrimary = true,
        icon = MUI.TEX_ICON .. "profession-alchemy",
        spells = {
            ranks           = { 2259, 3101, 3464, 11611 },                    -- Alchemy ranks
        },
    },
    BLACKSMITHING = {
        isGathering = false,
        isPrimary = true,
        icon = MUI.TEX_ICON .. "profession-blacksmithing",
        spells = {
            ranks           = { 2018, 3100, 3538, 9785 },                     -- Blacksmithing ranks
            specializations = { 17041, 17040, 17039, 9787, 9788 },            -- Master Axe/Hammer/Sword smith, Weaponsmith, Armorsmith
        },
    },
    ENCHANTING = {
        isGathering = false,
        isPrimary = true,
        icon = MUI.TEX_ICON .. "profession-enchanting",
        spells = {
            ranks           = { 7411, 7412, 7413, 13920 },                    -- Enchanting ranks
            other           = { 13262 },                                      -- Disenchant
        },
    },
    ENGINEERING = {
        isGathering = false,
        isPrimary = true,
        icon = MUI.TEX_ICON .. "profession-engineering",
        spells = {
            ranks           = { 4036, 4037, 4038, 12656 },                    -- Engineering ranks
            specializations = { 20219, 20222 },                               -- Gnomish, Goblin
        },
    },
    HERBALISM = {
        isGathering = true,
        isPrimary = true,
        icon = MUI.TEX_ICON .. "profession-herbalism",
        spells = {
            ranks           = { 2366, 2368, 3570, 11993 },                    -- Herb Gathering ranks
            other           = { 2383 },                                       -- Find Herbs
        },
    },
    LEATHERWORKING = {
        isGathering = false,
        isPrimary = true,
        icon = MUI.TEX_ICON .. "profession-leatherworking",
        spells = {
            ranks           = { 2108, 3104, 3811, 10662 },                    -- Leatherworking ranks
            specializations = { 10656, 10658, 10660 },                        -- Dragonscale, Elemental, Tribal
        },
    },
    MINING = {
        isGathering = true,
        isPrimary = true,
        icon = MUI.TEX_ICON .. "profession-mining",
        spells = {
            ranks           = { 2575, 2576, 3564, 10248 },                    -- Mining ranks
            other           = { 2656 },                                       -- Smelting
        },
    },
    SKINNING = {
        isGathering = true,
        isPrimary = true,
        icon = MUI.TEX_ICON .. "profession-skinning",
        spells = {
            ranks           = { 8613, 8617, 8618, 10768 },                    -- Skinning ranks
        },
    },
    TAILORING = {
        isGathering = false,
        isPrimary = true,
        icon = MUI.TEX_ICON .. "profession-tailoring",
        spells = {
            ranks           = { 3908, 3909, 3910, 12180 },                    -- Tailoring ranks
        },
    },

    -- Secondary professions (no character limit)
    COOKING = {
        isGathering = false,
        isPrimary = false,
        icon = MUI.TEX_ICON .. "profession-cooking",
        spells = {
            ranks           = { 2550, 3102, 3413, 18260 },                    -- Cooking ranks
            other           = { 818 },                                        -- Basic Campfire
        },
    },
    FISHING = {
        isGathering = true,
        isPrimary = false,
        icon = MUI.TEX_ICON .. "profession-fishing",
        spells = {
            ranks           = { 7620, 7731, 7732, 18248 },                    -- Fishing ranks
        },
    },
    FIRST_AID = {
        isGathering = false,
        isPrimary = false,
        icon = MUI.TEX_ICON .. "profession-firstaid",
        spells = {
            ranks           = { 3273, 3274, 7924, 10846 },                    -- First Aid ranks
        },
    },

    -- Poisons 
    POISONS = {
        isGathering = false,
        isPrimary = false,
        icon = "Interface\\Icons\\Trade_BrewPoison",
        spells = {
            ranks           = { 2842 },
        },
    },
}

-- Localized skill-line name → PROFESSION def. Used by _RefreshSkillProgress
-- to map GetSkillLineInfo's localized row name back to one of our entries.
-- Add a new locale by copying the EN block and translating each key.
local SKILL_TO_PROFESSION = {
    EN = {
        ["Alchemy"]         = PROFESSIONS.ALCHEMY,
        ["Blacksmithing"]   = PROFESSIONS.BLACKSMITHING,
        ["Enchanting"]      = PROFESSIONS.ENCHANTING,
        ["Engineering"]     = PROFESSIONS.ENGINEERING,
        ["Herbalism"]       = PROFESSIONS.HERBALISM,
        ["Leatherworking"]  = PROFESSIONS.LEATHERWORKING,
        ["Mining"]          = PROFESSIONS.MINING,
        ["Skinning"]        = PROFESSIONS.SKINNING,
        ["Tailoring"]       = PROFESSIONS.TAILORING,
        ["Cooking"]         = PROFESSIONS.COOKING,
        ["Fishing"]         = PROFESSIONS.FISHING,
        ["First Aid"]       = PROFESSIONS.FIRST_AID,
        ["Poisons"]         = PROFESSIONS.POISONS,
    },
}

-- Map Blizzard's GetLocale() → SKILL_TO_PROFESSION table key. Fallback to EN
-- when a locale isn't translated yet — the table lookup will simply miss and
-- skill rank/maxRank will stay nil for that locale until someone adds rows.
local LOCALE_TO_KEY = {
    enUS = "EN",
    enGB = "EN",
}

-- Back-pointer so SKILL_TO_PROFESSION lookups can recover the string key.
for key, def in pairs(PROFESSIONS) do def.key = key end

-- Era profession tiers (300 cap). Sorted ascending; resolved by walking until
-- maxRank < threshold. Title constants are Blizzard globals (localized).
local PROFESSION_RANK_TITLES = {
    {  75, APPRENTICE  },
    { 150, JOURNEYMAN  },
    { 225, EXPERT      },
    { 300, ARTISAN     },
}

local function GetProfessionRankTitle(maxRank)
    if not maxRank then return "" end
    local title = ""
    for i = 1, #PROFESSION_RANK_TITLES do
        local threshold, name = PROFESSION_RANK_TITLES[i][1], PROFESSION_RANK_TITLES[i][2]
        if maxRank < threshold then break end
        title = name
    end
    return title
end


object "ModuleProfessions" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Professions")

        self._professions = {
            ALCHEMY         = nil,
            BLACKSMITHING   = nil,
            ENCHANTING      = nil,
            ENGINEERING     = nil,
            HERBALISM       = nil,
            LEATHERWORKING  = nil,
            MINING          = nil,
            SKINNING        = nil,
            TAILORING       = nil,
            COOKING         = nil,
            FISHING         = nil,
            FIRST_AID       = nil,
            POISONS         = nil,
        }

        -- Plain Frame just for event subscription; Module itself isn't a Frame.
        self._eventFrame = Frame("Frame", nil, "MUI_ModuleProfessionsEvents")

        self._subscribers = {}
        self._lastSig = nil
    end;

    -- Register a callback fired whenever the profession set or any
    -- profession's rank/spell state actually changes. Callback signature:
    --   callback(self)  -- the module instance; subscribers pull via accessors.
    -- Subscribers do NOT get an immediate fire on register — call the
    -- accessors yourself for the initial state, then react to changes.
    Subscribe = function(self, callback)
        table.insert(self._subscribers, callback)
    end;

    Unsubscribe = function(self, callback)
        for i, cb in ipairs(self._subscribers) do
            if cb == callback then
                table.remove(self._subscribers, i)
                return
            end
        end
    end;

    OnEnable = function(self)
        -- Events that can change the player's profession/skill state:
        --   PLAYER_ENTERING_WORLD   — initial scan at login/reload
        --   SKILL_LINES_CHANGED     — rank-up, learn, abandon (skill UI side)
        --   LEARNED_SPELL_IN_TAB    — explicit learning at trainer
        --   SPELLS_CHANGED          — covers unlearn + most spellbook churn
        self._refreshing = false
        self._eventFrame:RegisterEventHandler("PLAYER_ENTERING_WORLD", function() self:_Refresh() end)
        self._eventFrame:RegisterEventHandler("SKILL_LINES_CHANGED",   function() self:_Refresh() end)
        self._eventFrame:RegisterEventHandler("LEARNED_SPELL_IN_TAB",  function() self:_Refresh() end)
        self._eventFrame:RegisterEventHandler("SPELLS_CHANGED",        function() self:_Refresh() end)

        self:_Refresh()
    end;

    -- Walk PROFESSIONS, mark each as known/unknown by scanning every spellID
    -- (ranks + specializations + other). One match is enough — the player
    -- has the profession. knownSpells captures:
    --   rank           = highest learned rank spellID (last IsSpellKnown match
    --                    in def.spells.ranks; canonical "learned rank" spell,
    --                    use GetSpellInfo on it for the localized prof name).
    --   specialization = first known specialization spellID (if any).
    --   other          = first known "other" spellID (Find Herbs, Smelting,
    --                    Disenchant, Basic Campfire, …) if any.
    _Refresh = function(self)

        if self._refreshing then return end

        self._refreshing = true

        for key, def in pairs(PROFESSIONS) do
            local rank, specialization, other = nil, nil, nil

            if def.spells.ranks then
                for _, spellID in ipairs(def.spells.ranks) do
                    if IsSpellKnown(spellID, false) then rank = spellID end
                end
            end
            if def.spells.specializations then
                for _, spellID in ipairs(def.spells.specializations) do
                    if IsSpellKnown(spellID, false) then specialization = spellID; break end
                end
            end
            if def.spells.other then
                for _, spellID in ipairs(def.spells.other) do
                    if IsSpellKnown(spellID, false) then other = spellID; break end
                end
            end

            if rank or specialization or other then
                self._professions[key] = {
                    def         = def,
                    knownSpells = {
                        rank           = rank,
                        specialization = specialization,
                        other          = other,
                    },
                }
            else
                self._professions[key] = nil
            end
        end

        self:_RefreshSkillProgress()

        -- Fire subscribers only when the post-refresh state actually differs
        -- from what we last notified — events can fire many times during
        -- login / crafting without any real change.
        local newSig = self:_Signature()
        if newSig ~= self._lastSig then
            self._lastSig = newSig
            for _, callback in ipairs(self._subscribers) do
                callback(self)
            end
        end

        self._refreshing = false
    end;

    -- Deterministic string fingerprint of current profession state. Keys
    -- sorted so pairs() ordering doesn't produce spurious "changed" sigs.
    _Signature = function(self)
        local keys = {}
        for key, state in pairs(self._professions) do
            if state then table.insert(keys, key) end
        end
        table.sort(keys)

        local parts = {}
        for _, key in ipairs(keys) do
            local s = self._professions[key]
            table.insert(parts, string.format("%s:%d/%d:r=%d:s=%d:o=%d",
                key,
                s.rank or 0, s.maxRank or 0,
                s.knownSpells.rank or 0,
                s.knownSpells.specialization or 0,
                s.knownSpells.other or 0
            ))
        end
        return table.concat(parts, "|")
    end;

    -- Populate rank/maxRank/skillIndex on each known profession by walking
    -- GetSkillLineInfo. Maps the localized skill row name back to our
    -- PROFESSION def via SKILL_TO_PROFESSION[locale]; only known profs
    -- (already populated by the spell-detection pass) get updated.
    _RefreshSkillProgress = function(self)
        local skillToProf = SKILL_TO_PROFESSION[LOCALE_TO_KEY[GetLocale()] or "EN"]
                            or SKILL_TO_PROFESSION.EN

        ExpandSkillHeader(0)
        for i = 1, GetNumSkillLines() do
            local skillName, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
            if not isHeader then
                local def = skillToProf[skillName]
                if def and self._professions[def.key] then
                    self._professions[def.key].name       = skillName
                    self._professions[def.key].rank       = rank
                    self._professions[def.key].maxRank    = maxRank
                    self._professions[def.key].skillIndex = i
                    self._professions[def.key].title      = GetProfessionRankTitle(maxRank)
                end
            end
        end
    end;

    -- ====================================================================
    --  Data accessors
    -- ====================================================================

    -- Returns true if spellID is any rank, specialization, or "other"
    -- spell of a known profession (Alchemy ranks, Smelting, Find Herbs,
    -- Master Swordsmith, …). Doesn't require the player to have the
    -- profession — checks against the static PROFESSIONS table.
    IsProfessionSpell = function(self, spellID)
        local subtext = C_Spell.GetSpellSubtext(spellID)
        if subtext == APPRENTICE or
            subtext == JOURNEYMAN or
            subtext == EXPERT or
            subtext == ARTISAN or
            subtext == MASTER or
            subtext == GRAND_MASTER
        then
            return true
        end

        if not spellID then return false end
        for _, def in pairs(PROFESSIONS) do
            for _, group in pairs(def.spells) do
                for _, id in ipairs(group) do
                    if id == spellID then return true end
                end
            end
        end
        return false

    end;

    -- Generic: returns state table or nil. Key is one of the PROFESSIONS
    -- top-level keys (e.g. "ALCHEMY", "FIRST_AID").
    GetProfession = function(self, key)
        return self._professions[key]
    end;

    -- Internal dict of all profession states, keyed by canonical KEY
    -- ("ALCHEMY", …). Values are state tables for known profs, nil for
    -- unknown. Use to iterate or filter (e.g., by def.isGathering).
    GetAll = function(self)
        return self._professions
    end;

    -- Locale-aware lookup: find a state whose .name matches the given
    -- localized skill-line name (e.g., from GetTradeSkillLine()). Returns
    -- nil if no known profession matches.
    GetByLocalizedName = function(self, name)
        if not name then return nil end
        for _, state in pairs(self._professions) do
            if state and state.name == name then return state end
        end
    end;

    -- Returns the two known primary professions in skill-list order (i.e.,
    -- the order they appear in GetSkillLineInfo, which matches the in-game
    -- skill panel). Either slot may be nil.
    GetFirstPrimaryProfession = function(self)
        return self:_SortedPrimaries()[1]
    end;

    GetSecondPrimaryProfession = function(self)
        return self:_SortedPrimaries()[2]
    end;

    _SortedPrimaries = function(self)
        local list = {}
        for _, state in pairs(self._professions) do
            if state and state.def.isPrimary then
                table.insert(list, state)
            end
        end
        table.sort(list, function(a, b)
            return (a.skillIndex or math.huge) < (b.skillIndex or math.huge)
        end)
        return list
    end;

    GetCooking  = function(self) return self._professions.COOKING   end;
    GetFishing  = function(self) return self._professions.FISHING   end;
    GetFirstAid = function(self) return self._professions.FIRST_AID end;
    GetPoisons  = function(self) return self._professions.POISONS   end;

}
