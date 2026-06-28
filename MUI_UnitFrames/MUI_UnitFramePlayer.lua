-- UnitFramePlayer: skins PlayerFrame and owns the player-side widgets:
-- health/mana bars + value texts, combat / resting overlay glow, hit-text
-- container, PVP icon/timer, and the resting-zzZ flipbook animation.
--
-- Combat/resting glow + flipbook update on a shared OnUpdate so we don't
-- spawn multiple per-frame tickers. Resting glow shares the pulse phase
-- with the combat glow (one timeline, mutually exclusive states).

local TEX = MUI.TEX_SKIN .. "unitframes\\"

-- Editable wrapper around a native (secure) unit frame. Wrapping keeps it the
-- same Frame the widgets anchor to; Editable adds the drag overlay. The frame's
-- own children scale with it, so the default scale hook works. Moving/scaling a
-- protected frame is fine out of combat (edit mode); never Show/Hide/SetParent it.
class "UnitFrameEditable" : extends {"Frame", "Editable"} {
    __init = function(self, native, label)
        Frame.__init(self, native)
        Editable.__init(self)
        self:EditModeSetLabel(label)
        self:EditModeSetupSettings(function(content) end)
    end;
}

class "UnitFramePlayer" {
    __init = function(self, module)
        self.module = module
		
		
        Frame(PlayerFrameHealthBar):HideFrame()
        Frame(PlayerFrameHealthBarText):HideFrame()
        Frame(PlayerFrameHealthBarTextLeft):HideFrame()
        Frame(PlayerFrameHealthBarTextRight):HideFrame()
        Frame(PlayerFrameManaBar):HideFrame()
        Frame(PlayerFrameManaBarText):HideFrame()
        Frame(PlayerFrameManaBarTextLeft):HideFrame()
        Frame(PlayerFrameManaBarTextRight):HideFrame()
        Frame(PlayerFrameBackground):HideFrame()
        Texture(PlayerFrameTexture):Hide()
        Texture(PlayerStatusTexture):SetTexture("")

        self.frame = UnitFrameEditable(PlayerFrame, "Player")
        self.frame:ClearAllPoints()
        self.frame:SetSize(171, 58)
        self.frame:SetPoint("BOTTOMRIGHT", MUI_ModuleActionBars.bars.MAIN1, "TOPLEFT", -38, 162)
        self.frame:EditModeSetDefaultPosition(function(f)
            f:ClearAllPoints()
            f:SetPoint("BOTTOMRIGHT", MUI_ModuleActionBars.bars.MAIN1, "TOPLEFT", -38, 162)
        end)

        self._portrait = Texture(PlayerPortrait)
        self._portrait:SetSize(56, 54)
        self._portrait:ClearAllPoints()
        self._portrait:AlignTop(self.frame, 1)
        self._portrait:AlignLeft(self.frame, 1)
        self._portrait:SetDrawLayer("BACKGROUND")

        self._frameTex = Texture(self.frame)
        self._frameTex:SetTextureRegion(TEX .. "player-frame", 512, 128, 63, 0, 384, 128)
        self._frameTex:SetDrawLayer("ARTWORK")
        self._frameTex:FillParentPadding(-2,0,0,0)

        local barLevel = self.frame:GetFrameLevel() + 2
        self.health = AnimatedBar(self.frame, "MUI_PlayerHealth", 114.5, 28)
        self.health:RightOf(self._portrait, -0.5, -2)
        self.health:SetFrameLevel(barLevel)
        self.health:SetFillTexture(TEX .. "player-health.tga")
        self.health:SetFillColor(0.5, 1.0, 0.13, 1)
        self.health:SetCutoutColor(1, 0, 0, 1)
        self.health:SetMaxValue(UnitHealthMax("player"))
        self.health:SetBarValue(UnitHealth("player"), true)

