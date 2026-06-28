-- ClassTree: class spell tree. Builds a SpellGrid populated with the
-- class's spells & talents, laid out per spec across COLS×ROWS slots.
-- Used as the LEFT grid in TabTalents.

local COLS = 9
local ROWS = 10

-- Per-spec base column for starter / pinned talents.
local SPEC_BASE_COLUMNS = { [1] = 2, [2] = 4, [3] = 6 }

-- Row-priority weights. Tune to reshape how the algorithm fills slots:
--   WEIGHT_BELOW_EMPTY  added when the slot directly above is empty
--   WEIGHT_CENTRALITY   indexed by distance from grid center
--   WEIGHT_BOUNDARY     bias on the two outermost columns
local WEIGHT_BELOW_EMPTY = 3
local WEIGHT_CENTRALITY  = { [0] = 2, [1] = 2, [2] = 0, [3] = -1, [4] = -1 }
local WEIGHT_BOUNDARY    = 0

-- Per-spec column biases applied on top of the row priority during the
-- per-spec DP fill. Steers each spec toward its own band of columns.
local SPEC_BONUSES = {
    [1] = { 0, 1, 1, 0, -1, -2, -3, -4, -5 },
    [2] = { -1, 0, 0, 1, 1, 1, 0, 0, -1 },
    [3] = { -5, -4, -3, -2, -1, 0, 1, 1, 0 },
}

-- Role per class+spec; drives the harmful/helpful tiebreak when picking
-- a starter spell.
local SPEC_ROLE = {
    [1]  = { "dps",  "dps",  "tank" },  -- Warrior
    [2]  = { "heal", "tank", "dps"  },  -- Paladin
    [3]  = { "dps",  "dps",  "dps"  },  -- Hunter
    [4]  = { "dps",  "dps",  "dps"  },  -- Rogue
    [5]  = { "heal", "heal", "dps"  },  -- Priest
    [6]  = { "tank", "dps",  "dps"  },  -- DK
    [7]  = { "dps",  "dps",  "heal" },  -- Shaman
    [8]  = { "dps",  "dps",  "dps"  },  -- Mage
    [9]  = { "dps",  "dps",  "dps"  },  -- Warlock
    [11] = { "dps",  "tank", "heal" },  -- Druid
}

local STARTER_SOURCE_PRIORITY = { "default", "quest", "trainer" }


class "ClassTree" : extends "SpellGrid" {

    __init = function(self, parent, name)
        SpellGrid.__init(self, parent, name, ROWS, COLS, true)
        self._specFocus = nil
    end;

    SetSpecFocus = function(self, spec)
        self._specFocus = spec
    end;

    -- Pick the representative def for a single spell's rank list. Walks the
    -- starter source priority (default > quest > trainer); within the highest
    -- source that has any entries, picks the lowest-levelReq def.
    _PickBestDef = function(self, defs)
        for _, source in ipairs(STARTER_SOURCE_PRIORITY) do
            local bestDef = nil
            for _, d in ipairs(defs) do
                if d.source == source and d.spellID then
                    if not bestDef or (d.levelReq or 0) < (bestDef.levelReq or 0) then
                        bestDef = d
                    end
                end
            end
            if bestDef then return bestDef end
        end
        return nil
    end;

    -- Pick the def that drives the slot's icon + tooltip — the "next-to-learn"
    -- rank. Lowest known rank, then first unknown above it, else highest known.
    _PickDisplayDef = function(self, defs)
        local sorted = {}
        for _, d in ipairs(defs) do
            if d.spellID then table.insert(sorted, d) end
        end
        if #sorted == 0 then return nil end
        table.sort(sorted, function(a, b) return (a.levelReq or 0) < (b.levelReq or 0) end)

        local firstKnown
        for _, d in ipairs(sorted) do
            if d.isKnown then firstKnown = d; break end
        end
        if not firstKnown then return sorted[1] end

        for _, d in ipairs(sorted) do
            if not d.isKnown and (d.levelReq or 0) > (firstKnown.levelReq or 0) then
                return d
            end
        end

        local highestKnown = firstKnown
        for _, d in ipairs(sorted) do
            if d.isKnown then highestKnown = d end
        end
        return highestKnown
    end;

