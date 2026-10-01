-- MUI_Nameplates: hide native visuals; render BarBG + Bar fill via NineSlice (9-sliced atlas).

local ATLAS1 = MUI_AtlasRegistry.Nameplates1
local ATLAS2 = MUI_AtlasRegistry.Nameplates2

local FILL_MAX_W   = 258.5

local TEXT_LVL_W = 11
local TEXT_HPPERC_W = 20

-- healthText mode values (match dropdown option values)
local HP_NONE, HP_NUMERIC, HP_PERCENT, HP_BOTH = 0, 1, 2, 3

-- nameplateSize CVar (1..5: Small, Medium, Large, Extra Large, Huge) → plate
-- scale. Wider than Blizzard's own factors (0.8 .. 1.6), which left our
-- plates too small: Small is our base size and each step adds a quarter.
local SCALE_STEPS = { 1.0, 1.25, 1.5, 1.75, 2.0 }
local BAR_SCALE = 0.34

object "ModuleNameplates" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Nameplates")
    end;

    OnEnable = function(self)

		SetCVar("nameplateSelectedScale", tostring(1.30))

        self:RegisterSettings()

        self.driver = Frame("Frame", nil, "MUI_NameplateDriver")
        self.driver:RegisterEventHandler("NAME_PLATE_UNIT_ADDED", function(_, _, unit)
            local np = C_NamePlate.GetNamePlateForUnit(unit)
            if not np then return end
            self:SkinPlate(np)
            np._muiUnit = unit
            self:UpdateScale(unit)
            self:UpdateFill(unit)
            self:UpdateColor(unit)
            self:UpdateName(unit)
            self:UpdateLevel(unit)
            self:UpdateHealthText(unit)
            self:UpdateSelection(unit)
            self:UpdateQuestIcon(unit)
            self:UpdateRaidIcon(unit)
        end)
        self.driver:RegisterEventHandler("RAID_TARGET_UPDATE", function() self:UpdateAllRaidIcons() end)
        self.driver:RegisterEventHandler("CVAR_UPDATE", function(_, _, cvar)
            if cvar == "nameplateSize" then self:UpdateAllScales() end
        end)
        -- Quest markers follow the quest log (accept / progress / turn-in)
        -- and the bags (required source items).
        local watcher = MUI_QuestHelper.watcher
        for _, name in ipairs({ "OnQuestAdded", "OnQuestChanged", "OnQuestRemoved" }) do
            watcher:RegisterCallback(name, function() self:UpdateAllQuestIcons() end)
        end
        self.driver:RegisterEventHandler("BAG_UPDATE_DELAYED", function() self:UpdateAllQuestIcons() end)
        self.driver:RegisterEventHandler("NAME_PLATE_UNIT_REMOVED", function(_, _, unit)
            local np = C_NamePlate.GetNamePlateForUnit(unit)
            if np then np._muiUnit = nil end
        end)
        self.driver:RegisterEventHandler("UNIT_HEALTH",    function(_, _, unit)
            self:UpdateFill(unit)
            self:UpdateHealthText(unit)
        end)
        self.driver:RegisterEventHandler("UNIT_MAXHEALTH", function(_, _, unit)
            self:UpdateFill(unit)
            self:UpdateHealthText(unit)
        end)
        -- Our own PvP toggle changes attackability of every other plate (bar and
        -- level colours), so refresh all.
        local function attackabilityChanged(_, _, unit)
            if unit == "player" then
                self:UpdateAllColors()
                self:UpdateAllLevels()
            else
                self:UpdateColor(unit)
                self:UpdateLevel(unit)
            end
        end
        self.driver:RegisterEventHandler("UNIT_FACTION", attackabilityChanged)
        self.driver:RegisterEventHandler("UNIT_FLAGS",   attackabilityChanged)
        self.driver:RegisterEventHandler("UNIT_NAME_UPDATE", function(_, _, unit) self:UpdateName(unit) end)
        -- Level colours are relative to the player's level, so a ding recolours all.
        self.driver:RegisterEventHandler("UNIT_LEVEL", function(_, _, unit)
            if unit == "player" then self:UpdateAllLevels() else self:UpdateLevel(unit) end
        end)
        self.driver:RegisterEventHandler("PLAYER_TARGET_CHANGED", function() self:UpdateAllSelections() end)
        self.driver:RegisterEventHandler("PLAYER_REGEN_DISABLED", function() self:UpdateAllColors() end)
        self.driver:RegisterEventHandler("PLAYER_REGEN_ENABLED",  function() self:UpdateAllColors() end)
    end;

    GetUnitColor = function(self, unit)
        -- Combat override: attackable unit currently in combat → red
		
		local unitIsPlayer = UnitIsPlayer(unit)
		local unitIsFriend = UnitIsFriend("player", unit)
		
        if unitIsPlayer then
			-- Friendly players - class colors
            if unitIsFriend then
                local _, class = UnitClass(unit)
                local c = class and RAID_CLASS_COLORS[class]
                if c then return c.r, c.g, c.b end
                return 1, 1, 1
            end
            -- Opposite faction: only red when mutual combat is possible.
            -- With player PvP off and target flagged (or vice-versa) no fight is possible → yellow.
            if UnitCanAttack("player", unit) and UnitCanAttack(unit, "player") then
                return 1, 0.1, 0.1
            end
            return 1, 1, 0.1
        end
		
		-- NPC tapped by others - grey
		if UnitIsTapDenied(unit) then
			return 0.8, 0.8, 0.8
		end
		
		-- NPC for which we have threat - red
		local threat = UnitThreatSituation("player", unit)
		if threat ~= nil then
			return 1, 0.1, 0.1
		end
		
		-- No threat - color by reaction
        local reaction = UnitReaction(unit, "player") or 4
        if reaction <= 2 then
            return 1, 0.1, 0.1     -- hated / hostile
        elseif reaction == 3 then
            return 1, 0.5, 0.1     -- unfriendly (orange)
        elseif reaction == 4 then
            return 1, 1, 0.1       -- neutral
        else
            return 0.1, 1, 0.1     -- friendly+
        end
    end;

    UpdateColor = function(self, unit)
        if not unit then return end
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        if not np or not np._muiFill then return end
        local r, g, b = self:GetUnitColor(unit)
        np._muiFill:SetVertexColor(r, g, b)
    end;

    UpdateAllColors = function(self)
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            if np._muiUnit then self:UpdateColor(np._muiUnit) end
        end
    end;

    SkinPlate = function(self, namePlate)
        if namePlate._muiSkinned then return end
        namePlate._muiSkinned = true

        local plate = Frame(namePlate)
        self:HideAllNative(plate)

        local bg = NineSlice(plate, "MUI_NamePlateBG_" .. plate:GetName())
        bg:SetSize(274, 46)
        bg:ClearAllPoints()
        bg:CenterAt(plate)
        bg:SetFromAtlas(ATLAS1, "BarBG", 10, 10, 16, 19)
        bg:SetScale(BAR_SCALE)
        bg:SetSubpixelRendering(true)
        namePlate._muiBarBG = bg

        -- Clipper holds the fill at full width; shrinks horizontally with health, clipping
        -- the right portion off so the fill's pieces stay in place ("cutoff" behavior).
		local FILL_INSET_L = 3.5
		local FILL_INSET_T = 5
		local FILL_HEIGHT  = 28
		
        local clipper = Frame("Frame", bg, "MUI_NamePlateClipper_" .. plate:GetName())
        clipper:ClearAllPoints()
        clipper:AlignParentTopLeft(FILL_INSET_T, FILL_INSET_L)
        clipper:SetSize(FILL_MAX_W, FILL_HEIGHT)
        clipper:SetClipsChildren(true)
        namePlate._muiClipper = clipper

        local fill = NineSlice(clipper, "MUI_NamePlateFill_" .. plate:GetName())
        fill:ClearAllPoints()
        fill:AlignParentTopLeft(0, 0)
        fill:SetSize(FILL_MAX_W, FILL_HEIGHT)
        fill:SetFromAtlas(ATLAS1, "Bar", 10, 6, 10, 6)
        fill:SetSubpixelRendering(true)
        namePlate._muiFill = fill

        -- Overlay frame above BG's frame level so text renders on top.
        local overlay = Frame("Frame", plate, "MUI_NamePlateOverlay_" .. plate:GetName())
        overlay:SetAllPoints(fill)
        overlay:SetFrameLevel(bg:GetFrameLevel() + 5)
        namePlate._muiOverlay = overlay
		
		local TEXT_SIZE = 6
		
		local level = FontString(overlay, nil, "OVERLAY")
		level:SetFontSize(TEXT_SIZE, "OUTLINE")
        level:SetTextColor(1, 1, 1)
        level:ClearAllPoints()
		level:SetJustifyH("LEFT")
		level:SetText("")
		level:SetWidth(TEXT_LVL_W)
        level:AlignParentLeft(2)
		namePlate._muiLevel = level
		
		local healthPercent = FontString(overlay, nil, "OVERLAY")
		healthPercent:SetFontSize(TEXT_SIZE, "OUTLINE")
        healthPercent:SetTextColor(1, 1, 1)
        healthPercent:ClearAllPoints()
		healthPercent:SetJustifyH("RIGHT")
		healthPercent:SetText("100%")
        healthPercent:AlignParentRight(2)
		namePlate._muiHealthPercent = healthPercent
		
		local healthValue = FontString(overlay, nil, "OVERLAY")
		healthValue:SetFontSize(TEXT_SIZE, "OUTLINE")
        healthValue:SetTextColor(1, 1, 1)
        healthValue:ClearAllPoints()
		healthValue:SetJustifyH("RIGHT")
		healthValue:SetText("4321")
        healthValue:LeftOf(healthPercent, 0)
		namePlate._muiHealthValue = healthValue

        local name = FontString(overlay, nil, "OVERLAY")
        name:SetFontSize(TEXT_SIZE, "OUTLINE")
        name:SetTextColor(1, 1, 1)
        name:SetJustifyH("LEFT")
        -- Horizontal fills between level/healthValue; vertical locked to overlay so name's
        -- Y doesn't shift when the side labels' text changes their auto-sized height.
        name:ClearAllPoints()
        name:SetPoint("TOP",    overlay, "TOP",    0, 0)
        name:SetPoint("BOTTOM", overlay, "BOTTOM", 0, 0)
        name:SetPoint("LEFT",   level,        "RIGHT", 0, 0)
        name:SetPoint("RIGHT",  healthValue,  "LEFT",  0, 0)
        namePlate._muiName = name
		
		-- Target-selected overlay; shown only when this unit is the player's target.
        local selected = NineSlice(bg, "MUI_NamePlateSelected_" .. plate:GetName())
        selected:ClearAllPoints()
        selected:CenterAt(fill, 0, 0)
        selected:SetSize(FILL_MAX_W + 10, FILL_HEIGHT + 10)
        selected:SetFromAtlas(ATLAS2, "Selected", 12, 12, 12, 12)
        selected:SetSubpixelRendering(true)
        selected:Hide()
        namePlate._muiSelected = selected

        -- Deselected dim overlay; shown on non-target plates, hidden on the target.
        local deselected = NineSlice(bg, "MUI_NamePlateDeselected_" .. plate:GetName())
        deselected:ClearAllPoints()
        deselected:SetAllPoints(fill)
        deselected:SetFromAtlas(ATLAS2, "Deselected", 12, 4, 12, 4)
        deselected:SetSubpixelRendering(true)
        namePlate._muiDeselected = deselected

        -- Quest objective marker, left of the bar (UpdateQuestIcon).
        local questIcon = Texture(overlay, nil, "OVERLAY")
        questIcon:SetSize(10)
        questIcon:LeftOf(overlay, 3)
        questIcon:Hide()
        namePlate._muiQuestIcon = questIcon

        -- Raid target icon, right of the bar (the native one is hidden with
        -- the rest of the plate's art).
        local raidIcon = Texture(overlay, nil, "OVERLAY")
        raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        raidIcon:SetSize(12)
        raidIcon:RightOf(overlay, 3)
        raidIcon:Hide()
        namePlate._muiRaidIcon = raidIcon
    end;

    -- The icons sit in a 4x4 sheet, index 1..8 row by row.
    UpdateRaidIcon = function(self, unit)
        if not unit then return end
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        if not np or not np._muiRaidIcon then return end
        local index = GetRaidTargetIndex(unit)
        if not index then
            np._muiRaidIcon:Hide()
            return
        end
        local col, row = (index - 1) % 4, math.floor((index - 1) / 4)
        np._muiRaidIcon:SetTexCoord(col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25)
        np._muiRaidIcon:Show()
    end;

    UpdateAllRaidIcons = function(self)
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            if np._muiUnit then self:UpdateRaidIcon(np._muiUnit) end
        end
    end;

    -- The attack cursor's sword when an accepted quest still needs this NPC
    -- killed, the loot cursor's bag when it still needs something the NPC
    -- drops; nothing otherwise.
    UpdateQuestIcon = function(self, unit)
        if not unit then return end
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        if not np or not np._muiQuestIcon then return end
        local kind
        if MUI_DB.settings.nameplates.questIcons and not UnitIsPlayer(unit) then
            local guidKind, _, _, _, _, idStr = strsplit("-", UnitGUID(unit) or "")
            if guidKind == "Creature" or guidKind == "Vehicle" then
                kind = MUI_QuestHelper.objectiveTooltip:GetNpcObjectiveKind(tonumber(idStr))
            end
        end
        local icon = np._muiQuestIcon
        if kind == "kill" then
            icon:SetTexture("Interface\\Cursor\\Attack")
            icon:Show()
        elseif kind == "loot" then
            icon:SetTexture("Interface\\Cursor\\LootAll")
            icon:Show()
        else
            icon:Hide()
        end
    end;

    UpdateAllQuestIcons = function(self)
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            if np._muiUnit then self:UpdateQuestIcon(np._muiUnit) end
        end
    end;

    UpdateName = function(self, unit)
        if not unit then return end
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        if not np or not np._muiName then return end
        np._muiName:SetText(UnitName(unit) or "")
    end;

    -- Attackable NPCs: level coloured by difficulty against the player's level,
    -- as the target frame does (TargetFrameMixin:CheckLevel); "??" takes the
    -- impossible red. Friendly NPCs and players keep plain white.
    GetLevelColor = function(self, unit, lvl)
        if UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then
            return 1, 1, 1
        end
        local c = (lvl == -1) and QuestDifficultyColors["impossible"]
                  or GetCreatureDifficultyColor(lvl)
        return c.r, c.g, c.b
    end;

    UpdateLevel = function(self, unit)
        if not unit then return end
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        if not np or not np._muiLevel then return end

        local show = MUI_DB.settings.nameplates.showLevel
        if not show then
			np._muiLevel:SetWidth(0)
            np._muiLevel:SetText("")
            return
        end

        local lvl = UnitLevel(unit)
        if lvl == -1 then
            np._muiLevel:SetText("??")
            np._muiLevel:SetTextColor(self:GetLevelColor(unit, lvl))
			np._muiLevel:SetWidth(TEXT_LVL_W)
        elseif lvl and lvl > 0 then
            np._muiLevel:SetText(tostring(lvl))
            np._muiLevel:SetTextColor(self:GetLevelColor(unit, lvl))
			np._muiLevel:SetWidth(TEXT_LVL_W)
        else
            np._muiLevel:SetText("")
			np._muiLevel:SetWidth(0)
        end
    end;

    UpdateAllLevels = function(self)
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            if np._muiUnit then self:UpdateLevel(np._muiUnit) end
        end
    end;

    UpdateHealthText = function(self, unit)
        if not unit then return end
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        if not np or not np._muiHealthValue or not np._muiHealthPercent then return end

        local mode = (MUI_DB and MUI_DB.settings and MUI_DB.settings.nameplates
            and MUI_DB.settings.nameplates.healthText) or HP_NONE

        local cur = UnitHealth(unit) or 0
        local max = UnitHealthMax(unit) or 1
        local pct = max > 0 and math.floor(cur / max * 100) or 0

        -- Other players' HP is clamped to 0-100 by the engine in Classic Era (unless party/raid).
        -- Numeric is meaningless there, so any non-None mode collapses to percent-only.
        local hpClamped = UnitIsPlayer(unit)
            and not UnitIsUnit(unit, "player")
            and not UnitInParty(unit)
            and not UnitInRaid(unit)

        local showNumeric, showPercent
        if hpClamped then
            showNumeric = false
            showPercent = (mode ~= HP_NONE)
        else
            showNumeric = (mode == HP_NUMERIC or mode == HP_BOTH)
            showPercent = (mode == HP_PERCENT or mode == HP_BOTH)
        end

        -- Width 0 = auto-size. An exact-fit width measured at one plate scale truncates
        -- to "..." at another (the plate grows and shrinks with nameplateSelectedScale).
        local hpVal = np._muiHealthValue
        hpVal:SetText(showNumeric and tostring(cur) or "")
        hpVal:SetWidth(0)

        local hpPerc = np._muiHealthPercent
        if showPercent then
            hpPerc:SetText(pct .. "%")
            hpPerc:SetWidth(TEXT_HPPERC_W)
        else
            hpPerc:SetText("")
            hpPerc:SetWidth(0)
        end
    end;

    UpdateAllHealthText = function(self)
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            if np._muiUnit then self:UpdateHealthText(np._muiUnit) end
        end
    end;

    UpdateFill = function(self, unit)
        if not unit then return end
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        if not np or not np._muiClipper then return end
        local cur = UnitHealth(unit) or 0
        local max = UnitHealthMax(unit) or 1
        local pct = cur / math.max(max, 1)
        if pct <= 0 then
            np._muiClipper:Hide()
        else
            np._muiClipper:Show()
            np._muiClipper:SetWidth(FILL_MAX_W * pct)
        end
		
		np._muiHealthPercent:SetWidth(TEXT_HPPERC_W)
		np._muiHealthPercent:SetText(tostring(pct * 100) .. "%")
		
		np._muiHealthValue:SetText(tostring(cur))
		
    end;

    UpdateSelection = function(self, unit)
        if not unit then return end
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        if not np or not np._muiSelected then return end
        local isTarget = UnitIsUnit(unit, "target")
        if isTarget then
            np._muiSelected:Show()
            if np._muiDeselected then np._muiDeselected:Hide() end
        else
            np._muiSelected:Hide()
            if np._muiDeselected then np._muiDeselected:Show() end
        end
    end;

    UpdateAllSelections = function(self)
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            if np._muiUnit then self:UpdateSelection(np._muiUnit) end
        end
    end;

    -- Our visuals follow Blizzard's Nameplates > Size slider (the nameplateSize
    -- CVar, 1..5), which only resizes the native plate we've hidden.
    UpdateScale = function(self, unit)
        if not unit then return end
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        if not np or not np._muiBarBG then return end
        local scale = SCALE_STEPS[tonumber(GetCVar("nameplateSize"))] or 1.0
        np._muiBarBG:SetScale(BAR_SCALE * scale)
        np._muiOverlay:SetScale(scale)
    end;

    UpdateAllScales = function(self)
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            if np._muiUnit then self:UpdateScale(np._muiUnit) end
        end
    end;

    RegisterSettings = function(self)
        MUI.InjectOption({
            categoryId   = "NAMEPLATE_OPTIONS_CATEGORY_ID",
            variable     = "MUI_Nameplate_ShowLevel",
            type         = "checkbox",
            label        = "Show level",
            tooltip      = "Display the unit's level on their nameplate.",
            default      = false,
            tbl          = MUI_DB.settings.nameplates,
            key          = "showLevel",
            after        = NAMEPLATES_LABEL,
            onChange     = function() self:UpdateAllLevels() end,
        })

        MUI.InjectOption({
            categoryId   = "NAMEPLATE_OPTIONS_CATEGORY_ID",
            variable     = "MUI_Nameplate_HealthText",
            type         = "dropdown",
            label        = "Show health text",
            tooltip      = "Choose how to display the unit's health on their nameplate.",
            default      = HP_NONE,
            tbl          = MUI_DB.settings.nameplates,
            key          = "healthText",
            options      = {
                { HP_NONE,    "None"      },
                { HP_NUMERIC, "Numerical" },
                { HP_PERCENT, "Percent"   },
                { HP_BOTH,    "Both"      },
            },
            after        = "Show level",
            onChange     = function() self:UpdateAllHealthText() end,
        })

        MUI.InjectOption({
            categoryId   = "NAMEPLATE_OPTIONS_CATEGORY_ID",
            variable     = "MUI_Nameplate_QuestIcons",
            type         = "checkbox",
            label        = "Show quest objective icon",
            tooltip      = "Mark nameplates of NPCs an accepted quest still needs: swords to kill, a bag to loot.",
            default      = true,
            tbl          = MUI_DB.settings.nameplates,
            key          = "questIcons",
            after        = "Show health text",
            onChange     = function() self:UpdateAllQuestIcons() end,
        })
    end;

    HideAllNative = function(self, cframe)
        for _, region in ipairs(cframe:GetRegions()) do
            region:SetAlpha(0)
        end
        for _, child in ipairs(cframe:GetChildren()) do
            self:HideAllNative(child)
        end
    end;
}
