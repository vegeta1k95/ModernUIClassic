-- Retail-style experience/reputation bar

local ATLAS = MUI_AtlasRegistry.XPBar
local BAR_WIDTH = 504
local HALF_WIDTH = BAR_WIDTH / 2
local FILL_WIDTH = 508
local FILL_HALF = FILL_WIDTH / 2
local FILL_HEIGHT = 9
local FRAME_H = 10
local FRAME_HEIGHT = 15.5

local function CreateSplitPair(parent, layer, leftRegion, rightRegion, halfWidth, height)
    local left = Texture(parent, nil, layer)
    left:SetAtlas(ATLAS, leftRegion)
    left:SetSize(halfWidth, height)

    local right = Texture(parent, nil, layer)
    right:SetAtlas(ATLAS, rightRegion)
    right:SetSize(halfWidth, height)

    return left, right
end

local REP_FILL_MAP = {
    [1] = "FillRepRed",
    [2] = "FillRepRed",
    [3] = "FillRepOrange",
    [4] = "FillRepYellow",
    [5] = "FillRepGreen",
    [6] = "FillRepGreen",
    [7] = "FillRepGreen",
    [8] = "FillRepGreen",
}

-- Editable wrapper for the XP / reputation bars (plain non-secure frames whose
-- content is all children, so the default drag + scale handlers just work).
class "XPBarEditable" : extends {"Frame", "Editable"} {
    __init = function(self, name, label)
        Frame.__init(self, "Frame", MUI_Root, name)
        Editable.__init(self)
        self:EditModeSetLabel(label)
        self:EditModeSetLabelSize(12)   -- thin bars; default 18 overflows
        self:EditModeSetupSettings(function(content) end)
    end;
}

object "ModuleXPBar" : extends "Module" {
    __init = function(self)
        Module.__init(self, "XPBar")
    end;

    OnEnable = function(self)
        self:HideVanillaBar()
        self:CreateBar()
        self:CreateRepBar()
        self:UpdateXP()
        self:UpdateRep()
        self:RegisterEvents()
    end;

    HideVanillaBar = function(self)
        local hides = {
            "MainMenuExpBar", "MainMenuBarMaxLevelBar", "ExhaustionTick",
            "StatusTrackingBarManager", "ReputationWatchBar",
        }
        for _, name in ipairs(hides) do
            local f = getglobal(name)
            if f then Frame(f):HideFrame() end
        end

        if ExhaustionLevelFillBar then Frame(ExhaustionLevelFillBar):Hide() end
    end;

    CreateBar = function(self)
        self.bar = XPBarEditable("MUI_XPBar", "Experience Bar")
        self.bar:SetSize(BAR_WIDTH, FRAME_H)
        self.bar:AlignParentBottom(5)
        self.bar:SetFrameStrata("MEDIUM")
        self.bar:EditModeSetDefaultPosition(function(b)
            b:ClearAllPoints()
            b:AlignParentBottom(2)
        end)

        self.bgL, self.bgR = CreateSplitPair(self.bar, "BACKGROUND",
            "BackgroundLeft", "BackgroundRight", FILL_HALF, FILL_HEIGHT)
        self.bgL:CenterInParent(-(FILL_HALF / 2)-2, 0)
        self.bgR:CenterInParent((FILL_HALF / 2)-2, 0)

        self.restedL = Texture(self.bar, nil, "BORDER")
        self.restedL:SetSize(0, FILL_HEIGHT)
        self.restedL:AlignLeft(self.bgL)
        self.restedL:AlignTop(self.bgL)

        self.restedR = Texture(self.bar, nil, "BORDER")
        self.restedR:SetSize(0, FILL_HEIGHT)
        self.restedR:AlignLeft(self.bgR)
        self.restedR:AlignTop(self.bgR)

        self.xpL = Texture(self.bar, nil, "ARTWORK")
        self.xpL:SetSize(0, FILL_HEIGHT)
        self.xpL:AlignLeft(self.bgL)
        self.xpL:AlignTop(self.bgL)

        self.xpR = Texture(self.bar, nil, "ARTWORK")
        self.xpR:SetSize(0, FILL_HEIGHT)
        self.xpR:AlignLeft(self.bgR)
        self.xpR:AlignTop(self.bgR)

        self.frameL, self.frameR = CreateSplitPair(self.bar, "OVERLAY",
            "FrameLeft", "FrameRight", HALF_WIDTH, FRAME_HEIGHT)
        self.frameL:CenterInParent(-(HALF_WIDTH / 2)-2.5, -2)
        self.frameL:SetWidth(HALF_WIDTH+5.5)

        self.frameR:CenterInParent((HALF_WIDTH / 2)+2, -2)
        self.frameR:SetWidth(HALF_WIDTH+5.5)

        self.pip = Texture(self.bar, nil, "OVERLAY")
        self.pip:SetAtlas(ATLAS, "Pip")
        self.pip:SetSize(10, 14)
        self.pip:Hide()

