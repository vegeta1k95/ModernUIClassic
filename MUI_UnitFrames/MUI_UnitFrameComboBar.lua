-- UnitFrameComboBar: combo-point bar for rogues + cat-form druids.
--
-- Druid gating: the bar is class-bound at construction (only DRUID /
-- ROGUE get one), and additionally hidden for druids whenever they're
-- not in cat form (Power type 3 = Energy = cat).
--
-- Combo-point cache: vanilla Classic clears combo points the moment
-- target dies / changes, even when the player can immediately cast on a
-- new target with those points still spent. We cache the last positive
-- count keyed by destination GUID so a "/cleartarget" macro that
-- finishes a finishing move still shows the points until the cached
-- target's death event arrives. Cleared on combat-end and on the
-- tracked target dying.

local function _hideVanillaComboFrame()
    -- Hide the native combo point dots that Blizzard renders on the target portrait.
    local combo = Frame(ComboFrame)
    combo:Hide()
    hooksecurefunc("ComboFrame_Update", function() combo:Hide() end)
    for i = 1, 5 do
        local cp = getglobal("ComboPoint" .. i)
        if cp then Frame(cp):Hide() end
    end
end


class "UnitFrameComboBar" {
    __init = function(self, playerFrameWidget, anchorWidget)
        _hideVanillaComboFrame()

        local _, class = UnitClass("player")
        local atlas, flipbook
        if class == "DRUID" then
            atlas    = MUI_AtlasRegistry.ComboDruid
            flipbook = { cols = 8, rows = 3, frames = 20, duration = 1.0,  w = 26, h = 41, sx = 1, sy = 3 }
        elseif class == "ROGUE" then
            atlas    = MUI_AtlasRegistry.ComboRogue
            flipbook = { cols = 6, rows = 3, frames = 17, duration = 0.57, w = 58, h = 58, sx = 1, sy = 0 }
        end
        if not atlas then return end

        self.comboClass = class
        self.bar = ComboBar(playerFrameWidget, "MUI_ComboBar", atlas, 5, flipbook)
        self.bar:ClearAllPoints()
        self.bar:SetScale(0.66)
        self.bar:Below(anchorWidget, 9)
        self.bar:SetCount(0)
    end;

    Update = function(self)
        if not self.bar then return end

        -- Druid only shows combo points in cat form (the only form that uses Energy = 3).
        local shouldShow = true
        if self.comboClass == "DRUID" then
            shouldShow = (UnitPowerType("player") == 3)
        end
        if shouldShow then
            self.bar:Show()
        else
            self.bar:Hide()
        end

        -- Prefer player-bound API (persists across target changes) → fall back to target-bound.
        local COMBO_POWER = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4
        local count = (UnitPower and UnitPower("player", COMBO_POWER)) or 0
        if count == 0 then
            count = (GetComboPoints and GetComboPoints("player", "target")) or 0
        end

        local hasTarget  = UnitExists("target")
        local targetDead = hasTarget and UnitIsDead("target")

        if targetDead then
            count = 0
            self.cached = 0
            self.cachedTargetGUID = nil
        elseif count > 0 then
            -- Anything positive is worth caching (covers macros that cast + /cleartarget).
            self.cached = count
            if hasTarget then self.cachedTargetGUID = UnitGUID("target") end
        elseif not hasTarget then
            -- No target and APIs report 0 — fall back to last known value.
            count = self.cached or 0
        end

        self.bar:SetCount(count)
    end;

    -- Clear the combo-point cache (combat end, tracked target dying, etc.).
    ClearCache = function(self)
        if not self.bar then return end
        self.cached           = 0
        self.cachedTargetGUID = nil
        self:Update()
    end;
}
