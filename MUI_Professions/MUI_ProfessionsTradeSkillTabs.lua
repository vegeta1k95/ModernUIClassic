-- Profession tab row below the main frame.
--
-- Each tab represents a profession the player has trained (excluding
-- gathering-only). Clicking a non-active tab casts that profession's rank
-- spell which fires TRADE_SKILL_SHOW / CRAFT_SHOW and rotates the overlay.
--
-- Tab order: primary 1, primary 2, then secondaries (cooking, first aid).
-- Fishing is gathering-only → skipped. Mining/Herbalism/Skinning have
-- isGathering=true → no tab even though Mining has a Smelting window.

class "ProfessionsTabs" : extends "TabGroup" {

    __init = function(self, parent)
        TabGroup.__init(self, parent, "MUI_ProfessionsTradeSkillTabs", TabFrame, "bottom", -7)
        self:SetSize(1, 1)
        self.OnTabSelected = function(_, idx)
            -- Skip casts during Refresh (AddTab auto-selects-first, and we
            -- call SelectTab(activeIdx) explicitly) — only user clicks cast.
            if self._refreshing then return end
            if InCombatLockdown() then return end
            local tab = self:GetTab(idx)
            if not tab or not tab._spellID then return end
            local name = GetSpellInfo(tab._spellID)
            if name then CastSpellByName(name) end
            if self.OnSelect then self:OnSelect(tab) end
        end
    end;

    -- Rebuild the tab row from currently-known non-gathering professions
    -- and select the one matching the open native. _refreshing flag
    -- suppresses OnTabSelected casts triggered by AddTab's auto-select-first
    -- and our explicit SelectTab(activeIdx) below.
    Refresh = function(self, activeState)
        -- Build the ordered list with nil-checked inserts, NOT a table
        -- constructor: a missing primary leaves a nil hole and ipairs stops
        -- at the first hole (a Cooking + First Aid only char got zero tabs).
        local p1       = MUI_ModuleProfessions:GetFirstPrimaryProfession()
        local p2       = MUI_ModuleProfessions:GetSecondPrimaryProfession()
        local cooking  = MUI_ModuleProfessions:GetCooking()
        local firstAid = MUI_ModuleProfessions:GetFirstAid()
        local poisons  = MUI_ModuleProfessions:GetPoisons()
        local ordered = {}
        if p1       then table.insert(ordered, p1)       end
        if p2       then table.insert(ordered, p2)       end
        if cooking  then table.insert(ordered, cooking)  end
        if firstAid then table.insert(ordered, firstAid) end
        if poisons  then table.insert(ordered, poisons)  end

        self._refreshing = true
        self:SetSilent(true)
        self:ClearTabs()
        local activeIdx, idx = nil, 0
        for _, state in ipairs(ordered) do
            if not state.def.isGathering and state.knownSpells.rank then
                idx = idx + 1
                local tab = self:AddTab("MUI_ProfessionTab" .. state.name, state.name or state.def.key, nil, 98, 200, 4)
                tab._spellID = state.knownSpells.rank
                if state == activeState then activeIdx = idx end
            end
        end
        if activeIdx then self:SelectTab(activeIdx) end
        self:SetSilent(false)
        self._refreshing = false
    end;
}
