-- NativeAdapter: collapses the TradeSkillFrame / CraftFrame API split behind
-- one uniform interface. Vanilla Era has two parallel native systems —
-- "tradeskill" (Alchemy, BS, Tailoring, Cooking, First Aid, Leatherworking,
-- Engineering, Mining/Smelting) and "craft" (Enchanting + a few class-only
-- skills). The two expose almost-identical functionality through differently-
-- named globals (Get{TradeSkill,Craft}Info, Get{TradeSkill,Craft}NumReagents,
-- …). Without this layer, every code path in the overlay branches:
--
--     if self._activeNative == TradeSkillFrame then
--         name = GetTradeSkillInfo(idx)
--     elseif self._activeNative == CraftFrame then
--         name = GetCraftInfo(idx)
--     end
--
-- With one of these adapters installed as `self.adapter`, the same call is:
--
--     name = self.adapter:GetRecipeInfo(idx)
--
-- Both adapters expose the same surface; only the wiring differs.

-- One module-level scratch table that holds whichever adapter was last picked
-- by `MUI_ProfessionsNativeAdapter:For(frame)`. Exposed via the singleton so
-- callers don't have to know which class implements it.
local _trade, _craft

class "TradeSkillAdapter" {

    nativeFrame = nil,           -- set after first For() call
    setSelection = nil,          -- ditto
    CanQueue     = true,         -- DoTradeSkill accepts a count argument

    GetSelectionIndex = function(self)
        return (GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex()) or 0
    end;

    GetNumRecipes = function(self)
        return (GetNumTradeSkills and GetNumTradeSkills()) or 0
    end;

    -- (name, skillType, numAvailable, isExpanded, altVerb, numSkillUps, indent)
    GetRecipeInfo = function(self, idx)
        return GetTradeSkillInfo(idx)
    end;

    GetRecipeIcon = function(self, idx)
        return GetTradeSkillIcon and GetTradeSkillIcon(idx)
    end;

    GetRecipeDescription = function(self, idx)
        return (GetTradeSkillDescription and GetTradeSkillDescription(idx)) or ""
    end;

    -- Produced item LINK for the recipe (used to derive icon/quality/name for
    -- the recipe-detail pane). Crafts don't expose an item link — only Trade.
    GetRecipeItemLink = function(self, idx)
        return GetTradeSkillItemLink and GetTradeSkillItemLink(idx)
    end;

    -- (minMade, maxMade) or nil — crafts don't expose this.
    GetNumMade = function(self, idx)
        if not GetTradeSkillNumMade then return end
        return GetTradeSkillNumMade(idx)
    end;

    GetNumReagents = function(self, idx)
        return (GetTradeSkillNumReagents and GetTradeSkillNumReagents(idx)) or 0
    end;

    -- (name, texture, reagentCount, playerCount)
    GetReagentInfo = function(self, idx, i)
        return GetTradeSkillReagentInfo(idx, i)
    end;

    GetReagentItemLink = function(self, idx, i)
        return GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(idx, i)
    end;

    -- Tool / spell-focus requirement strings, formatted by BuildColoredListString.
    GetTools = function(self, idx)
        return GetTradeSkillTools(idx)
    end;

    -- Highlight the native's selected row. Side effects fire the SetSelection
    -- hook in the overlay, which re-routes through _RefreshRecipeFrame.
    SetSelection = function(self, idx)
        if TradeSkillFrame_SetSelection then TradeSkillFrame_SetSelection(idx) end
    end;

    -- (name, rank, maxRank, modifier)
    GetLine = function(self)
        return GetTradeSkillLine and GetTradeSkillLine()
    end;

    -- Expand every header. We always do this once on open so iteration sees
    -- the full recipe list; collapse state is then tracked client-side.
    ExpandAll = function(self)
        if ExpandTradeSkillSubClass then ExpandTradeSkillSubClass(0) end
    end;

    -- DoTradeSkill takes (index, count); count > 1 queues that many crafts.
    DoCraft = function(self, idx, count)
        if DoTradeSkill then DoTradeSkill(idx, count or 1) end
    end;

    -- Populate the given tooltip wrapper with the recipe's native tooltip
    -- (output-item view for TradeSkill, enchant-effect view for Craft).
    SetRecipeTooltip = function(self, tooltip, idx)
        tooltip:SetTradeSkillItem(idx)
    end;

