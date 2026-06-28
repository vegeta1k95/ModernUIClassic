
object "IconOverrides" {

    __init = function(self)
        self._spellOverrides = {}

        self:_HookSpellOverrides()
    end;

    SetSpellOverride = function(self, spellID, iconPath)
        self._spellOverrides[spellID] = iconPath
    end;

    -- Returns the override icon for a spell, or nil if no override.
    -- Consumers that want the override should query this directly; we
    -- do NOT replace GetSpellInfo / GetSpellTexture as globals, because
    -- replacing a Blizzard secure function taints every secure caller
    -- (action-button activation, spellbook cast click, …) and triggers
    -- "ADDON_ACTION_BLOCKED" even outside combat.
    GetOverride = function(self, spellID)
        return spellID and self._spellOverrides[spellID] or nil
    end;

    _HookSpellOverrides = function(self)
        local function ApplyActionButtonOverride(btn)
            if not btn or not btn.icon or not btn.action then return end
            local actionType, id = GetActionInfo(btn.action)
            if actionType ~= "spell" or not id then return end
            local override = self._spellOverrides[id]
            if override then
                btn.icon:SetTexture(override)
            end
        end

        hooksecurefunc("ActionButton_Update", ApplyActionButtonOverride)

        -- ActionButton.lua has two events (UPDATE_SHAPESHIFT_FORM,
        -- UPDATE_SUMMONPETS_ACTION) that set self.icon:SetTexture directly
        -- without going through ActionButton_Update. Re-apply on those.
        hooksecurefunc("ActionButton_OnEvent", function(btn, event)
            if event == "UPDATE_SHAPESHIFT_FORM"
            or event == "UPDATE_SUMMONPETS_ACTION" then
                ApplyActionButtonOverride(btn)
            end
        end)
    end;

}