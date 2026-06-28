-- UnitFrameTargetOfTarget: skins TargetFrameToT (created dynamically by
-- Blizzard when a target's target exists). Owns the ToT health/mana
-- bars + dead text.
--
-- TargetofTarget_Update is the engine's ToT-refresh entry point and we
-- hook it for value updates. The frame anchor lives here because it
-- only needs to land relative to the parent target frame.

local TEX = MUI.TEX_SKIN .. "unitframes\\"

class "UnitFrameTargetOfTarget" {
    __init = function(self, module, targetFrameWidget)
        self.module = module

        if not TargetFrameToT then return end

        Frame(TargetFrameToTHealthBar):HideFrame()
        Frame(TargetFrameToTManaBar):HideFrame()
        Frame(TargetFrameToTBackground):HideFrame()
        Texture(TargetFrameToTTextureFrameTexture):Hide()

        self.frame = UnitFrameEditable(TargetFrameToT, "ToT")
        self.frame:ClearAllPoints()
        self.frame:SetSize(103, 41)
        self.frame:Below(targetFrameWidget, 5)
        self.frame:AlignRight(targetFrameWidget, -54)
        self.frame:EditModeSetDefaultPosition(function(f)
            f:ClearAllPoints()
            f:Below(targetFrameWidget, 5)
            f:AlignRight(targetFrameWidget, -24)
        end)

        self._frameTex = Texture(self.frame)
        self._frameTex:SetTextureRegion(TEX .. "tot-frame", 256, 128, 12, 16, 230, 90)
        self._frameTex:FillParent()
        self._frameTex:SetDrawLayer("ARTWORK")

        local totName = FontString(TargetFrameToTTextureFrameName)
        totName:SetWidth(54)
        totName:SetJustifyH("LEFT")
        totName:SetFont(MUI.FONT, 9)
        totName:ClearAllPoints()
        totName:AlignParentTopLeft(3, 40)

        local totPortrait = Texture(TargetFrameToTPortrait)
        totPortrait:ClearAllPoints()
        totPortrait:AlignTop(self.frame, 6)
        totPortrait:AlignLeft(self.frame, 5)
        totPortrait:SetSize(32)

        self.health = AnimatedBar(self.frame, "MUI_ToTHealth", 64, 13)
        self.health:RightOf(totPortrait, 0, 2.5)
        self.health:SetFillTexture(TEX .. "player-health")
        self.health:SetFillColor(0.5, 1.0, 0.13, 1)

        self.mana = AnimatedBar(self.frame, "MUI_ToTMana", 64, 7)
        self.mana:Below(self.health, -1.5)
        self.mana:AlignLeft(self.health)
        self.mana:SetFillTexture(TEX .. "player-resource")

        local totDead = FontString(TargetFrameToTTextureFrameDeadText)
        totDead:SetFont(MUI.FONT, 8)
        totDead:SetParent(self.health)
        totDead:ClearAllPoints()
        totDead:CenterInParent()

        hooksecurefunc("TargetofTarget_Update", function() self:UpdateBars() end)
    end;

    UpdateBars = function(self)
        if not TargetFrameToT then return end
        if not UnitExists("targettarget") then return end
        self.health:SetMaxValue(UnitHealthMax("targettarget"))
        self.health:SetBarValue(UnitHealth("targettarget"))
        local maxMana = UnitPowerMax("targettarget")
        if maxMana > 0 then
            self.mana:Show()
            self.mana:SetMaxValue(maxMana)
            self.mana:SetBarValue(UnitPower("targettarget"))
            self.mana:SetFillColor(self.module:GetPowerColor("targettarget"))
        else
            self.mana:Hide()
        end
    end;
}
