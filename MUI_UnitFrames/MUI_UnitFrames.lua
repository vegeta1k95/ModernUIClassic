-- MUI_UnitFrames: facade for the unit-frame layer. Wires the per-unit
-- skin classes (player/target/pet/tot), the target-aura layout helper,
-- and the combo bar. Exposes shared formatting + factory helpers used
-- by the components (FormatValue, GetPowerColor, CreateBarText), and
-- owns the single event-dispatch table that fans out to the right
-- component on each Blizzard unit event.
--
-- Construction order (matters):
--   1. player          — bars + overlays for PlayerFrame
--   2. target          — bars + auraContainer + classification border
--   3. targetAuras     — buff/debuff layout into target.auraContainer
--   4. targetCastBar   — anchored Below target.auraContainer
--   5. pet             — anchored Below player.frame
--   6. tot             — anchored to target.frame
--   7. combo           — anchored Below player.mana

local POWER_COLORS = {
    [0] = { 0.04, 0.5, 1 },  -- Mana
    [1] = { 1, 0, 0 },       -- Rage
    [2] = { 1, 1, 0 },       -- Focus
    [3] = { 1, 1, 0 },       -- Energy
}


object "UnitFrames" : extends "Module" {
    __init = function(self)
        Module.__init(self, "UnitFrames")
    end;

    OnEnable = function(self)
        self.player      = UnitFramePlayer(self)
        self.target      = UnitFrameTarget(self)
        self.targetAuras = UnitFrameTargetAuras(self.target)
        self:_SetupTargetCastBar()
        self.pet         = UnitFramePet(self, self.player.frame)
        self.tot         = UnitFrameTargetOfTarget(self, self.target.frame)
        self.combo       = UnitFrameComboBar(self.player.frame, self.player.mana)

        self:_RegisterEvents()
        self:ApplyStatusTextMode()
    end;

    -- ---- shared helpers ----------------------------------------------

    GetPowerColor = function(self, unit)
        local pt = UnitPowerType(unit)
        local c  = POWER_COLORS[pt] or POWER_COLORS[0]
        return c[1], c[2], c[3]
    end;

    -- Build a value-text overlay sitting on top of `bar`. Hides itself
    -- when statusTextDisplay = NONE except on hover (mouseover reveals).
    CreateBarText = function(self, parentFrame, bar, fontSize, widthRef)
        local ref = widthRef or bar
        local textFrame = Frame("Frame", parentFrame, nil)
        textFrame:AlignLeft(ref)
        textFrame:AlignTop(bar)
        textFrame:AlignBottom(bar)
        textFrame:SetWidth(ref:GetWidth())
        textFrame:SetFrameStrata(parentFrame:GetFrameStrata())
        textFrame:SetFrameLevel(parentFrame:GetFrameLevel() + 2)
        textFrame:EnableMouse(true)

        local valueText = FontString(textFrame, nil, "OVERLAY")
        valueText:SetFont(MUI.FONT, fontSize, "OUTLINE")
        valueText:CenterInParent()
        valueText:SetTextColor(1, 1, 1)

        textFrame:SetScript("OnEnter", function()
            if GetCVar("statusTextDisplay") == "NONE" then
                valueText:Show()
            end
        end)
        textFrame:SetScript("OnLeave", function()
            if GetCVar("statusTextDisplay") == "NONE" then
                valueText:Hide()
            end
        end)

        return { frame = textFrame, value = valueText }
    end;

    FormatValue = function(self, current, max, unit, isHealth)
        local mode = GetCVar("statusTextDisplay") or "NUMERIC"
        if max <= 0 then return "" end
        local pct = math.floor(current / max * 100)

        -- Classic Era restricts only HEALTH for other players (party/raid excepted) to 0–100.
        -- Mana of other players and NPC health both return real values.
        local restricted = isHealth and unit
            and UnitIsPlayer(unit)
            and not UnitIsUnit(unit, "player")
            and not UnitInParty(unit)
            and not UnitInRaid(unit)

