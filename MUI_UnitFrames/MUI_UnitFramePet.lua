-- UnitFramePet: skins PetFrame and owns the pet-side widgets — health
-- and mana bars, combat glow overlay, name/happiness/debuff anchors.
--
-- Pet combat glow is independent of the player one because the pet can
-- be in combat without the player being (and vice versa). Pulse phase
-- is its own ticker on the petCombatOverlay.

local TEX = MUI.TEX_SKIN .. "unitframes\\"

class "UnitFramePet" {
    __init = function(self, module, anchorWidget)
        self.module = module

        Frame(PetFrameHealthBar):HideFrame()
        Frame(PetFrameManaBar):HideFrame()

        self.frame = UnitFrameEditable(PetFrame, "Pet")
        self.frame:ClearAllPoints()
        self.frame:SetSize(103, 41)
        self.frame:Below(anchorWidget, 5)
        self.frame:AlignRight(anchorWidget)
        self.frame:EditModeSetDefaultPosition(function(f)
            f:ClearAllPoints()
            f:Below(anchorWidget, 5)
            f:AlignRight(anchorWidget)
        end)
        -- Only pet classes get the pet frame in edit mode; others never have a
        -- pet, so there's nothing to position.
        local _, class = UnitClass("player")
        self.frame:EditModeEnabled(class == "HUNTER" or class == "WARLOCK")

        hooksecurefunc("PetFrame_Update", function()
            Texture(PetFrameTexture):Hide()
        end)

        self._frameTex = Texture(self.frame)
        self._frameTex:SetTextureRegion(TEX .. "tot-frame", 256, 128, 12, 16, 230, 90)
        self._frameTex:FillParent()
        self._frameTex:SetDrawLayer("ARTWORK")

        self._portrait = Texture(PetPortrait)
        self._portrait:ClearAllPoints()
        self._portrait:AlignTop(self.frame, 6)
        self._portrait:AlignLeft(self.frame, 5)
        self._portrait:SetSize(32)

        Texture(PetAttackModeTexture):SetTexture("")
        PetAttackModeTexture.Show = function() end

        self.combatOverlay = Frame("Frame", self.frame, "MUI_PetCombatOverlay")
        self.combatOverlay:FillParent()
        self.combatOverlay:SetFrameLevel(self.frame:GetFrameLevel() + 3)
        self.combatGlowTex = Texture(self.combatOverlay, nil, "ARTWORK")
        self.combatGlowTex:SetTextureRegion(TEX .. "tot-frame-combat", 256, 128, 12, 16, 230, 90)
        self.combatGlowTex:FillParent()
        self.combatGlowTex:SetVertexColor(1, 0, 0, 1)
        self.combatGlowTex:SetAlpha(0)

        self.combatPulseTime     = 0
        self.combatPulseDuration = 1

        self.combatOverlay:SetScript("OnUpdate", function(_, elapsed)
            self:UpdateCombatGlow(elapsed)
        end)

        self.health = AnimatedBar(self.frame, "MUI_PetHealth", 64, 13)
        self.health:RightOf(self._portrait, 0, 2.5)
        self.health:SetFillTexture(TEX .. "player-health.tga")
        self.health:SetFillColor(0, 0.9, 0.2, 1)

        self.mana = AnimatedBar(self.frame, "MUI_PetMana", 64, 9)
        self.mana:Below(self.health, -2)
        self.mana:AlignLeft(self.health)
        self.mana:SetFillTexture(TEX .. "player-resource.tga")

        local petName = FontString(PetName)
        petName:SetJustifyH("LEFT")
        petName:ClearAllPoints()
        petName:Above(self.health)
        petName:SetFont(MUI.FONT, 9)
        petName:AlignLeft(self.health)

        local petHappiness = Frame(PetFrameHappiness)
        petHappiness:ClearAllPoints()
        petHappiness:RightOf(self.health, 0, -3)

        local petDebuff = Frame(PetFrameDebuff1)
        petDebuff:ClearAllPoints()
        petDebuff:Below(self.mana, 3)
        petDebuff:AlignLeft(self.mana)

        -- Combat feedback text ("Miss"/"Dodge"/heal) centred on the pet portrait,
        -- above the combat glow
        self.hitTextFrame = Frame("Frame", self.frame, "MUI_PetHitTextFrame")
        self.hitTextFrame:Fill(self._portrait)
        self.hitTextFrame:SetFrameStrata("HIGH")
        self.hitTextFrame:SetFrameLevel(50)

        local petHit = FontString(PetHitIndicator)
        petHit:SetParent(self.hitTextFrame)
        petHit:SetDrawLayer("OVERLAY", 7)
        petHit:ClearAllPoints()
        petHit:CenterInParent()
    end;

    UpdateBars = function(self)
        if not UnitExists("pet") then return end
        self.health:SetMaxValue(UnitHealthMax("pet"))
        self.health:SetBarValue(UnitHealth("pet"))
        local maxMana = UnitPowerMax("pet")
        if maxMana > 0 then
            self.mana:Show()
            self.mana:SetMaxValue(maxMana)
            self.mana:SetBarValue(UnitPower("pet"))
            self.mana:SetFillColor(self.module:GetPowerColor("pet"))
        else
            self.mana:Hide()
        end
    end;

    UpdateCombatGlow = function(self, elapsed)
        if not UnitExists("pet") then
            self.combatGlowTex:SetAlpha(0)
            return
        end

        local petInCombat  = UnitAffectingCombat("pet")
        local petHasAggro  = UnitExists("pettarget") and UnitExists("pettargettarget")
                             and UnitIsUnit("pettargettarget", "pet")

        if petInCombat and petHasAggro then
            self.combatGlowTex:SetAlpha(1)
            self.combatPulseTime = 0
        elseif petInCombat then
            self.combatPulseTime = self.combatPulseTime + elapsed
            if self.combatPulseTime > self.combatPulseDuration then
                self.combatPulseTime = self.combatPulseTime - self.combatPulseDuration
            end
            local progress = self.combatPulseTime / self.combatPulseDuration
            self.combatGlowTex:SetAlpha(math.sin(progress * 3.14159))
        else
            local a = self.combatGlowTex:GetAlpha()
            if a > 0 then
                self.combatGlowTex:SetAlpha(math.max(0, a - elapsed * 2))
            end
            self.combatPulseTime = 0
        end
    end;
}