        self.mana = AnimatedBar(self.frame, "MUI_PlayerMana", 114.5, 14)
        self.mana:AlignLeft(self.health)
        self.mana:Below(self.health, -6.5)
        self.mana:SetFrameLevel(barLevel)
        self.mana:SetFillTexture(TEX .. "player-resource.tga")
        self.mana:SetFillColor(self.module:GetPowerColor("player"))
        self.mana:SetMaxValue(UnitPowerMax("player"))
        self.mana:SetBarValue(UnitPower("player"), true)

        self.healthText = self.module:CreateBarText(self.frame, self.health, 9)
        self.manaText   = self.module:CreateBarText(self.frame, self.mana,   9, self.health)

        local nameFS = FontString(PlayerFrame.name)
        nameFS:ClearAllPoints()
        nameFS:SetJustifyH("LEFT")
        nameFS:AlignTop(self.frame, 8.5 )
        nameFS:RightOf(self._portrait, 4)
        nameFS:SetFont(MUI.FONT, 9)
        nameFS:SetTextColor(1, 0.82, 0)

        local levelFS = FontString(PlayerLevelText)
        local function anchorPlayerLevel()
            levelFS:ClearAllPoints()
            levelFS:SetJustifyH("RIGHT")
            levelFS:AlignRight(self.frame, 4)
            levelFS:AlignTop(self.frame, 10)
        end
        anchorPlayerLevel()
        levelFS:SetFont(MUI.FONT, 9)
        levelFS:SetTextColor(1, 0.82, 0)
        -- PlayerFrame_UpdateLevelTextAnchor re-SetPoints the text on every
        -- UNIT_LEVEL / refresh, so hook it and re-apply our anchor.
        hooksecurefunc("PlayerFrame_UpdateLevelTextAnchor", anchorPlayerLevel)
		
		

        -- Suppress vanilla combat/attack/rest glow visuals
        local attackGlow = Texture(PlayerAttackGlow)
        local attackIcon = Texture(PlayerAttackIcon)
        local restIcon   = Texture(PlayerRestIcon)
        local restGlow   = Texture(PlayerRestGlow)
        attackGlow:SetTexture("")
        attackIcon:SetTexture("")
        restIcon:SetTexture("")
        restGlow:SetTexture("")
        hooksecurefunc("PlayerFrame_UpdateStatus", function()
            attackGlow:SetAlpha(0)
            attackIcon:SetAlpha(0)
            restIcon:SetAlpha(0)
            restGlow:SetAlpha(0)
        end)
		
        self:_BuildOverlays()
        self:_BuildHitTextFrame()
        self:UpdateTexts()
    end;

    _BuildOverlays = function(self)
        self.combatOverlay = Frame("Frame", self.frame, "MUI_CombatOverlay")
        self.combatOverlay:FillParent()
        self.combatOverlay:SetFrameStrata("MEDIUM")
        self.combatGlowTex = Texture(self.combatOverlay, nil, "ARTWORK")
        self.combatGlowTex:SetTextureRegion(TEX .. "player-frame-combat", 512, 128, 63, 0, 384, 128)
        self.combatGlowTex:FillParent()
        self.combatGlowTex:SetVertexColor(1, 0, 0)
        self.combatGlowTex:SetAlpha(0)

        self.combatIcon = Texture(self.combatOverlay, nil, "OVERLAY")
        self.combatIcon:SetTexture(TEX .. "flag-idle")
        self.combatIcon:SetSize(32*0.45)
        self.combatIcon:AlignBottom(self._portrait)
        self.combatIcon:AlignRight(self._portrait, 2)

        self.restingOverlay = Frame("Frame", self.frame, "MUI_RestingOverlay")
        self.restingOverlay:FillParent()
        self.restingOverlay:SetFrameStrata("MEDIUM")
        self.restingGlowTex = Texture(self.restingOverlay, nil, "OVERLAY")
        self.restingGlowTex:SetTextureRegion(TEX .. "player-frame-glow", 512, 128, 63, 0, 384, 128)
        self.restingGlowTex:FillParent()
        self.restingGlowTex:SetVertexColor(1, 0.82, 0, 1)
        self.restingGlowTex:SetAlpha(0)

