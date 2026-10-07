-- MUI_CharacterHonor: the Honor tab — Era's honor sheet (rank and progress,
-- kills and honor by period) set out in the stat sheet's plates and rows.

local SHEET = "Interface\\PaperDollInfoFrame\\PaperDollInfoPart1"

local COLUMN_W = 190
local PLATE_H  = 40
local ROW_H    = 15

-- title, column (-1 left, 1 right, 0 centre), top, rows
local BLOCKS = {
    { key = "today",     title = "Today",     column = -1, top = 96,  rows = { "Honorable Kills", "Dishonorable Kills" } },
    { key = "yesterday", title = "Yesterday", column = 1,  top = 96,  rows = { "Honorable Kills", "Honor" } },
    { key = "thisWeek",  title = "This Week", column = -1, top = 172, rows = { "Honorable Kills", "Honor" } },
    { key = "lastWeek",  title = "Last Week", column = 1,  top = 172, rows = { "Honorable Kills", "Honor", "Standing" } },
    { key = "lifetime",  title = "Lifetime",  column = 0,  top = 262, rows = { "Honorable Kills", "Dishonorable Kills", "Highest Rank" } },
}

class "CharacterHonor" : extends "CharacterPane" {
    __init = function(self, window)
        CharacterPane.__init(self, window)

        self:_BuildRank()
        self._rows = {}
        for _, block in ipairs(BLOCKS) do
            self:_BuildBlock(block)
        end

        self:HookScript("OnShow", function() self:Refresh() end)
        local function refresh() if self:IsVisible() then self:Refresh() end end
        self:RegisterEventHandler("PLAYER_PVP_KILLS_CHANGED", refresh)
        self:RegisterEventHandler("PLAYER_PVP_RANK_CHANGED", refresh)
    end;

    GetTitle = function(self)
        return HONOR, 1, 0.82, 0
    end;

    -- The rank: its badge, its name and number, and the progress to the next.
    _BuildRank = function(self)
        self._badge = Texture(self, nil, "ARTWORK")
        self._badge:SetSize(36, 36)
        self._badge:AlignParentTop(10)

        self._rank = FontString(self, nil, "ARTWORK")
        self._rank:SetFontSize(13)
        self._rank:SetTextColor(1, 0.82, 0, 1)
        self._rank:AlignParentTop(50)

        self._progress = StatusBar(self)
        self._progress:SetSize(220, 12)
        self._progress:AlignParentTop(72)
        self._progress:SetMinMaxValues(0, 1)
        local edge = Frame("Frame", self._progress, nil, "ThinGoldEdgeTemplate")
        edge:FillParentPadding(-3, -3, -3, -3)
    end;

    -- A period: its title plate over its rows.
    _BuildBlock = function(self, block)
        local x = block.column * (COLUMN_W / 2 + 3)
        local plate = Texture(self, nil, "BACKGROUND")
        plate:SetDrawLayer("BACKGROUND", 1)
        plate:SetTextureRegion(SHEET, 1024, 1024, 1, 715, 196, 40)
        plate:SetSize(COLUMN_W, PLATE_H)
        plate:AlignParentTop(block.top, x)
        local title = FontString(self, nil, "ARTWORK")
        title:SetFontSize(12)
        title:SetTextColor(1, 1, 1, 1)
        title:CenterAt(plate, 0, 1)
        title:SetText(block.title)

        local rows = {}
        for i, label in ipairs(block.rows) do
            local row = CharacterStatRow(self)
            row:AlignParentTop(block.top + PLATE_H + 2 + (i - 1) * ROW_H, x)
            row:SetStriped(i % 2 == 0)
            row.label = label
            rows[i] = row
        end
        self._rows[block.key] = rows
    end;

    _Set = function(self, key, ...)
        for i, row in ipairs(self._rows[key]) do
            local value = select(i, ...) or 0
            row:Set(row.label, value, row.label .. " " .. value)
        end
    end;

    Refresh = function(self)
        local rankName, rankNumber = GetPVPRankInfo(UnitPVPRank("player"))
        if rankName then
            self._rank:SetText(rankName .. " (" .. RANK .. " " .. rankNumber .. ")")
        else
            self._rank:SetText(NONE)
        end
        self._badge:SetVisible(rankNumber ~= nil and rankNumber > 0)
        if rankNumber and rankNumber > 0 then
            self._badge:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", rankNumber))
        end
        if UnitFactionGroup("player") == "Alliance" then
            self._progress:SetStatusBarColor(0.05, 0.15, 0.36)
        else
            self._progress:SetStatusBarColor(0.63, 0.09, 0.09)
        end
        self._progress:SetValue(GetPVPRankProgress())

        local hk, dk, honor, standing, highest
        hk, dk = GetPVPSessionStats()
        self:_Set("today", hk, dk)
        hk, dk, honor = GetPVPYesterdayStats()
        self:_Set("yesterday", hk, honor)
        hk, honor = GetPVPThisWeekStats()
        self:_Set("thisWeek", hk, honor)
        hk, dk, honor, standing = GetPVPLastWeekStats()
        self:_Set("lastWeek", hk, honor, standing)
        hk, dk, highest = GetPVPLifetimeStats()
        self:_Set("lifetime", hk, dk, GetPVPRankInfo(highest) or NONE)
    end;
}
