
local ROWS = 7
local COLS = 4

-- Hidden, off-screen tooltip used only to force the client to lazy-load and
-- cache a talent rank's tooltip data ahead of the player hovering. Pushing a
-- talent hyperlink through it triggers the same fetch a real hover would.
-- rank0 is the 0-indexed hyperlink rank (rank N shows as N-1).
local preloadTip
local function PreloadTalentRank(talentID, rank0)
    if not preloadTip then
        preloadTip = Frame("GameTooltip", nil, "MUI_TalentPreloadTip", "GameTooltipTemplate")
        preloadTip._native:SetOwner(UIParent, "ANCHOR_NONE")
    end
    preloadTip._native:SetHyperlink(string.format("talent:%d:%d", talentID, rank0))
end

class "TalentGrid" : extends "SpellGrid" {

    __init = function(self, parent, name)
        SpellGrid.__init(self, parent, name, ROWS, COLS, true)

        self._pointsSpent = 0
        self._currentSpec = nil
        self._group       = nil   -- talent group to render; nil = active group

        -- Pool of prereq arrows: extra lines drawn between a talent and
        -- its prerequisite talent. Populated dynamically by Add/Clear
        -- PrereqArrow, sized lazily as we go.
        self._prereqArrows = {}
        self._prereqCount  = 0

        self._specLock = Texture(self, nil, "OVERLAY")
        self._specLock:SetTextureRegion(MUI.TEX_SKIN .. "talents\\talents", 2048, 1024, 1, 990, 170, 28)
        self._specLock:SetSize(80, 12)
        self._specLock:Hide()

        self._specLockCount = FontString(self)
        self._specLockCount:LeftOf(self._specLock, 10, -1)
        self._specLockCount:SetFontSize(20)
        self._specLockCount:SetJustifyH("RIGHT")
        self._specLockCount:SetSize(100, 14)
        self._specLockCount:SetText("0")
        self._specLockCount:SetTextColor(190/255, 136/255, 121/255, 1)
        self._specLockCount:Hide()

        self.OnUpdate = nil

        -- Auto-refresh on preview changes (clicking a slot calls
        -- AddPreviewTalentPoints which fires this event) and on actual
        -- talent commits.
        self:RegisterEventHandler("PREVIEW_TALENT_POINTS_CHANGED", function()
            if self._currentSpec then self:UpdateFromSpec(self._currentSpec) end
        end)
        self:RegisterEventHandler("PLAYER_TALENT_UPDATE", function()
            if self._currentSpec then self:UpdateFromSpec(self._currentSpec) end
        end)

    end;

    -- Total unspent points across all 3 tabs, accounting for preview
    -- subtractions. GetUnspentTalentPoints alone doesn't subtract preview.
    _GetSpareEffective = function(self, group)
        local total = UnitLevel("player") - 9
        if total < 0 then total = 0 end
        for tab = 1, 3 do
            local _, _, _, _, ps, _, pps = GetTalentTabInfo(tab, false, false, group)
            total = total - (ps or 0) - (pps or 0)
        end
        return total
    end;

    UpdateFromSpec = function(self, spec)
        -- Clear slots
        self:Clear()

        self._currentSpec = spec
        self._pointsSpent = 0

        local active        = GetActiveTalentGroup()
        local group         = self._group or active
        local isActiveGroup = group == active

        -- Clear prerequisite arrows
        for _, arrow in ipairs(self._prereqArrows) do arrow:Hide() end
        self._prereqCount = 0

        local _, _, classID = UnitClass("player")
        local _, _, _, _, pointsSpent, _, previewPointsSpent = GetTalentTabInfo(spec, false, false, group)
        local color = SPEC_HAZE_COLORS[classID][spec]

        -- Effective spent for this tab = real + staged preview. Used for
        -- tier-reach gating (tier N needs (N-1)*5 points in THIS tab).
        local effectivePointsSpent = (pointsSpent or 0) + (previewPointsSpent or 0)
        local isMaxLevel = UnitLevel("player") == 60
        local spare = self:_GetSpareEffective(group)
        local count = GetNumTalents(spec)

        local firstUnreached = nil
        local firstUnreachedX = 0
        local firstUnreachedY = 0

        -- GetTalentInfo doesn't return isPassive on its own. Pull it from
        -- the scanned spell DB, where the original talent pass already
        -- resolved the spellID and called IsPassiveSpell on it.
        local passiveByID = {}
        local bucket = MUI_DB.data.spells.class[spec]
        if bucket then
            for _, defs in pairs(bucket) do
                for _, d in ipairs(defs) do
                    if d.source == "talent" and d.talentID then
                        passiveByID[d.talentID] = d.isPassive
                    end
                end
            end
        end

        for i = 1, count do
            local info = C_SpecializationInfo.GetTalentInfo({
                specializationIndex = spec,
                talentIndex         = i,
                isInspect           = false,
                isPet               = false,
                groupIndex          = group,
            })
            if info and info.column and info.tier then
                local slot = self:GetSlot(info.tier, info.column)
                if slot then
                    slot:Show()