    -- Tell the server to close the native window. Routed through the
    -- overlay's close-button so Blizzard's UIPanel/event flow fires our
    -- TRADE_SKILL_CLOSE / CRAFT_CLOSE handler and we tear our overlay down.
    Close = function(self)
        if CloseTradeSkill then CloseTradeSkill() end
    end;

    -- Localized profession name shown in the title bar. Same as GetLine()'s
    -- first return; kept as a separate method for clarity at call sites.
    GetProfName = function(self)
        return (self:GetLine())
    end;
}

class "CraftAdapter" {

    nativeFrame = nil,
    CanQueue    = false,         -- DoCraft has no count argument

    GetSelectionIndex = function(self)
        return (GetCraftSelectionIndex and GetCraftSelectionIndex()) or 0
    end;

    GetNumRecipes = function(self)
        return (GetNumCrafts and GetNumCrafts()) or 0
    end;

    -- (name, subSpellName, craftType, numAvailable, isExpanded, trainingPointCost, requiredLevel)
    -- We surface it shaped like TradeSkill's tuple — name first, skillType
    -- ("header" / "optimal" / …) second, numAvailable third — so callers can
    -- destructure identically. Anything beyond `available` is filled with nil.
    GetRecipeInfo = function(self, idx)
        local name, _, craftType, available = GetCraftInfo(idx)
        return name, craftType, available
    end;

    GetRecipeIcon = function(self, idx)
        return GetCraftIcon and GetCraftIcon(idx)
    end;

    GetRecipeDescription = function(self, idx)
        return (GetCraftDescription and GetCraftDescription(idx)) or ""
    end;

    GetRecipeItemLink = function(self, idx)
        return nil    -- Craft API returns a spell link, no item
    end;

    GetNumMade = function(self, idx)
        return nil
    end;

    GetNumReagents = function(self, idx)
        return (GetCraftNumReagents and GetCraftNumReagents(idx)) or 0
    end;

    GetReagentInfo = function(self, idx, i)
        return GetCraftReagentInfo(idx, i)
    end;

    GetReagentItemLink = function(self, idx, i)
        return GetCraftReagentItemLink and GetCraftReagentItemLink(idx, i)
    end;

    GetTools = function(self, idx)
        return GetCraftSpellFocus(idx)
    end;

    SetSelection = function(self, idx)
        if CraftFrame_SetSelection then CraftFrame_SetSelection(idx) end
    end;

    GetLine = function(self)
        if GetCraftDisplaySkillLine then return GetCraftDisplaySkillLine() end
        if GetCraftName             then return GetCraftName() end
    end;

    ExpandAll = function(self)
        if ExpandCraftSkillLine then ExpandCraftSkillLine(0) end
    end;

    -- DoCraft takes (index) only. The `count` argument is accepted-and-
    -- ignored here so callers can pass the same arg regardless of adapter;
    -- they should also gate Create-All UI on CanQueue.
    DoCraft = function(self, idx, _count)
        if DoCraft then DoCraft(idx) end
    end;

    -- Populate the given tooltip wrapper with the recipe's native tooltip.
    -- For crafts that's the enchant-effect view (SetCraftSpell), not an item.
    SetRecipeTooltip = function(self, tooltip, idx)
        tooltip:SetCraftSpell(idx)
    end;

    Close = function(self)
        if CloseCraft then CloseCraft() end
    end;

    -- Craft's GetLine returns name only (no rank tuple), so GetProfName
    -- already matches that shape — defer to it.
    GetProfName = function(self)
        return (self:GetLine())
    end;
}

-- Singleton picker. Returns the adapter matching a native frame, or nil if
-- the frame isn't one of our two known natives. Adapters are instantiated
-- lazily — the FIRST For() call constructs them and stamps the matching
-- native frame onto each so `adapter.nativeFrame` is a stable identity for
-- comparisons (e.g. `if self.adapter.nativeFrame == TradeSkillFrame`).
object "ProfessionsNativeAdapter" {
    For = function(self, nativeFrame)
        if not nativeFrame then return nil end
        if nativeFrame == TradeSkillFrame then
            if not _trade then
                _trade = TradeSkillAdapter()
                _trade.nativeFrame = TradeSkillFrame
            end
            return _trade
        end
        if nativeFrame == CraftFrame then
            if not _craft then
                _craft = CraftAdapter()
                _craft.nativeFrame = CraftFrame
            end
            return _craft
        end
        return nil
    end;
}