        self.text = FontString(self.bar, nil, "OVERLAY")
        self.text:SetFont(MUI.FONT, 9, "OUTLINE")
        self.text:SetTextColor(1, 1, 1, 1)
        self.text:CenterInParent(0, 0)
        self.text:Hide()

        self.bar:EnableMouse(true)
        self.bar:SetScript("OnEnter", function()
            self.text:Show()
        end)
        self.bar:SetScript("OnLeave", function()
            self.text:Hide()
        end)

        self.bar:SetTooltip("ANCHOR_TOP", function(tooltip)
            local currXP = UnitXP("player")
            local maxXP = UnitXPMax("player")
            local remaining = maxXP - currXP
            local exhaustion = GetXPExhaustion() or 0

            tooltip:AddLine("Experience", 1, 1, 1, true, 13)
            tooltip:AddDoubleLine("Current:", currXP .. " / " .. maxXP)
            tooltip:AddDoubleLine("Remaining:", remaining)

            if exhaustion > 0 then
                tooltip:AddDoubleLine("Rested:", exhaustion, 0.2, 0.6, 1, 0.2, 0.6, 1)
            end
        end)

        if UnitLevel("player") == MAX_PLAYER_LEVEL then
            self.bar:Hide()
        end
    end;

    SetSplitFill = function(self, leftTex, rightTex, pct, leftRegion, rightRegion)
        if pct <= 0 then
            leftTex:Hide()
            rightTex:Hide()
            return
        end

        local fillPx = FILL_WIDTH * pct
        local lRegion = ATLAS:GetRegion(leftRegion)
        local rRegion = ATLAS:GetRegion(rightRegion)
        if not lRegion then return end

        if fillPx <= FILL_HALF then
            leftTex:Show()
            rightTex:Hide()
            leftTex:SetSize(fillPx, FILL_HEIGHT)
            local cropR = lRegion.left + (lRegion.right - lRegion.left) * (fillPx / FILL_HALF)
            leftTex:SetTexture(lRegion.file)
            leftTex:SetTexCoord(lRegion.left, cropR, lRegion.top, lRegion.bottom)
        else
            leftTex:Show()
            leftTex:SetSize(FILL_HALF, FILL_HEIGHT)
            leftTex:SetTexture(lRegion.file)
            leftTex:SetTexCoord(lRegion.left, lRegion.right, lRegion.top, lRegion.bottom)

            if rRegion then
                rightTex:Show()
                local rightFill = fillPx - FILL_HALF
                rightTex:SetSize(rightFill, FILL_HEIGHT)
                local cropR = rRegion.left + (rRegion.right - rRegion.left) * (rightFill / FILL_HALF)
                rightTex:SetTexture(rRegion.file)
                rightTex:SetTexCoord(rRegion.left, cropR, rRegion.top, rRegion.bottom)
            end
        end
    end;

    UpdateXP = function(self)
        local maxLevel = UnitLevel("player") == MAX_PLAYER_LEVEL
        -- No XP bar at max level, so keep it out of edit mode too. Re-evaluated
        -- here (runs at login and on PLAYER_LEVEL_UP) so dinging max disables it.
        self.bar:EditModeEnabled(not maxLevel)
        if maxLevel then
            self.bar:Hide()
            return
        end

        local currXP = UnitXP("player")
        local maxXP = UnitXPMax("player")
        if maxXP == 0 then maxXP = 1 end

        local pct = currXP / maxXP
        local exhaustion = GetXPExhaustion() or 0

        if exhaustion > 0 then
            self:SetSplitFill(self.xpL, self.xpR, pct, "FillRestedLeft", "FillRestedRight")

            local restedEndPct = math.min(1, (currXP + exhaustion) / maxXP)
            self:SetSplitFill(self.restedL, self.restedR, restedEndPct,
                "FillRestedLeft", "FillRestedRight")
            self.restedL:SetVertexColor(0.3, 0.3, 0.5)
            self.restedR:SetVertexColor(0.3, 0.3, 0.5)

            if restedEndPct == 1.0 then
                self.pip:Hide()
            else
                local pipX = FILL_WIDTH * restedEndPct - 5
                self.pip:ClearAllPoints()
                self.pip:AlignLeft(self.bgL, pipX)
                self.pip:AlignTop(self.bar, -1)
                self.pip:Show()
            end

        else
            self:SetSplitFill(self.xpL, self.xpR, pct, "FillXPLeft", "FillXPRight")
            self.restedL:Hide()
            self.restedR:Hide()
            self.pip:Hide()
        end

        self.text:SetText("XP: " .. currXP .. "/" .. maxXP)
    end;