    -- Same as _PickBestDef but also considers talent defs (after default/
    -- quest/trainer) so talent-only spells can land in the bands. Passive
    -- talents are skipped — they'd be pointless slot icons.
    _PickBestDefAny = function(self, defs)
        local sources = { "default", "quest", "trainer", "talent" }
        for _, source in ipairs(sources) do
            local bestDef = nil
            for _, d in ipairs(defs) do
                local eligible = d.spellID and d.source == source
                    and not (source == "talent" and d.isPassive)
                if eligible then
                    if not bestDef or (d.levelReq or 0) < (bestDef.levelReq or 0) then
                        bestDef = d
                    end
                end
            end
            if bestDef then return bestDef end
        end
        return nil
    end;

    -- Group spells into indivisible chunks. Talents at the same level form
    -- one chunk; non-talents are single-spell chunks. Output is sorted by
    -- level so subsequent band packing preserves monotonicity.
    _BuildChunks = function(self, spells)
        table.sort(spells, function(a, b)
            if a.levelReq ~= b.levelReq then return a.levelReq < b.levelReq end
            if (a.source == "talent") ~= (b.source == "talent") then
                return a.source == "talent"
            end
            return a.name < b.name
        end)

        local chunks = {}
        local i = 1
        while i <= #spells do
            local s = spells[i]
            if s.source == "talent" then
                local chunk = { spells = { s }, level = s.levelReq }
                i = i + 1
                while i <= #spells
                    and spells[i].source == "talent"
                    and spells[i].levelReq == s.levelReq do
                    table.insert(chunk.spells, spells[i])
                    i = i + 1
                end
                table.insert(chunks, chunk)
            else
                table.insert(chunks, { spells = { s }, level = s.levelReq })
                i = i + 1
            end
        end
        return chunks
    end;

    -- Spread chunks across `numBands` bands as uniformly as possible by spell
    -- count while preserving chunk order. Each band targets
    -- ceil(remaining/remaining_bands) spells (at least minPerBand). Leftovers
    -- spill into the last band.
    _SplitIntoBands = function(self, chunks, numBands, minPerBand)
        minPerBand = minPerBand or 1
        local bands = {}
        for i = 1, numBands do bands[i] = {} end
        if #chunks == 0 then return bands end

        local total = 0
        for _, chunk in ipairs(chunks) do total = total + #chunk.spells end

        local chunkIdx = 1
        for bandIdx = 1, numBands do
            if chunkIdx > #chunks then break end
            local remainingBands = numBands - bandIdx + 1
            local placed = 0
            for b = 1, bandIdx - 1 do placed = placed + #bands[b] end
            local target = math.max(minPerBand,
                math.ceil((total - placed) / remainingBands))

            while chunkIdx <= #chunks and #bands[bandIdx] < target do
                for _, s in ipairs(chunks[chunkIdx].spells) do
                    table.insert(bands[bandIdx], s)
                end
                chunkIdx = chunkIdx + 1
            end
        end

        while chunkIdx <= #chunks do
            for _, s in ipairs(chunks[chunkIdx].spells) do
                table.insert(bands[numBands], s)
            end
            chunkIdx = chunkIdx + 1
        end

        return bands
    end;

