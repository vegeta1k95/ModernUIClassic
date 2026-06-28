-- UnitFrameTarget: skins TargetFrame and owns the target-side widgets:
-- health/mana bars + value texts, classification border (elite / rare /
-- boss), header tint, combat glow, hit-text container, dead text, and the
-- "this NPC is a quest objective" portrait flag.
--
-- The aura container is created here (so its anchor rests against
-- self.mana), but per-aura layout lives in UnitFrameTargetAuras — the
-- container exposes itself as self.auraContainer for that consumer.
--
-- UpdateBorder is split off because TargetFrame_CheckClassification fires
-- independently of TargetFrame_Update and we don't want one event to
-- redo the other's work.

local TEX = MUI.TEX_SKIN .. "unitframes\\"

class "UnitFrameTarget" {
    __init = function(self, module)
        self.module = module
		
        Frame(TargetFrameHealthBar):HideFrame()
        Frame(TargetFrameManaBar):HideFrame()
        Frame(TargetFrameBackground):HideFrame()
        Texture(TargetFrameNameBackground):SetTexture(nil)

        self.frame = UnitFrameEditable(TargetFrame, "Target")
        self.frame:ClearAllPoints()
        self.frame:SetSize(171, 58)
        self.frame:SetPoint("BOTTOMLEFT", MUI_ModuleActionBars.bars.MAIN1, "TOPRIGHT", 38, 162)
        self.frame:EditModeSetDefaultPosition(function(f)
            f:ClearAllPoints()
            f:SetPoint("BOTTOMLEFT", MUI_ModuleActionBars.bars.MAIN1, "TOPRIGHT", 38, 162)
        end)

        self._portrait = Texture(TargetFramePortrait)
        self._portrait:SetSize(55, 54)
        self._portrait:ClearAllPoints()
        self._portrait:AlignTop(self.frame, 1)
        self._portrait:AlignRight(self.frame, 3)

        self._frameTex = Texture(self.frame)
        self._frameTex:SetTextureRegion(TEX .. "target-frame", 512, 128, 66, 0, 380, 128)
        self._frameTex:SetDrawLayer("ARTWORK")
        self._frameTex:Fill(self.frame)

        self.borderFrame = Frame("Frame", self.frame, "MUI_TargetBorderFrame")
        self.borderFrame:Fill(self._portrait)
        self.borderFrame:SetFrameLevel(self.frame:GetFrameLevel() + 4)
        self.border = Texture(self.borderFrame, nil, "ARTWORK")
        self.border:FillParentPadding(-6, -8, -12, -8)

        self.combatFrame = Frame("Frame", self.frame, "MUI_TargetCombatFrame")
        self.combatFrame:FillParent()
        self.combatFrame:SetFrameLevel(self.frame:GetFrameLevel() + 5)
        self.combat = Texture(self.combatFrame, nil, "ARTWORK")
        self.combat:SetTextureRegion(TEX .. "target-frame-combat", 512, 128, 66, 0, 380, 128)
        self.combat:SetVertexColor(1, 0, 0, 1)
        self.combat:FillParent()
        self.combat:Hide()

        self.hitTextFrame = Frame("Frame", self.frame, "MUI_TargetHitTextFrame")
        self.hitTextFrame:Fill(self._portrait)
        self.hitTextFrame:SetFrameStrata("HIGH")
        self.hitTextFrame:SetFrameLevel(50)
        if TargetFrame.feedbackText then
            self.hitTextFrame:Reparent(TargetFrame.feedbackText)
            FontString(TargetFrame.feedbackText):SetDrawLayer("OVERLAY", 7)
        end

        -- PVP icon must render above the combat glow — reparent into hitTextFrame (level 50).
        self.hitTextFrame:Reparent(TargetFrameTextureFramePVPIcon)
        local targetPvpIcon = Texture(TargetFrameTextureFramePVPIcon)
        targetPvpIcon:SetSize(58, 58)
        targetPvpIcon:SetDrawLayer("OVERLAY")
        targetPvpIcon:ClearAllPoints()
        targetPvpIcon:Below(self._portrait, -26)
        targetPvpIcon:RightOf(self._portrait, -22)

        self.header = Texture(self.frame, nil, "BORDER")
        self.header:SetTexture(TEX .. "target-frame-header.tga")
        self.header:SetSize(256*0.46, 32*0.46)
        self.header:AlignParentTopLeft(8, 1.5)
        self.header:SetBlendMode("BLEND")
        self.header:SetAlpha(1)