    CreateRepBar = function(self)
        self.repBar = XPBarEditable("MUI_RepBar", "Reputation Bar")
        self.repBar:SetSize(BAR_WIDTH, FRAME_H)
        -- Default sits at the bottom at max level (no XP bar), else above the XP
        -- bar. "Restore default position" re-runs the same state-dependent rule.
        local function repDefault(b)
            b:ClearAllPoints()
            if UnitLevel("player") == MAX_PLAYER_LEVEL then
                b:AlignParentBottom(4)
            else
                b:Above(self.bar, 5)
            end
        end
        repDefault(self.repBar)
        self.repBar:EditModeSetDefaultPosition(repDefault)

        self.repBar:SetFrameStrata("MEDIUM")
        self.repBar:Hide()

        self.repBgL, self.repBgR = CreateSplitPair(self.repBar, "BACKGROUND",
            "BackgroundLeft", "BackgroundRight", FILL_HALF, FILL_HEIGHT)
        self.repBgL:CenterInParent(-(FILL_HALF / 2) - 2, 0)
        self.repBgR:CenterInParent((FILL_HALF / 2) - 2, 0)

        self.repFillL = Texture(self.repBar, nil, "ARTWORK")
        self.repFillL:SetSize(0, FILL_HEIGHT)
        self.repFillL:AlignLeft(self.repBgL)
        self.repFillL:AlignTop(self.repBgL)

        self.repFillR = Texture(self.repBar, nil, "ARTWORK")
        self.repFillR:SetSize(0, FILL_HEIGHT)
        self.repFillR:AlignLeft(self.repBgR)
        self.repFillR:AlignTop(self.repBgR)

        self.repFrameL, self.repFrameR = CreateSplitPair(self.repBar, "OVERLAY",
            "FrameLeft", "FrameRight", HALF_WIDTH, FRAME_HEIGHT)
        self.repFrameL:CenterInParent(-(HALF_WIDTH / 2) - 2.5, -2)
        self.repFrameL:SetWidth(HALF_WIDTH + 5.5)
        self.repFrameR:CenterInParent((HALF_WIDTH / 2) + 2, -2)
        self.repFrameR:SetWidth(HALF_WIDTH + 5.5)

        self.repText = FontString(self.repBar, nil, "OVERLAY")
        self.repText:SetFont(MUI.FONT, 9, "OUTLINE")
        self.repText:SetTextColor(1, 1, 1, 1)
        self.repText:CenterInParent(0, 0.5)
        self.repText:Hide()

        self.repBar:EnableMouse(true)
        self.repBar:SetScript("OnEnter", function()
            self.repText:Show()
        end)
        self.repBar:SetScript("OnLeave", function()
            self.repText:Hide()
        end)

        self.repBar:SetTooltip("ANCHOR_TOP", function(tooltip)
            local name, standing, minRep, maxRep, value = GetWatchedFactionInfo()
            if not name then return end

            local standingText = getglobal("FACTION_STANDING_LABEL" .. standing) or ""
            local range = maxRep - minRep
            local current = value - minRep
            tooltip:AddLine(name, 1, 1, 1, false, 13)
            tooltip:AddDoubleLine("Standing:", standingText)
            tooltip:AddDoubleLine("Reputation:", current .. " / " .. range)
        end)
    end;

    UpdateRep = function(self)
        local name, standing, minRep, maxRep, value = GetWatchedFactionInfo()
        if not name then
            self.repBar:Hide()
            return
        end

        self.repBar:Show()

        local range = maxRep - minRep
        if range <= 0 then range = 1 end
        local pct = (value - minRep) / range

        local prefix = REP_FILL_MAP[standing] or "FillRepGreen"

        if standing == 4 then
            self.repFillL:Show()
            self.repFillR:Hide()
            local region = ATLAS:GetRegion("FillRepYellow")
            if region then
                local fillPx = FILL_WIDTH * pct
                self.repFillL:SetSize(fillPx, FILL_HEIGHT)
                local cropR = region.left + (region.right - region.left) * pct
                self.repFillL:SetTexture(region.file)
                self.repFillL:SetTexCoord(region.left, cropR, region.top, region.bottom)
            end
        else
            self:SetSplitFill(self.repFillL, self.repFillR, pct,
                prefix .. "Left", prefix .. "Right")
        end

        self.repText:SetText(name .. " " .. (value - minRep) .. " / " .. range)
    end;

    ShowRepTooltip = function(self)
        
    end;

    RegisterEvents = function(self)
        local eventFrame = Frame("Frame", nil, "MUI_XPBarEvents")
        local function refresh()
            self:UpdateXP()
            self:UpdateRep()
        end
        eventFrame:RegisterEventHandler("PLAYER_XP_UPDATE",      refresh)
        eventFrame:RegisterEventHandler("PLAYER_LEVEL_UP",       refresh)
        eventFrame:RegisterEventHandler("UPDATE_EXHAUSTION",     refresh)
        eventFrame:RegisterEventHandler("PLAYER_ENTERING_WORLD", refresh)
        eventFrame:RegisterEventHandler("UPDATE_FACTION",        refresh)
    end;
}
