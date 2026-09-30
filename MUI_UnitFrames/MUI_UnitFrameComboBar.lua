-- UnitFrameComboBar: combo-point bar for rogues + cat-form druids.
--
-- Druid gating: the bar is class-bound at construction (only DRUID /
-- ROGUE get one), and additionally hidden for druids whenever they're
-- not in cat form (Power type 3 = Energy = cat).
--
-- Count = points on the current target, as Era's ComboFrame reads them:
-- 0 with no target, so deselecting resets the bar (vanilla behaviour). A
-- corpse keeps its points in the API; the bar shows 0 for a dead target.

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
        -- Apply the form gate now: a fresh frame is shown, and the first
        -- Update otherwise waits for a power / form / target event.
        self:Update()
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

        self.bar:SetCount(UnitIsDead("target") and 0 or GetComboPoints("player", "target"))
    end;
}