                    -- The "Next rank" tooltip section is lazy-loaded by the
                    -- client the first time that rank's talent tooltip is
                    -- shown, then cached. Pre-warm it by pushing the next
                    -- rank's hyperlink through a hidden tooltip now, so the
                    -- player's first hover already has it. (RequestLoadSpellData
                    -- loads the spell, not the talent's next-rank section.)
                    local effRank = info.previewRank or info.rank or 0
                    if effRank < (info.maxRank or 1) then
                        PreloadTalentRank(info.talentID, effRank)  -- 0-indexed = rank effRank+1
                    end

                    local isPassive = passiveByID[info.talentID]
                    if isPassive == nil then isPassive = true end
                    slot:SetPassive(isPassive)
                    slot:SetTooltip("ANCHOR_RIGHT", function(tooltip)
                        -- previewRank = effective rank (committed + staged).
                        local pr = info.previewRank or info.rank or 0
                        if pr == 0 then
                            -- Nothing invested or staged: SetTalent renders
                            -- the proper "not learned / rank 1 grants…" view.
                            -- The hyperlink at :0 would show rank 1 AS the
                            -- current rank plus a bogus "Next rank" section.
                            tooltip:SetTalent(info.talentID, false, false, group)
                        else
                            -- Invested/staged rank N: hyperlink rank is
                            -- 0-indexed (rank 5 -> ":4"), and gives the
                            -- current-rank + next-rank sections correctly.
                            tooltip:SetHyperlink(string.format("talent:%d:%d",
                                info.talentID, pr - 1))
                        end
                    end)

                    if info.icon then slot:SetIcon(info.icon) end

                    -- Preview-aware rank + prereq. previewRank starts equal
                    -- to rank; AddPreviewTalentPoints staged via left/right
                    -- click bumps the diff. Visuals are identical for
                    -- staged vs real ranks.
                    local rank    = info.previewRank or info.rank or 0
                    local maxRank = info.maxRank or 1
                    local meetsPrereq = info.meetsPreviewPrereq
                    if meetsPrereq == nil then meetsPrereq = info.meetsPrereq end

                    self._pointsSpent = self._pointsSpent + rank

                    -- State mapping (TalentSlot: 0 unavailable, 1 locked,
                    -- 2 known, 3 available):
                    --   3  can spend a point on this RIGHT NOW
                    --   2  fully invested, OR partially invested with no
                    --      spare points to push further
                    --   1  rank 0 but tier+prereq are met — investable as
                    --      soon as a spare point appears
                    --   0  everything else (tier not reached / prereq miss)
                    -- meetsPrereq only checks the prereq-talent rule;
                    -- the per-tier "points-spent-in-tab" gate
                    -- (tier N needs (N-1)*5 points in this tab) we have
                    -- to enforce ourselves.
                    local tierReached = effectivePointsSpent >= (info.tier - 1) * 5
                    local reachable   = meetsPrereq and tierReached
                    local canInvestMore = reachable and rank < maxRank and spare > 0
                    local state

                    if isMaxLevel and spare == 0 and rank == 0 then
                        state = 0
                    elseif canInvestMore then
                        state = 3
                        slot:SetHalo(color[1], color[2], color[3], 1)
                    elseif rank > 0 then
                        state = 2
                        slot:SetHalo(color[1], color[2], color[3], 1)
                    elseif reachable then
                        state = 1
                    else
                        state = 0
                        if not firstUnreached or
                            (info.tier <= firstUnreachedY and info.column <= firstUnreachedX)  then
                            firstUnreached = slot
                            firstUnreachedX = info.column
                            firstUnreachedY = info.tier
                        end
                    end
                    slot:SetState(state)

                    if (rank == 0 or maxRank == 1) and not canInvestMore then
                        slot:SetLabel("")
                    else
                        slot:SetLabel(rank)
                    end

                    if canInvestMore then
                        slot:SetLabelColor(0, 1, 0, 1)
                    else
                        slot:SetLabelColor(1, 0.82, 0, 1)
                    end

                    -- Left  click: stage +1 via AddPreviewTalentPoints
                    -- Right click: stage -1
                    -- The CVar previewTalentsOption is forced on by the
                    -- Spells module init. PREVIEW_TALENT_POINTS_CHANGED
                    -- triggers our auto-refresh.
                    local talentIdx, talentSpec = i, spec
                    if isActiveGroup then
                        slot.OnClick = function(_, button)
                            if button == "RightButton" then
                                AddPreviewTalentPoints(talentSpec, talentIdx, -1, false)
                            else
                                AddPreviewTalentPoints(talentSpec, talentIdx,  1, false)
                            end
                        end
                    else
                        -- Previewing the inactive group — display only.
                        slot.OnClick = nil
                    end

                    -- Prereq arrows. With preview on, GetTalentPrereqs
                    -- returns 4-tuples (tier, column, isLearnable,
                    -- isPreviewLearnable). Use preview state for "active".
                    local prereqs = { GetTalentPrereqs(spec, i, false, false, group) }
                    for k = 1, #prereqs, 4 do
                        local pTier, pCol = prereqs[k], prereqs[k+1]
                        local pPreviewLearn = prereqs[k+3]
                        if pPreviewLearn == nil then pPreviewLearn = prereqs[k+2] end
                        if pTier and pCol then
                            self:_AddPrereqArrow(
                                pTier, pCol, info.tier, info.column,
                                pPreviewLearn and true or false)
                        end
                    end
                end
            end
        end

        

