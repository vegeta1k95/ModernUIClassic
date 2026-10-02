-- MUI_Nameplates: since 1.15.9 Era has retail's own nameplates, so they are
-- left as Blizzard draws them. We add two things: a quest objective marker
-- (an icon beside the plate of an NPC an accepted quest still needs), and
-- the unit's level, which Blizzard only shows in its "Classic" plate style.

local ICON_SIZE = 18
local ICON_GAP = 4        -- between the marker and whatever is beside it
local LEVEL_GAP = 3        -- between the level and the name

object "ModuleNameplates" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Nameplates")
    end;

    OnEnable = function(self)
        self:RegisterSettings()

        self.driver = Frame("Frame", nil, "MUI_NameplateDriver")
        self.driver:RegisterEventHandler("NAME_PLATE_UNIT_ADDED", function(_, _, unit)
            local np = C_NamePlate.GetNamePlateForUnit(unit)
            if not np then return end
            np._muiUnit = unit
            self:UpdateQuestIcon(unit)
            self:UpdateLevel(unit)
        end)
        -- Blizzard has already released the plate's UnitFrame to its pool by
        -- now (it is nil here). Our pieces live on that UnitFrame and are set
        -- again for whichever unit acquires it next, so nothing to undo.
        self.driver:RegisterEventHandler("NAME_PLATE_UNIT_REMOVED", function(_, _, unit)
            local np = C_NamePlate.GetNamePlateForUnit(unit)
            if np then np._muiUnit = nil end
        end)

        -- Level colours are relative to the player's level and to whether the
        -- unit can be attacked, so our own ding or PvP toggle recolours all.
        local function levelChanged(_, _, unit)
            if unit == "player" then self:UpdateAllLevels() else self:UpdateLevel(unit) end
        end
        self.driver:RegisterEventHandler("UNIT_LEVEL",   levelChanged)
        self.driver:RegisterEventHandler("UNIT_FACTION", levelChanged)

        -- Markers follow the quest log (accept / progress / turn-in) and the
        -- bags (required source items).
        local watcher = MUI_QuestHelper.watcher
        for _, name in ipairs({ "OnQuestAdded", "OnQuestChanged", "OnQuestRemoved" }) do
            watcher:RegisterCallback(name, function() self:UpdateAllQuestIcons() end)
        end
        self.driver:RegisterEventHandler("BAG_UPDATE_DELAYED", function() self:UpdateAllQuestIcons() end)
    end;

    -- Unit frames are pooled separately from the plates and handed to a
    -- plate per unit, so everything of ours is kept on the UnitFrame itself.
    --
    -- The marker lives on Blizzard's unit frame, so it scales and fades with
    -- the plate.
    _QuestIcon = function(self, unitFrame)
        local icon = unitFrame._muiQuestIcon
        if not icon then
            icon = Texture(Frame(unitFrame), nil, "OVERLAY")
            icon:SetSize(ICON_SIZE)
            icon:Hide()
            unitFrame._muiQuestIcon = icon

            -- The buff list is switched on and off per unit type (and by the
            -- nameplate aura options), as is the whole auras frame.
            local auras = unitFrame.AurasFrame
            unitFrame._muiBuffList = Frame(auras.BuffListFrame)
            local function reanchor() self:_AnchorQuestIcon(unitFrame) end
            hooksecurefunc(auras.BuffListFrame, "SetShown", reanchor)
            hooksecurefunc(auras, "SetShown", reanchor)
            hooksecurefunc(unitFrame.ClassificationFrame, "UpdateShownState", reanchor)
            hooksecurefunc(unitFrame.RaidTargetFrame, "UpdateShownState", reanchor)
        end
        return icon
    end;

    -- The marker goes left of everything Blizzard stacks on that side of the
    -- health bar: the raid target icon, then the classification (elite /
    -- rare) icon, then the buff icons. The first two collapse when hidden,
    -- and a visible buff list is always laid out to its content (1 px wide
    -- when empty), so its outer edge is the outermost thing there. A hidden
    -- buff list keeps whatever size it last had, so then the marker chains
    -- off the classification frame instead. An offset from a collapsed
    -- frame collapses with it, so the gap only holds against a shown one:
    -- walk the chain down to the first that is, else the bar itself.
    _AnchorQuestIcon = function(self, unitFrame)
        local icon = unitFrame._muiQuestIcon
        icon:ClearAllPoints()
        if unitFrame._muiBuffList:IsVisible() then
            icon:LeftOf(unitFrame._muiBuffList, ICON_GAP)
        elseif unitFrame.ClassificationFrame:IsShown() then
            icon:LeftOf(unitFrame.ClassificationFrame, ICON_GAP)
        elseif unitFrame.RaidTargetFrame:IsShown() then
            icon:LeftOf(unitFrame.RaidTargetFrame, ICON_GAP)
        else
            icon:LeftOf(unitFrame.HealthBarsContainer, ICON_GAP)
        end
    end;

    -- The attack cursor's sword when an accepted quest still needs this NPC
    -- killed, the loot cursor's bag when it still needs something the NPC
    -- drops; nothing otherwise.
    UpdateQuestIcon = function(self, unit)
        if not unit then return end
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        if not np then return end
        local unitFrame = np.UnitFrame
        local kind
        if MUI_DB.settings.nameplates.questIcons and not UnitIsPlayer(unit) then
            local guidKind, _, _, _, _, idStr = strsplit("-", UnitGUID(unit) or "")
            if guidKind == "Creature" or guidKind == "Vehicle" then
                kind = MUI_QuestHelper.objectiveTooltip:GetNpcObjectiveKind(tonumber(idStr))
            end
        end
        if not kind then
            if unitFrame._muiQuestIcon then unitFrame._muiQuestIcon:Hide() end
            return
        end
        local icon = self:_QuestIcon(unitFrame)
        icon:SetTexture(kind == "kill" and "Interface\\Cursor\\Attack" or "Interface\\Cursor\\LootAll")
        self:_AnchorQuestIcon(unitFrame)
        icon:Show()
    end;

    -- Level text in front of the unit's name: it takes the name's own spot
    -- and the name starts right after it. Attackable NPCs take the
    -- difficulty colour against the player's level, as the target frame
    -- does; "??" takes the impossible red. Players and friendly NPCs stay
    -- white. Hidden while Blizzard shows its own level (the Classic plate
    -- style) and on name-only plates.
    UpdateLevel = function(self, unit)
        if not unit then return end
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        if not np then return end
        local unitFrame = np.UnitFrame
        local level = UnitLevel(unit)
        if not MUI_DB.settings.nameplates.showLevel or not level or level == 0
                or unitFrame.LevelFrame:IsShown()
                or not unitFrame.HealthBarsContainer:IsShown() then
            self:_HideLevel(unitFrame)
            return
        end

        local text = unitFrame._muiLevel
        if not text then
            text = FontString(Frame(unitFrame), nil, "OVERLAY", "SystemFont_NamePlate_Outlined")
            -- As Blizzard's own plate texts: without it the scaled text snaps
            -- to whole sizes and sits a pixel off the name at some plate
            -- scales (normal vs. the enlarged target plate).
            text:SetSmoothScaling(true)
            unitFrame._muiLevel = text
            unitFrame._muiName  = FontString(unitFrame.name)
            -- Blizzard re-anchors the name on every layout pass; put it
            -- back behind the level afterwards.
            hooksecurefunc(unitFrame, "UpdateAnchors", function()
                self:_PlaceLevel(unitFrame)
            end)
        end
        if UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then
            text:SetTextColor(1, 1, 1)
        else
            local c = (level == -1) and QuestDifficultyColors["impossible"] or GetCreatureDifficultyColor(level)
            text:SetTextColor(c.r, c.g, c.b)
        end
        text:SetText(level == -1 and "??" or tostring(level))
        text:Show()
        self:_PlaceLevel(unitFrame)
    end;

    -- Where Blizzard starts the name for the current plate style, as the
    -- (point, relativePoint, x, y) of its first anchor on the health bar
    -- container (NamePlateUnitFrameMixin:UpdateAnchors). nil for the style
    -- with the name centred above the bar. Nameplate regions are restricted:
    -- addon code can't measure them (GetPoint and the like throw), so the
    -- anchor is rebuilt from Blizzard's settings instead of being read back.
    _NameAnchor = function(self)
        local options = NamePlateSetupOptions
        local styles = NamePlateConstants.NAME_ANCHOR_STYLES
        if options.unitNameAnchorStyle == styles.InsideHealthBar then
            return "LEFT", "LEFT", 4, 0
        elseif options.unitNameAnchorStyle ~= styles.CenteredAboveHealthBar then
            return "BOTTOMLEFT", "TOPLEFT", 4, options.healthBarToNameAboveSpacing
        end
    end;

    -- Seat the level where the name starts and hang the name off its right
    -- edge. A centred name keeps its place; the level goes just left of it.
    _PlaceLevel = function(self, unitFrame)
        local text, name = unitFrame._muiLevel, unitFrame._muiName
        if not text:IsShown() then return end
        local container = unitFrame.HealthBarsContainer
        -- Same font and height as Blizzard gives the name and health text:
        -- outlined when the name sits inside the bar, plain when above it.
        local options = NamePlateSetupOptions
        local inside = options.unitNameAnchorStyle == NamePlateConstants.NAME_ANCHOR_STYLES.InsideHealthBar
        text:SetFontObject(inside and "SystemFont_NamePlate_Outlined" or "SystemFont_NamePlate")
        text:SetTextHeight(options.healthBarFontHeight)
        -- SetTextHeight scales the glyphs but not the string's own box, which
        -- leaves the text off its anchor line. Blizzard gives the name a box
        -- of exactly one line for that reason (UpdateAnchors); do the same,
        -- so the level sits on the name's and the health text's line.
        text:SetHeight(text:GetLineHeight())
        local point, relativePoint, x, y = self:_NameAnchor()
        text:ClearAllPoints()
        if not point then
            text:LeftOf(name, LEVEL_GAP)
            return
        end
        text:SetPoint(point, container, relativePoint, x, y)
        name:SetPoint(point, text, point == "LEFT" and "RIGHT" or "BOTTOMRIGHT", LEVEL_GAP, 0)
        unitFrame._muiNameMoved = true
    end;

    -- Hide the level and give the name its place back.
    _HideLevel = function(self, unitFrame)
        local text = unitFrame._muiLevel
        if not text or not text:IsShown() then return end
        text:Hide()
        if unitFrame._muiNameMoved then
            unitFrame._muiNameMoved = false
            local point, relativePoint, x, y = self:_NameAnchor()
            if point then
                unitFrame._muiName:SetPoint(point, unitFrame.HealthBarsContainer, relativePoint, x, y)
            end
        end
    end;

    UpdateAllLevels = function(self)
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            if np._muiUnit then self:UpdateLevel(np._muiUnit) end
        end
    end;

    UpdateAllQuestIcons = function(self)
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            if np._muiUnit then self:UpdateQuestIcon(np._muiUnit) end
        end
    end;

    RegisterSettings = function(self)
        MUI.InjectOption({
            categoryId   = "NAMEPLATE_OPTIONS_CATEGORY_ID",
            variable     = "MUI_Nameplate_ShowLevel",
            type         = "checkbox",
            label        = "Show level",
            tooltip      = "Show the unit's level on its nameplate (Blizzard only does in the Classic style).",
            default      = true,
            tbl          = MUI_DB.settings.nameplates,
            key          = "showLevel",
            after        = NAMEPLATES_LABEL,
            onChange     = function() self:UpdateAllLevels() end,
        })

        MUI.InjectOption({
            categoryId   = "NAMEPLATE_OPTIONS_CATEGORY_ID",
            variable     = "MUI_Nameplate_QuestIcons",
            type         = "checkbox",
            label        = "Show quest objective icon",
            tooltip      = "Mark nameplates of NPCs an accepted quest still needs: a sword to kill, a bag to loot.",
            default      = true,
            tbl          = MUI_DB.settings.nameplates,
            key          = "questIcons",
            after        = "Show level",
            onChange     = function() self:UpdateAllQuestIcons() end,
        })
    end;
}