        local barLevel = self.frame:GetFrameLevel() + 2
        self.health = AnimatedBar(self.frame, "MUI_TargetHealth", 116, 29)
        self.health:LeftOf(self._portrait, -3, -2.5)
        self.health:SetFrameLevel(barLevel)
        self.health:SetFillTexture(TEX .. "target-health.tga")
        self.health:SetFillColor(0.4, 1.0, 0.13, 1)
        self.health:SetCutoutColor(1, 0, 0, 1)
        self.health:SetFillDirection("LEFT")

        self.mana = AnimatedBar(self.frame, "MUI_TargetMana", 120, 14)
        self.mana:AlignLeft(self.health, 2)
        self.mana:Below(self.health, -6.5)
        self.mana:SetFrameLevel(barLevel)
        self.mana:SetFillTexture(TEX .. "target-resource")
        self.mana:SetFillDirection("LEFT")

        self.healthText = self.module:CreateBarText(self.frame, self.health, 9)
        self.manaText   = self.module:CreateBarText(self.frame, self.mana,   9, self.health)

        self.deadText = FontString(TargetFrameTextureFrameDeadText)
        self.deadText:SetParent(self.health)
        self.deadText:ClearAllPoints()
        self.deadText:CenterInParent()

        local COLS      = 6
        local SPACING   = 3
        local ICON_SIZE = 22
        self.auraContainer = Frame("Frame", Frame(TargetFrame), "MUI_TargetAuraContainer")
        self.auraContainer:Below(self.mana, 0.5)
        self.auraContainer:AlignLeft(self.mana, 1)
        self.auraContainer:SetSize(COLS * (ICON_SIZE + SPACING), 0.1)

        self:_SetupNameAndLevel()
        self:_SetupQuestFlag()

        hooksecurefunc("TargetFrame_CheckClassification", function()
            self:UpdateBorder()
        end)
        hooksecurefunc("TargetFrame_Update", function()
            self:OnTargetChanged()
        end)

    end;

    _SetupNameAndLevel = function(self)
        local nameFS = FontString(TargetFrame.name)
        nameFS:ClearAllPoints()
        nameFS:SetWidth(80)
        nameFS:SetPoint("LEFT", self.header, "CENTER", -35, 1)
        nameFS:SetJustifyH("LEFT")
        nameFS:SetFont(MUI.FONT, 9)
        nameFS:SetTextColor(1, 0.82, 0)

        local levelFS = FontString(TargetFrameTextureFrameLevelText)
        levelFS:SetFont(MUI.FONT, 9)
        levelFS:SetTextColor(1, 0.82, 0)
        levelFS:SetJustifyH("LEFT")

        local function reanchor()
            levelFS:ClearAllPoints()
            levelFS:SetPoint("LEFT", self.header, "CENTER", -57, 1)
        end
        reanchor()
        hooksecurefunc("TargetFrame_UpdateLevelTextAnchor", reanchor)
        if BossTargetFrame_UpdateLevelTextAnchor then
            hooksecurefunc("BossTargetFrame_UpdateLevelTextAnchor", reanchor)
        end

        local skull = Texture(TargetFrameTextureFrameHighLevelTexture)
        skull:SetTexture(TEX .. "flag-skull")
        skull:SetTexCoord(0, 1, 0, 1)
        skull:SetSize(skull:GetWidth()*0.9, skull:GetHeight()*0.9)
        skull:ClearAllPoints()
        skull:CenterAt(self.header, -51, 1)
    end;

    -- Quest flag: shown below the portrait when the target is a singular
    -- 0/1 kill/loot objective of any DB quest. Parented to hitTextFrame
    -- (level 50) so it draws above the combat glow on combatFrame
    -- (level +5) — same reason the PVP icon was re-parented there.
    _SetupQuestFlag = function(self)
        self.questFlag = Texture(self.hitTextFrame, nil, "OVERLAY")
        self.questFlag:SetTexture(TEX .. "flag-quest")
        self.questFlag:SetTexCoord(0, 1, 0, 1)
        self.questFlag:SetSize(22, 22)
        self.questFlag:Below(Texture(TargetFramePortrait), -11)
        self.questFlag:Hide()
    end;

    OnTargetChanged = function(self)
        if not UnitExists("target") then
            if self.questFlag then self.questFlag:Hide() end
            return
        end

        self.health:SuppressCutout(0.1)
        self.mana:SuppressCutout(0.1)

