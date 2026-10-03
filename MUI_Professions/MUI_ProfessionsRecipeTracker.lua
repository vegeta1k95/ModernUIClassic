-- RecipeTracker: the recipes the player ticked "Track Recipe" on, kept per
-- character in MUI_DB.data.trackedRecipes (retail's C_TradeSkillUI recipe
-- tracking, which Era doesn't have). Era only reports a recipe's reagents
-- while its profession window is open, so each entry is a snapshot taken
-- when it was tracked — { spellID, name, reagents = { { itemID, count,
-- name } } } — and the quest tracker counts what the bags hold itself.

object "RecipeTracker" {
    __init = function(self)
        self._listeners = {}
    end;

    GetAll = function(self)
        return MUI_DB.data.trackedRecipes
    end;

    IsTracked = function(self, spellID)
        for _, recipe in ipairs(MUI_DB.data.trackedRecipes) do
            if recipe.spellID == spellID then return true end
        end
        return false
    end;

    -- `snapshot` is the entry to store when tracking.
    SetTracked = function(self, spellID, tracked, snapshot)
        local list = MUI_DB.data.trackedRecipes
        for i, recipe in ipairs(list) do
            if recipe.spellID == spellID then
                if tracked then return end
                table.remove(list, i)
                self:_Notify(spellID, false)
                return
            end
        end
        if tracked then
            table.insert(list, snapshot)
            self:_Notify(spellID, true)
        end
    end;

    RegisterCallback = function(self, fn)
        table.insert(self._listeners, fn)
    end;

    _Notify = function(self, spellID, tracked)
        for _, fn in ipairs(self._listeners) do fn(spellID, tracked) end
    end;
}
