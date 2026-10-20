-- MUI_InspectHonor: the inspect window's Honor tab — the inspected
-- player's honor in the character window's honor sheet
-- (MUI_CharacterHonor), 400 wide as it is there. Retail's PvP tab is rated
-- play and PvP talents, which Era has none of; its line of lifetime kills
-- heads this one.
--
-- Era asks the server for the player's honor when its own honor frame
-- (parked off screen) shows with the tab.

class "InspectHonor" : extends "CharacterHonor" {

    -- Retail's frame width for the tab, and where its inset ends above the
    -- frame's bottom.
    frameWidth  = 400,
    insetBottom = 4,

    EDGE_NAME = "MUI_InspectHonorProgressEdge",

    __init = function(self, window)
        CharacterHonor.__init(self, window)

        self._kills = FontString(self, nil, "OVERLAY")
        self._kills:SetFontSize(12)
        self._kills:SetTextColor(1, 1, 1, 1)
        self._kills:AlignTop(window.canvas, 36)

        self:RegisterEventHandler("INSPECT_HONOR_UPDATE", function()
            if self:IsVisible() then self:Refresh() end
        end)
    end;

    -- The character window's level line is the player's own.
    BuildLevelText = function(self) end;
    UpdateLevelText = function(self) end;

    Refresh = function(self)
        local unit = InspectFrame.unit
        if not unit or not HasInspectHonorData() then return end
        local sessionHK, sessionDK, yesterdayHK, yesterdayHonor, thisWeekHK, thisWeekHonor,
              lastWeekHK, lastWeekHonor, lastWeekStanding, lifetimeHK, lifetimeDK, lifetimeRank = GetInspectHonorData()

        self._kills:SetText(INSPECT_HONORABLE_KILLS:format(lifetimeHK))
        self:ShowRank(UnitPVPRank(unit), GetInspectPVPRankProgress(), UnitFactionGroup(unit))
        self:SetBlock("today", sessionHK, sessionDK)
        self:SetBlock("yesterday", yesterdayHK, yesterdayHonor)
        self:SetBlock("thisWeek", thisWeekHK, thisWeekHonor)
        self:SetBlock("lastWeek", lastWeekHK, lastWeekHonor, lastWeekStanding)
        self:SetBlock("lifetime", lifetimeHK, lifetimeDK, GetPVPRankInfo(lifetimeRank) or NONE)
    end;
}