        -- Restricted (other-player HP clamped 0-100): force percent since real numbers aren't available.
        if restricted then
            return pct .. "%"
        elseif mode == "PERCENT" then
            return pct .. "%"
        elseif mode == "BOTH" then
            return current .. " / " .. max .. "  " .. pct .. "%"
        end
        -- NONE / NUMERIC / anything else → numeric (NONE's visibility is controlled by Show/Hide).
        return current .. " / " .. max
    end;

    ApplyStatusTextMode = function(self)
        local show = (GetCVar("statusTextDisplay") ~= "NONE")
        local texts = {
            self.player.healthText, self.player.manaText,
            self.target.healthText, self.target.manaText,
        }
        for _, t in ipairs(texts) do
            if t and t.value then
                if show then t.value:Show() else t.value:Hide() end
            end
        end
        self.player:UpdateTexts()
        if UnitExists("target") then
            self.target:UpdateBars()
        end
    end;

    -- ---- target cast bar (small enough to live on the facade) --------

    _SetupTargetCastBar = function(self)
        if TargetFrameSpellBar then
            Frame(TargetFrameSpellBar):Kill()
        end

        self.targetCastBar = CastBar(nil, "MUI_CastBar_Target", "target", 133, 9)
        self.targetCastBar:SetIconEnabled(true)
        self.targetCastBar:SetFrameStrata("HIGH")
        self.targetCastBar.timeText:Hide()
        self.targetCastBar:ClearAllPoints()
        if self.target and self.target.auraContainer then
            self.targetCastBar:Below(self.target.auraContainer, 9)
            self.targetCastBar:AlignLeft(self.target.health, 19)
        elseif TargetFrame then
            self.targetCastBar:SetPoint("TOP", TargetFrame, "BOTTOM", -40, -10)
        end
    end;

    -- ---- events ------------------------------------------------------

    _RegisterEvents = function(self)
        self.eventFrame = Frame("Frame", nil, "MUI_UnitFrameEvents")

        local function unitBars(_, evt, unit)
            if unit == "player" then
                self.player:UpdateBars()
                if evt == "UNIT_POWER_UPDATE" then self.combo:Update() end
            elseif unit == "target" then
                self.target:UpdateBars()
            elseif unit == "pet" then
                self.pet:UpdateBars()
            elseif unit == "targettarget" then
                self.tot:UpdateBars()
            end
        end

        self.eventFrame:RegisterEventHandler("UNIT_HEALTH",     unitBars)
        self.eventFrame:RegisterEventHandler("UNIT_MAXHEALTH",  unitBars)
        self.eventFrame:RegisterEventHandler("UNIT_POWER_UPDATE", unitBars)
        self.eventFrame:RegisterEventHandler("UNIT_MAXPOWER",   unitBars)

        self.eventFrame:RegisterEventHandler("PLAYER_ENTERING_WORLD", function()
            self.player:UpdateBars()
            self.combo:Update()
            if UnitExists("target") then self.target:OnTargetChanged() end
            if UnitExists("pet")    then self.pet:UpdateBars()         end
        end)

        self.eventFrame:RegisterEventHandler("PLAYER_TARGET_CHANGED", function()
            self.target:OnTargetChanged()
            self.combo:Update()
        end)

        self.eventFrame:RegisterEventHandler("UNIT_PET", function()
            if UnitExists("pet") then self.pet:UpdateBars() end
        end)

        self.eventFrame:RegisterEventHandler("UNIT_DISPLAYPOWER", function(_, _, unit)
            if unit == "player" then
                self.player:UpdatePowerType()
                self.combo:Update()
            end
        end)

        self.eventFrame:RegisterEventHandler("UPDATE_SHAPESHIFT_FORM", function()
            self.combo:Update()
        end)

        -- Combat ended — drop any cached combo points.
        self.eventFrame:RegisterEventHandler("PLAYER_REGEN_ENABLED", function()
            self.combo:ClearCache()
        end)

        -- Tracked combo target died → drop the cache.
        self.eventFrame:RegisterEventHandler("COMBAT_LOG_EVENT_UNFILTERED", function()
            if not self.combo.cachedTargetGUID then return end
            local _, sub, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
            if destGUID == self.combo.cachedTargetGUID
                    and (sub == "UNIT_DIED" or sub == "PARTY_KILL") then
                self.combo:ClearCache()
            end
        end)

        self.eventFrame:RegisterEventHandler("UNIT_POWER_FREQUENT", function(_, _, unit)
            if unit == "player" then self.combo:Update() end
        end)

        self.eventFrame:RegisterEventHandler("CVAR_UPDATE", function(_, _, cvar)
            if cvar == "STATUS_TEXT_DISPLAY" or cvar == "statusTextDisplay" then
                self:ApplyStatusTextMode()
            end
        end)
    end;
}