        self:UpdateBars(true)
        self:UpdateBorder()
        self:UpdateQuestFlag()
    end;

    -- Show `flag-quest` below the portrait when the targeted NPC is a
    -- *unique* quest kill target — i.e. it's referenced as an objective by
    -- some quest in the DB AND it has at most one spawn point. Filters out
    -- generic "kill 10 X" mobs like Saltstone Basilisks (20 spawns) so the
    -- flag only fires for named/rare/scripted single-spawn targets.
    UpdateQuestFlag = function(self)
        if not UnitExists("target") or UnitIsPlayer("target") then
            self.questFlag:Hide(); return
        end
        local guid = UnitGUID("target")
        if not guid then self.questFlag:Hide(); return end
        local kind, _, _, _, _, idStr = strsplit("-", guid)
        if kind ~= "Creature" and kind ~= "Vehicle" and kind ~= "Pet" then
            self.questFlag:Hide(); return
        end
        local npcId = tonumber(idStr)
        local npc = npcId and MUI_NpcDB and MUI_NpcDB:Get(npcId)
        if not (npc and npc.questObjective and #npc.questObjective > 0) then
            self.questFlag:Hide(); return
        end
        local spawnTotal = 0
        if npc.spawns then
            for _, coords in pairs(npc.spawns) do
                spawnTotal = spawnTotal + #coords
                if spawnTotal > 1 then break end
            end
        end
        if spawnTotal == 1 then
            self.questFlag:Show()
        else
            self.questFlag:Hide()
        end
    end;

    UpdateBars = function(self, instant)
        if not UnitExists("target") then return end

        local health    = UnitHealth("target")
        local maxHealth = UnitHealthMax("target")
        local mana      = UnitPower("target")
        local maxMana   = UnitPowerMax("target")

        local reaction         = UnitReaction("target", "player")
        local isPlayer         = UnitIsPlayer("target")
        local isTappedByOthers = UnitIsTapDenied and UnitIsTapDenied("target")

        local isNone = GetCVar("statusTextDisplay") == "NONE"

        self.health:SetMaxValue(maxHealth)
        self.health:SetBarValue(health, instant)
        self.healthText.value:SetText(self.module:FormatValue(health, maxHealth, "target", true))
        if isNone then self.healthText.value:Hide() end

        if maxMana > 0 then
            self.mana:Show()
            self.mana:SetMaxValue(maxMana)
            self.mana:SetBarValue(UnitPower("target"), instant)
            self.mana:SetFillColor(self.module:GetPowerColor("target"))
            self.manaText.value:SetText(self.module:FormatValue(mana, maxMana, "target"))
            if isNone then self.manaText.value:Hide() end
        else
            self.mana:Hide()
            self.manaText.value:SetText("")
        end

        self.health:SetFillColor(0.5, 1.0, 0.13, 1)

        if isPlayer then
            self.header:SetVertexColor(0.1, 0.1, 1, 1)
        elseif isTappedByOthers then
            self.header:SetVertexColor(0.5, 0.5, 0.5, 1)
        elseif reaction and reaction <= 2 then
            self.header:SetVertexColor(1, 0, 0, 1)
        elseif reaction and reaction <= 4 then
            self.header:SetVertexColor(1, 1, 0, 1)
        else
            self.header:SetVertexColor(0, 1, 0, 1)
        end

        if health == 0 then
            self.deadText:Show()
            self.healthText.value:Hide()
            self.manaText.value:Hide()
        else
            self.deadText:Hide()
            if not isNone then
                self.healthText.value:Show()
                self.manaText.value:Show()
            end
        end
    end;

    UpdateBorder = function(self)
        if not UnitExists("target") then return end
        local classification = UnitClassification("target")

        if classification == "worldboss" then
            self.border:SetTextureRegion(TEX .. "target-frame-elite-boss", 256, 256, 47, 47, 160, 160)
        elseif classification == "rareelite" then
            self.border:SetTextureRegion(TEX .. "target-frame-elite-rare", 256, 256, 47, 47, 160, 160)
        elseif classification == "elite" then
            self.border:SetTextureRegion(TEX .. "target-frame-elite", 256, 256, 47, 47, 160, 160)
        elseif classification == "rare" then
            self.border:SetTextureRegion(TEX .. "target-frame-rare", 256, 256, 47, 47, 160, 160)
        else
            self.border:SetTexture("")
        end
        Texture(TargetFrameTextureFrameTexture):Hide()
    end;
}