        -- Resting zzZ flipbook (6 cols x 7 rows = 42 frames, 1.5s loop)
        self.restAnim = Frame("Frame", self.frame, "MUI_RestAnim")
        self.restAnim:SetSize(26, 26)
        self.restAnim:SetFrameStrata("MEDIUM")
        self.restAnim:SetFrameLevel(self.frame:GetFrameLevel() + 4)
        self.restAnim:AlignTop(self._portrait, -16)
        self.restAnim:AlignRight(self._portrait, -2)
        self.restAnimTex = Texture(self.restAnim, nil, "OVERLAY")
        self.restAnimTex:SetTexture(TEX .. "animation-sleep")
        self.restAnimTex:SetSize(26, 26)
        self.restAnimTex:CenterInParent()
        self.restAnimTime  = 0
        self.restAnimFrame = -1
        self.restAnim:Hide()

        self.combatPulseTime     = 0
        self.combatPulseDuration = 1
        self.combatGlowMax       = 1

        self.combatOverlay:SetScript("OnUpdate", function(_, elapsed)
            self:UpdateCombatGlow(elapsed)
        end)
    end;

    _BuildHitTextFrame = function(self)
        -- Native combat feedback text ("Miss"/"Dodge"/etc.) sits on PlayerFrame at lower
        -- effective level than combatOverlay, so the glow occludes it. Re-parent into a
        -- frame above combatOverlay.
        self.hitTextFrame = Frame("Frame", self.frame, "MUI_HitTextFrame")
        self.hitTextFrame:Fill(self._portrait)
        self.hitTextFrame:SetFrameStrata("HIGH")
        self.hitTextFrame:SetFrameLevel(50)

        local hitIndicator = FontString(PlayerHitIndicator)
        hitIndicator:SetParent(self.hitTextFrame)
        hitIndicator:SetDrawLayer("OVERLAY", 7)
        hitIndicator:ClearAllPoints()
        hitIndicator:CenterInParent()

        if PlayerFrame.feedbackText and PlayerFrame.feedbackText ~= PlayerHitIndicator then
            self.hitTextFrame:Reparent(PlayerFrame.feedbackText)
            FontString(PlayerFrame.feedbackText):SetDrawLayer("OVERLAY", 7)
        end

        -- PVP icon/timer need to render above combat/resting glow overlays.
        -- Reparent into hitTextFrame (already above both overlays).
        self.hitTextFrame:Reparent(PlayerPVPIcon)
        local pvpIcon = Texture(PlayerPVPIcon)
        pvpIcon:SetSize(56, 57)
        pvpIcon:SetDrawLayer("OVERLAY")
        pvpIcon:ClearAllPoints()
        pvpIcon:Below(self._portrait, -26)
        pvpIcon:AlignLeft(self._portrait, -18)

        self.hitTextFrame:Reparent(PlayerPVPTimerText)
        local pvpTimer = FontString(PlayerPVPTimerText)
        pvpTimer:ClearAllPoints()
        pvpTimer:SetJustifyH("CENTER")
        pvpTimer:Below(pvpIcon, -22, -10)
        pvpTimer:SetFont(MUI.FONT, 9)
    end;

    UpdateBars = function(self)
        local health    = UnitHealth("player")
        local maxHealth = UnitHealthMax("player")
        self.health:SetMaxValue(maxHealth)
        self.health:SetBarValue(health)

        local mana    = UnitPower("player")
        local maxMana = UnitPowerMax("player")
        self.mana:SetMaxValue(maxMana)
        self.mana:SetBarValue(mana)

        self:UpdateTexts()
    end;