        if (isMaxLevel and spare == 0) or (not firstUnreached) then
            self._specLock:Hide()
            self._specLockCount:Hide()
        else
            self._specLock:ClearAllPoints()
            self._specLock:LeftOf(firstUnreached, -20)
            self._specLock:Show()
            self._specLockCount:SetText((firstUnreachedY - 1) * 5 - effectivePointsSpent)
            self._specLockCount:Show()
        end

        self:UpdateLines()

        if self.OnUpdate then
            self.OnUpdate(self._pointsSpent)
        end

    end;

    -- Draw a prereq arrow from (fromRow, fromCol) -> (toRow, toCol).
    -- Direction is derived from the delta; anchoring follows the same
    -- edge-to-edge style as the static neighbor lines. Pooled — repeat
    -- calls reuse the same line instances.
    _AddPrereqArrow = function(self, fromRow, fromCol, toRow, toCol, active)
        local fromSlot = self:GetSlot(fromRow, fromCol)
        local toSlot   = self:GetSlot(toRow,   toCol)
        if not fromSlot or not toSlot then return end

        local dy = toRow - fromRow
        local dx = toCol - fromCol
        if dx == 0 and dy == 0 then return end

        local sx = (dx > 0) and 1 or (dx < 0 and -1 or 0)
        local sy = (dy > 0) and 1 or (dy < 0 and -1 or 0)

        -- Numpad-style direction map (matches SpellGridLine._ANGLES)
        local direction
        if     sy ==  1 and sx == -1 then direction = 1
        elseif sy ==  1 and sx ==  0 then direction = 2
        elseif sy ==  1 and sx ==  1 then direction = 3
        elseif sy ==  0 and sx == -1 then direction = 4
        elseif sy ==  0 and sx ==  1 then direction = 6
        elseif sy == -1 and sx == -1 then direction = 7
        elseif sy == -1 and sx ==  0 then direction = 8
        elseif sy == -1 and sx ==  1 then direction = 9
        end
        if not direction then return end

        self._prereqCount = self._prereqCount + 1
        local arrow = self._prereqArrows[self._prereqCount]
        if not arrow then
            arrow = SpellGridLine(self, direction, 10)
            arrow._line:SetDrawLayer("BACKGROUND", 5)
            arrow._tip:SetDrawLayer("BACKGROUND", 6)
            arrow:SetShowTip(true)
            self._prereqArrows[self._prereqCount] = arrow
        end
        arrow:SetDirection(direction)
        arrow:ClearAllPoints()

        -- Anchor edge-to-edge, mirroring the static neighbor-line offsets.
        if direction == 2 then
            arrow:SetPoint("TOP",    fromSlot, "BOTTOM",   0,  0)
            arrow:SetPoint("BOTTOM", toSlot,   "TOP",      0,  3)
        elseif direction == 8 then
            arrow:SetPoint("BOTTOM", fromSlot, "TOP",      0,  0)
            arrow:SetPoint("TOP",    toSlot,   "BOTTOM",   0,  -3)
        elseif direction == 6 then
            arrow:SetPoint("LEFT",   fromSlot, "RIGHT",    0,  0)
            arrow:SetPoint("RIGHT",  toSlot,   "LEFT",     -2,  0)
        elseif direction == 4 then
            arrow:SetPoint("RIGHT",  fromSlot, "LEFT",     0,  0)
            arrow:SetPoint("LEFT",   toSlot,   "RIGHT",    2,  0)
        elseif direction == 3 then
            arrow:SetPoint("TOPLEFT",     fromSlot, "BOTTOMRIGHT", -8,  8)
            arrow:SetPoint("BOTTOMRIGHT", toSlot,   "TOPLEFT",      6, -6)
        elseif direction == 1 then
            arrow:SetPoint("TOPRIGHT",    fromSlot, "BOTTOMLEFT",   8,  8)
            arrow:SetPoint("BOTTOMLEFT",  toSlot,   "TOPRIGHT",    -6, -6)
        elseif direction == 9 then
            arrow:SetPoint("BOTTOMLEFT",  fromSlot, "TOPRIGHT",    -8, -8)
            arrow:SetPoint("TOPRIGHT",    toSlot,   "BOTTOMLEFT",   6,  6)
        elseif direction == 7 then
            arrow:SetPoint("BOTTOMRIGHT", fromSlot, "TOPLEFT",      8, -8)
            arrow:SetPoint("TOPLEFT",     toSlot,   "BOTTOMRIGHT", -6,  6)
        end

        arrow:SetActive(active and true or false, 1.0)
        arrow:Show()
    end;

    -- Switch which talent group (1 = primary, 2 = secondary) this grid
    -- renders; nil follows the active group. Re-renders immediately when a
    -- spec is already loaded.
    SetGroup = function(self, group)
        self._group = group
        if self._currentSpec then self:UpdateFromSpec(self._currentSpec) end
    end;

}