    -- Place one row's spells:
    --   1) PRE-PASS — pin at most one talent per spec at SPEC_BASE_COLUMNS[spec].
    --   2) GLOBAL DP — pick cols jointly across the three specs so spec
    --      ordering holds and total effective priority is maximized.
    --   3) FALLBACK — any spell the DP couldn't fit lands in the highest
    --      remaining-priority free col (knowingly breaking spec ordering).
    -- Returns col → spell.
    _PlaceRow = function(self, spells, priorities)
        local slots = {}
        local remaining = {}
        local talentPlaced = { [1] = false, [2] = false, [3] = false }
        for _, s in ipairs(spells) do
            if not talentPlaced[s.specIdx] and s.source == "talent" then
                slots[SPEC_BASE_COLUMNS[s.specIdx]] = s
                talentPlaced[s.specIdx] = true
            else
                table.insert(remaining, s)
            end
        end

        local remBySpec = { [1] = {}, [2] = {}, [3] = {} }
        for _, s in ipairs(remaining) do
            table.insert(remBySpec[s.specIdx], s)
        end

        local target = {
            #remBySpec[1] + (talentPlaced[1] and 1 or 0),
            #remBySpec[2] + (talentPlaced[2] and 1 or 0),
            #remBySpec[3] + (talentPlaced[3] and 1 or 0),
        }

        local prePlacedSpec = {}
        for col, sp in pairs(slots) do prePlacedSpec[col] = sp.specIdx end

        local dp = {}
        local function key(c, n1, n2, n3)
            return ((c * 10 + n1) * 10 + n2) * 10 + n3
        end

        dp[key(0, 0, 0, 0)] = { value = 0 }

        local function relax(fromK, toK, addV, action)
            local from = dp[fromK]
            if not from then return end
            local nv = from.value + addV
            local to = dp[toK]
            if not to or to.value < nv then
                dp[toK] = { value = nv, action = action, prev = fromK }
            end
        end

        for c = 0, COLS - 1 do
            local b1 = (SPEC_BONUSES[1] and SPEC_BONUSES[1][c + 1]) or 0
            local b2 = (SPEC_BONUSES[2] and SPEC_BONUSES[2][c + 1]) or 0
            local b3 = (SPEC_BONUSES[3] and SPEC_BONUSES[3][c + 1]) or 0
            local prio = priorities[c] or 0
            local preSpec = prePlacedSpec[c]

            for n1 = 0, target[1] do
                for n2 = 0, target[2] do
                    for n3 = 0, target[3] do
                        local fromK = key(c, n1, n2, n3)
                        if dp[fromK] then
                            if preSpec then
                                local valid = true
                                if     preSpec == 1 and (n2 > 0 or n3 > 0) then valid = false
                                elseif preSpec == 2 and n3 > 0             then valid = false end
                                if valid then
                                    local nn1 = n1 + (preSpec == 1 and 1 or 0)
                                    local nn2 = n2 + (preSpec == 2 and 1 or 0)
                                    local nn3 = n3 + (preSpec == 3 and 1 or 0)
                                    relax(fromK, key(c + 1, nn1, nn2, nn3), 0, "preset")
                                end
                            else
                                relax(fromK, key(c + 1, n1, n2, n3), 0, "skip")
                                if n1 < target[1] and n2 == 0 and n3 == 0 then
                                    relax(fromK, key(c + 1, n1 + 1, n2, n3), prio + b1, "place1")
                                end
                                if n2 < target[2] and n3 == 0 then
                                    relax(fromK, key(c + 1, n1, n2 + 1, n3), prio + b2, "place2")
                                end
                                if n3 < target[3] then
                                    relax(fromK, key(c + 1, n1, n2, n3 + 1), prio + b3, "place3")
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Best end state: prefer max total placed, then max value.
        local bestKey, bestTotal, bestValue = nil, -1, -math.huge
        for n1 = 0, target[1] do
            for n2 = 0, target[2] do
                for n3 = 0, target[3] do
                    local kk = key(COLS, n1, n2, n3)
                    local st = dp[kk]
                    if st then
                        local total = n1 + n2 + n3
                        if total > bestTotal or (total == bestTotal and st.value > bestValue) then
                            bestKey, bestTotal, bestValue = kk, total, st.value
                        end
                    end
                end
            end
        end

        if not bestKey then return slots end

        local actions = {}
        local curK = bestKey
        while dp[curK] and dp[curK].prev do
            table.insert(actions, 1, dp[curK].action)
            curK = dp[curK].prev
        end

        local idx = { 1, 1, 1 }
        for i, action in ipairs(actions) do
            local c = i - 1
            if     action == "place1" then slots[c] = remBySpec[1][idx[1]]; idx[1] = idx[1] + 1
            elseif action == "place2" then slots[c] = remBySpec[2][idx[2]]; idx[2] = idx[2] + 1
            elseif action == "place3" then slots[c] = remBySpec[3][idx[3]]; idx[3] = idx[3] + 1 end
        end

        -- Any spec-X spell the DP couldn't fit lands in the best-effective-
        -- priority free col left, even if that breaks spec ordering.
        for spec = 1, 3 do
            local bonuses = SPEC_BONUSES[spec] or {}
            for i = idx[spec], #remBySpec[spec] do
                local spell = remBySpec[spec][i]
                local bestCol, bestPrio = nil, -math.huge
                for col = 0, COLS - 1 do
                    if not slots[col] then
                        local p = (priorities[col] or 0) + (bonuses[col + 1] or 0)
                        if p > bestPrio then bestPrio = p; bestCol = col end
                    end
                end
                if not bestCol then break end
                slots[bestCol] = spell
            end
        end

        return slots
    end;

    -- Spec starter: prefer `default`-source, else lowest-levelReq from
    -- quest/trainer; role-tiebreak by harmful/helpful for matching specs.
    _FindStarterSpell = function(self, bucket, role)
        if not bucket then return nil end
        local prefersHarmful = (role == "dps")
        local prefersHelpful = (role == "heal")
        local SOURCE_RANK    = { default = 1, quest = 2, trainer = 3 }

        local function isBetter(d, best)
            if not best then return true end
            local dl, bl = d.levelReq or 0, best.levelReq or 0
            if dl ~= bl then return dl < bl end
            local dr, br = SOURCE_RANK[d.source] or 99, SOURCE_RANK[best.source] or 99
            if dr ~= br then return dr < br end
            if prefersHarmful then
                local dh = C_Spell.IsSpellHarmful(d.spellID)
                local bh = C_Spell.IsSpellHarmful(best.spellID)
                if dh ~= bh then return dh and true or false end
            elseif prefersHelpful then
                local dh = C_Spell.IsSpellHelpful(d.spellID)
                local bh = C_Spell.IsSpellHelpful(best.spellID)
                if dh ~= bh then return dh and true or false end
            end
            return d.spellID < best.spellID
        end

        local function pickFrom(allowed)
            local bestName, bestDef, bestDefs = nil, nil, nil
            for name, defs in pairs(bucket) do
                for _, d in ipairs(defs) do
                    if allowed[d.source] and d.spellID then
                        if isBetter(d, bestDef) then
                            bestName, bestDef, bestDefs = name, d, defs
                        end
                    end
                end
            end
            if bestDef then
                local display = self:_PickDisplayDef(bestDefs) or bestDef
                return {
                    name       = bestName,
                    icon       = C_Spell.GetSpellTexture(display.spellID),
                    levelReq   = display.levelReq or 1,
                    displayDef = display,
                    group      = SpellGroup(bestName, bestDefs),
                }
            end
            return nil
        end

        return pickFrom({ default = true })
            or pickFrom({ quest = true, trainer = true })
    end;

    _ComputeRowPriorities = function(self, prevFilledCols)
        local filled = {}
        for _, c in ipairs(prevFilledCols) do filled[c] = true end

        local center = math.floor((COLS - 1) / 2)
        local pri = {}
        for col = 0, COLS - 1 do
            local score = 0
            if not filled[col] then score = score + WEIGHT_BELOW_EMPTY end
            local dist = math.abs(col - center)
            score = score + (WEIGHT_CENTRALITY[dist] or 0)
            pri[col] = score
        end
        pri[0]        = pri[0]        + WEIGHT_BOUNDARY
        pri[COLS - 1] = pri[COLS - 1] + WEIGHT_BOUNDARY
        return pri
    end;

    -- Stamp a placed spell onto the grid's TalentSlot at (col, row). State
    -- comes from the spell's SpellGroup so it reflects the whole rank set,
    -- not just the next-to-learn rep.
    _CreateIcon = function(self, spell, col, row)
        local slot = self:GetSlot(row + 1, col + 1)
        if not slot then return end

        local _,_,classID = UnitClass("player")
        local level       = UnitLevel("player")
        local group       = spell.group
        local displayRank = group:GetDisplayRank()
        local isKnown     = group:IsKnown()
        local isFullyKnown = group:IsFullyKnown()

        local isLearnable
        local isNext
        if displayRank.source == "talent" then
            isLearnable = false
            isNext = false
        else
            isLearnable = (not displayRank.isKnown)
                and (displayRank.levelReq <= level)
            isNext = displayRank.levelReq > level and displayRank.levelReq <= level + 2
        end

        slot:SetPassive(displayRank and displayRank.isPassive or false)
        slot:SetIcon(spell.icon)

        local numKnown = group:GetKnownRank()
        local numTotal = group:GetTotalRanks()
        if numKnown > 0 and numTotal > 1 then
            slot:SetLabel(numKnown)
        end

        if isLearnable then
            slot:SetState(3)
            slot:SetIconDesaturated(false)
            slot:SetLabel(numKnown)
            slot:SetLabelColor(0, 1, 0, 1)
        elseif isFullyKnown then
            slot:SetState(2)
            slot:SetIconDesaturated(false)
        elseif isKnown then
            slot:SetState(2)
        elseif isNext then
            slot:SetState(1)
        else
            slot:SetState(0)
        end

        if isLearnable then
            slot:SetLabelColor(0, 1, 0, 1)
        else
            slot:SetLabelColor(1, 0.82, 0, 1)
        end

        slot:SetIsNext(isNext)

        if self._specFocus then

            if displayRank.spec == self._specFocus then
                local halo = SPEC_HAZE_COLORS[classID][displayRank.spec]
                slot:SetHalo(halo[1], halo[2], halo[3], 1)
            else
                slot:SetHalo(0, 0, 0, 1)
            end

        else
            if (isNext or isLearnable) and displayRank.spec then
                local halo = SPEC_HAZE_COLORS[classID][displayRank.spec]
                slot:SetHalo(halo[1], halo[2], halo[3], 1)
            elseif isKnown and displayRank.spec then
                local halo = SPEC_HAZE_COLORS[classID][displayRank.spec]
                slot:SetHalo(halo[1], halo[2], halo[3], 1)
            else
                slot:SetHalo(0, 0, 0, 1)
            end

        end

        if displayRank.spec and displayRank.spec ~= self._specFocus then
            if slot:GetState() == 0 then
                slot:SetAlpha(0.5)
            else
                slot:SetAlpha(0.4)
            end
        else
            slot:SetAlpha(1.0)
        end

        if displayRank.spellID then
            C_Spell.RequestLoadSpellData(displayRank.spellID)
        end

        slot:SetTooltip("ANCHOR_RIGHT", function(tooltip)

            if displayRank.spellID then
                tooltip:SetSpellByID(displayRank.spellID)
            elseif displayRank.source == "talent" then
                tooltip:SetTalent(displayRank.talentID, false)
            end

            if not displayRank.isKnown then
                tooltip:AddBlank()
                if displayRank.source == "talent" then
                    tooltip:AddLine("Talent at level |cffFFFFFF" .. displayRank.levelReq .. "|cff00ff00", 0, 1, 0, false, 10.5)
                elseif displayRank.source == "quest" then
                    tooltip:AddLine("Quest at level |cffFFFFFF" .. displayRank.levelReq .. "|cff00ff00", 0, 1, 0, false, 10.5)
                elseif isLearnable then
                    tooltip:AddLine("Available at trainer", 0, 1, 0, false, 10.5)
                    tooltip:AddLine("Cost:   " .. GetCoinTextureString(displayRank.cost), 1, 1, 1)
                else
                    tooltip:AddLine("Next rank at level |cffFFFFFF" .. displayRank.levelReq .. "|cff00ff00", 0, 1, 0, false, 10.5)
                end
                
            end
        end)
        slot:Show()

        return slot
    end;

    -- Rows 0 and 1 (shared by SHORT and FULL): starters across row 0 in their
    -- spec columns; lvl<=6 non-starter spells packed left-to-right by spec
    -- across row 1's top-priority slots. Returns:
    --   placedNames[specIdx][spellName] = true for placed spells
    --   filledByRow[row] = list of occupied cols
    _BuildEarlyRows = function(self, classBuckets, roleForClass)
        local placedNames = { [1] = {}, [2] = {}, [3] = {} }
        local filledByRow = { [0] = {}, [1] = {} }

        for specIdx = 1, 3 do
            local role = roleForClass and roleForClass[specIdx]
            local starter = self:_FindStarterSpell(classBuckets and classBuckets[specIdx], role)
            if starter then
                placedNames[specIdx][starter.name] = true
                self:_CreateIcon(starter, SPEC_BASE_COLUMNS[specIdx], 0)
                table.insert(filledByRow[0], SPEC_BASE_COLUMNS[specIdx])
            end
        end

        local row1Priorities = self:_ComputeRowPriorities(filledByRow[0])

        local remaining = {}
        for specIdx = 1, 3 do
            local bucket = classBuckets and classBuckets[specIdx]
            if bucket then
                for name, defs in pairs(bucket) do
                    if not placedNames[specIdx][name] then
                        local rep = self:_PickBestDef(defs)
                        if rep and (rep.levelReq or 1) <= 6 then
                            local display = self:_PickDisplayDef(defs) or rep
                            table.insert(remaining, {
                                name       = name,
                                icon       = C_Spell.GetSpellTexture(display.spellID),
                                levelReq   = rep.levelReq or 1,
                                specIdx    = specIdx,
                                displayDef = display,
                                group      = SpellGroup(name, defs),
                            })
                        end
                    end
                end
            end
        end

        local rowSlots = self:_PlaceRow(remaining, row1Priorities)
        for col, spell in pairs(rowSlots) do
            self:_CreateIcon(spell, col, 1)
            placedNames[spell.specIdx][spell.name] = true
            table.insert(filledByRow[1], col)
        end
        table.sort(filledByRow[1])

        return { placedNames = placedNames, filledByRow = filledByRow }
    end;

    -- (Re)build the entire tree from MUI_DB. Hides every slot first so a
    -- refresh after respec / new spell learn doesn't leave stale icons.
    Refresh = function(self)
        for row = 1, ROWS do
            for col = 1, COLS do
                local slot = self:GetSlot(row, col)
                if slot then slot:Hide() end
            end
        end

        local count = MUI_DB.data.spells.trainerServiceCount or 0
        if count == 0 then return end

        local classBuckets = MUI_DB.data.spells.class
        local _, _, classID = UnitClass("player")
        local roleForClass = SPEC_ROLE[classID]

        -- SHORT: only starters + a row of lvl<=6 spells.
        if count <= 15 then
            self:_BuildEarlyRows(classBuckets, roleForClass)
            return
        end

        -- FULL: starters + lvl<=6 row, plus remaining spells distributed
        -- into level bands across rows 2..ROWS-1.
        local state = self:_BuildEarlyRows(classBuckets, roleForClass)

        local pool = {}
        for specIdx = 1, 3 do
            local bucket = classBuckets and classBuckets[specIdx]
            if bucket then
                for name, defs in pairs(bucket) do
                    local spellGroup = SpellGroup(name, defs)
                    if not state.placedNames[specIdx][name] then
                        local rep = self:_PickBestDefAny(defs)
                        if rep then
                            local firstRank = spellGroup:GetLowestRank()
                            local display = self:_PickDisplayDef(defs) or rep
                            table.insert(pool, {
                                name       = name,
                                icon       = C_Spell.GetSpellTexture(display.spellID),
                                levelReq   = firstRank.levelReq,
                                specIdx    = specIdx,
                                source     = firstRank.source,
                                displayDef = display,
                                group      = spellGroup,
                            })
                        end
                    end
                end
            end
        end

        -- General-bucket spells with a trainer def: floating entries with
        -- no fixed spec. specIdx is assigned per-band below (smallest
        -- spec count wins).
        local general = MUI_DB.data.spells.general
        if general then
            for name, defs in pairs(general) do
                local spellGroup = SpellGroup(name, defs)
                local lowestRank = spellGroup:GetLowestRank()
                if lowestRank.source == "trainer" or lowestRank.source == "quest" then
                    local display = self:_PickDisplayDef(defs) or lowestRank
                    table.insert(pool, {
                        name       = name,
                        icon       = C_Spell.GetSpellTexture(display.spellID),
                        levelReq   = lowestRank.levelReq,
                        specIdx    = nil,
                        source     = "trainer",
                        displayDef = display,
                        group      = spellGroup,
                    })
                end
            end
        end

        local chunks = self:_BuildChunks(pool)
        local bands  = self:_SplitIntoBands(chunks, ROWS - 2, 1)

        for _, band in ipairs(bands) do
            local counts = { [1] = 0, [2] = 0, [3] = 0 }
            for _, s in ipairs(band) do
                if s.specIdx then counts[s.specIdx] = counts[s.specIdx] + 1 end
            end
            for _, s in ipairs(band) do
                if not s.specIdx then
                    local minSpec = 1
                    for spec = 2, 3 do
                        if counts[spec] < counts[minSpec] then minSpec = spec end
                    end
                    s.specIdx = minSpec
                    counts[minSpec] = counts[minSpec] + 1
                end
            end
        end

        for _, band in ipairs(bands) do
            table.sort(band, function(a, b)
                if a.specIdx ~= b.specIdx then return a.specIdx < b.specIdx end
                return a.name < b.name
            end)
        end

        for bandIdx, spells in ipairs(bands) do
            local row = bandIdx + 1
            local priorities = self:_ComputeRowPriorities(state.filledByRow[row - 1])
            local rowSlots   = self:_PlaceRow(spells, priorities)

            state.filledByRow[row] = {}
            for col, spell in pairs(rowSlots) do
                self:_CreateIcon(spell, col, row)
                state.placedNames[spell.specIdx][spell.name] = true
                table.insert(state.filledByRow[row], col)
            end
            table.sort(state.filledByRow[row])
        end
    end;
}