    UpdateTexts = function(self)
        local health    = UnitHealth("player")
        local maxHealth = UnitHealthMax("player")
        self.healthText.value:SetText(self.module:FormatValue(health, maxHealth))

        local mana    = UnitPower("player")
        local maxMana = UnitPowerMax("player")
        self.manaText.value:SetText(self.module:FormatValue(mana, maxMana))

        if GetCVar("statusTextDisplay") == "NONE" then
            self.healthText.value:Hide()
            self.manaText.value:Hide()
        end
    end;

    UpdatePowerType = function(self)
        self.mana:SetFillColor(self.module:GetPowerColor("player"))
    end;

    HasAggro = function(self)
        if UnitExists("target") and UnitExists("targettarget")
                and UnitIsUnit("targettarget", "player") then
            return true
        end
        if UnitExists("pettarget") and UnitIsUnit("pettarget", "player") then
            return true
        end
        return false
    end;

    UpdateCombatGlow = function(self, elapsed)
        local playerIsCombat  = UnitAffectingCombat("player")
        local playerIsResting = IsResting()
        local hasAggro        = playerIsCombat and self:HasAggro()

        if playerIsCombat then
            self.combatIcon:SetTexture(TEX .. "flag-combat")
        else
            self.combatIcon:SetTexture(TEX .. "flag-idle")
        end

        local target = self.module.target

        if hasAggro then
            self.combatGlowTex:SetAlpha(1)
            if target then
                target.combat:Show()
                target.combat:SetAlpha(1)
            end
            self.restingGlowTex:SetAlpha(0)
            self.combatPulseTime = 0
        elseif playerIsCombat then
            if target then target.combat:Hide() end
            -- Modulo wrap (was single-step subtract) so a laggy frame with
            -- elapsed > combatPulseDuration can't leave progress > 1 and
            -- push sin() negative — Era's SetAlpha rejects negatives.
            self.combatPulseTime = (self.combatPulseTime + elapsed) % self.combatPulseDuration
            local progress = self.combatPulseTime / self.combatPulseDuration
            local alpha = math.sin(progress * 3.14159)
            self.combatGlowTex:SetAlpha(alpha)
            self.restingGlowTex:SetAlpha(0)
        elseif playerIsResting then
            if target then target.combat:Hide() end
            self.combatPulseTime = (self.combatPulseTime + elapsed) % self.combatPulseDuration
            local progress = self.combatPulseTime / self.combatPulseDuration
            local alpha = math.sin(progress * 3.14159)
            self.restingGlowTex:SetAlpha(alpha)
            self.combatGlowTex:SetAlpha(0)
        else
            if target then target.combat:Hide() end
            local a = self.combatGlowTex:GetAlpha()
            if a > 0 then
                self.combatGlowTex:SetAlpha(math.max(0, a - elapsed * 2))
            end
            a = self.restingGlowTex:GetAlpha()
            if a > 0 then
                self.restingGlowTex:SetAlpha(math.max(0, a - elapsed * 2))
            end
            self.combatPulseTime = 0
        end

        if playerIsResting and not playerIsCombat then
            if not self.restAnim:IsShown() then
                self.restAnim:Show()
                self.restAnimTime  = 0
                self.restAnimFrame = -1
            end
            self.restAnimTime = self.restAnimTime + elapsed
            if self.restAnimTime >= 1.5 then
                self.restAnimTime = self.restAnimTime - 1.5
            end
            local fi = math.floor(self.restAnimTime / 1.5 * 42)
            if fi > 41 then fi = 41 end
            if fi ~= self.restAnimFrame then
                self.restAnimFrame = fi
                local col = mod(fi, 6)
                local row = math.floor(fi / 6)
                local cw = 60 / 512
                local u = col * cw
                local v = row * cw
                self.restAnimTex:SetTexCoord(u, u + cw, v, v + cw)
            end
        else
            if self.restAnim:IsShown() then
                self.restAnim:Hide()
            end
        end
    end;
}
