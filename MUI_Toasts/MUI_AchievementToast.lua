-- MUI_AchievementToast: retail's "Achievement Earned!" alert
-- (AchievementAlertFrameTemplate): a 300x101 plate at the bottom of the
-- screen, the icon on its ring to the left, the points shield to the right.
-- It fades in while a glow flares and a shine sweeps across, holds about
-- four seconds and fades out. A click opens the achievement in the panel.
-- Art is retail's alert sheet; the fanfare is retail's, shipped as a file
-- since Era's client lacks the kit.
--
-- Several at once, as retail's AchievementAlertSystem (a queued alert
-- subsystem, 2 shown and 6 waiting): two plates stack upward, nearly touching,
-- the next in line takes a slot as one goes, and anything beyond the
-- waiting six is dropped — a login sweep of a veteran's deeds shows eight
-- toasts, not eighty.

local WIDTH, HEIGHT  = 300, 101
local BOTTOM_OFFSET  = 200     -- retail's 128 sits on the bottom multibars here
-- Between stacked plates, frame edge to frame edge. The plate art stops
-- 6 px short of its frame's top and 7 of its bottom, so this leaves the
-- plates themselves about 7 px apart (retail's 10 between frames read as
-- 23 between plates).
local STACK_GAP      = -14
local MAX_SHOWN      = 2
local MAX_QUEUED     = 6
local FADE_IN        = 0.2
local HOLD           = 4.05
local FADE_OUT       = 1.5
local SOUND = "Interface\\AddOns\\ModernUI\\assets\\sounds\\achievement-earned.ogg"
local SOUND_GAP      = 1      -- one fanfare for toasts that land together

-- One plate, with its animations. `owner` is the AchievementToast managing
-- the stack; it hears OnDone when the plate has faded or been clicked.
class "AchievementToastPlate" : extends "Frame" {
    __init = function(self, owner)
        Frame.__init(self, "Frame", nil)
        self.owner = owner
        self:SetSize(WIDTH, HEIGHT)
        self:SetFrameStrata("DIALOG")
        self:EnableMouse(true)
        self:SetAlpha(0)
        self:Hide()

        local atlas = MUI_AtlasRegistry.AchievementAlert

        local bg = Texture(self, nil, "BACKGROUND")
        bg:SetAtlas(atlas, "Background")
        bg:CenterInParent()

        self.unlocked = FontString(self, nil, "BACKGROUND")
        self.unlocked:SetFont(MUI.FONT, 10)
        self.unlocked:SetTextColor(0, 0, 0, 1)
        self.unlocked:SetSize(200, 12)
        self.unlocked:AlignParentTop(23.5, 7)
        self.unlocked:SetText("Achievement Earned!")

        self.name = FontString(self, nil, "BACKGROUND")
        self.name:SetFont(MUI.FONT, 12)
        self.name:SetShadowOffset(1, -1)
        self.name:SetTextColor(1, 1, 1, 1)
        self.name:SetSize(155, 36)
        self.name:SetJustifyH("CENTER")
        self.name:SetJustifyV("MIDDLE")
        self.name:Below(self.unlocked)

        local iconFrame = Frame("Frame", self)
        iconFrame:SetSize(78, 75)
        iconFrame:AlignParentTopLeft(15, -4)
        self.icon = Texture(iconFrame, nil, "ARTWORK")
        self.icon:SetSize(52, 52)
        self.icon:CenterInParent()
        local ring = Texture(iconFrame, nil, "OVERLAY")
        ring:SetAtlas(atlas, "IconFrame")
        ring:CenterInParent(-1, 2)

        local shield = Frame("Frame", self)
        shield:SetSize(64, 64)
        shield:AlignParentTopRight(15, 8)
        local shieldTex = Texture(shield, nil, "BACKGROUND")
        shieldTex:SetAtlas(atlas, "Shield")
        shieldTex:AlignParentTopRight(6, -1)
        self.points = FontString(shield, nil, "OVERLAY")
        self.points:SetFont(MUI.FONT, 12)
        self.points:SetShadowOffset(1, -1)
        self.points:SetTextColor(1, 0.82, 0, 1)
        self.points:CenterInParent(1.5, -4)

        -- The glow flares and dies; the shine fades in and slides across.
        self.glow = Texture(self, nil, "OVERLAY")
        self.glow:SetAtlas(atlas, "Glow")
        self.glow:CenterInParent()
        self.glow:SetBlendMode("ADD")
        self.glow:SetAlpha(0)
        self.glowAnim = AnimationGroup(self.glow)
        self.glowAnim:SetToFinalAlpha(true)
        local anim = self.glowAnim:CreateAnimation("Alpha")
        anim:SetFromAlpha(0)
        anim:SetToAlpha(1)
        anim:SetDuration(0.2)
        anim:SetOrder(1)
        anim = self.glowAnim:CreateAnimation("Alpha")
        anim:SetFromAlpha(1)
        anim:SetToAlpha(0)
        anim:SetDuration(0.5)
        anim:SetOrder(2)

        self.shine = Texture(self, nil, "OVERLAY")
        self.shine:SetAtlas(atlas, "Shine")
        self.shine:AlignParentBottomLeft(8, 0)
        self.shine:SetBlendMode("ADD")
        self.shine:SetAlpha(0)
        self.shineAnim = AnimationGroup(self.shine)
        self.shineAnim:SetToFinalAlpha(true)
        anim = self.shineAnim:CreateAnimation("Alpha")
        anim:SetFromAlpha(0)
        anim:SetToAlpha(1)
        anim:SetDuration(0.2)
        anim:SetOrder(1)
        anim = self.shineAnim:CreateAnimation("Translation")
        anim:SetOffset(240, 0)
        anim:SetDuration(0.85)
        anim:SetOrder(2)
        anim = self.shineAnim:CreateAnimation("Alpha")
        anim:SetStartDelay(0.35)
        anim:SetFromAlpha(1)
        anim:SetToAlpha(0)
        anim:SetDuration(0.5)
        anim:SetOrder(2)

        self.fadeIn = AnimationGroup(self)
        self.fadeIn:SetToFinalAlpha(true)
        anim = self.fadeIn:CreateAnimation("Alpha")
        anim:SetFromAlpha(0)
        anim:SetToAlpha(1)
        anim:SetDuration(FADE_IN)

        self.fadeOut = AnimationGroup(self)
        self.fadeOut:SetToFinalAlpha(true)
        anim = self.fadeOut:CreateAnimation("Alpha")
        anim:SetStartDelay(HOLD)
        anim:SetFromAlpha(1)
        anim:SetToAlpha(0)
        anim:SetDuration(FADE_OUT)
        self.fadeOut:SetScript("OnFinished", function() self.owner:OnDone(self) end)

        self:SetScript("OnMouseUp", function(_, button)
            if button ~= "LeftButton" then return end
            self.owner:OnDone(self, self.id)
        end)
    end;

    -- data = { id, name, pts, icon }
    Present = function(self, data)
        self.id = data.id
        self.name:SetText(data.name or "")
        self.points:SetText(data.pts or "")
        self.icon:SetTexture(data.icon)
        self:Show()
        self.fadeIn:Play()
        self.glowAnim:Play()
        self.shineAnim:Play()
        self.fadeOut:Play()
    end;

    Clear = function(self)
        self.fadeIn:Stop()
        self.fadeOut:Stop()
        self.glowAnim:Stop()
        self.shineAnim:Stop()
        self.glow:SetAlpha(0)
        self.shine:SetAlpha(0)
        self:SetAlpha(0)
        self:Hide()
        self.id = nil
    end;
}

-- The stack: the plates showing, oldest at the bottom, and the line
-- waiting behind them.
class "AchievementToast" {
    -- onClick(achievementId) runs when a plate is clicked.
    __init = function(self, onClick)
        self.onClick = onClick
        self.plates = {}       -- every plate made, showing or spare
        self.active = {}       -- the plates showing, in order of arrival
        self.queue = {}
        self.lastSound = 0
    end;

    -- data = { id, name, pts, icon }: shown now, kept waiting, or dropped
    -- when six already wait (retail's AlertFrameQueueMixin:AddAlert).
    Present = function(self, data)
        if #self.active < MAX_SHOWN then
            self:_Show(data)
        elseif #self.queue < MAX_QUEUED then
            table.insert(self.queue, data)
        end
    end;

    _Show = function(self, data)
        local plate
        for _, p in ipairs(self.plates) do
            if not p:IsShown() then plate = p break end
        end
        if not plate then
            plate = AchievementToastPlate(self)
            table.insert(self.plates, plate)
        end
        table.insert(self.active, plate)
        self:_Layout()
        plate:Present(data)
        if GetTime() - self.lastSound >= SOUND_GAP then
            self.lastSound = GetTime()
            PlaySoundFile(SOUND, "SFX")
        end
    end;

    -- A plate faded out, or was clicked (`id` set): its slot goes to the
    -- next in line and the stack closes up.
    OnDone = function(self, plate, id)
        plate:Clear()
        for i, p in ipairs(self.active) do
            if p == plate then table.remove(self.active, i) break end
        end
        if #self.queue > 0 then
            self:_Show(table.remove(self.queue, 1))
        else
            self:_Layout()
        end
        if id then self.onClick(id) end
    end;

    -- The first plate at the bottom offset, each next one above the last.
    _Layout = function(self)
        for i, plate in ipairs(self.active) do
            plate:ClearAllPoints()
            if i == 1 then
                plate:AlignParentBottom(BOTTOM_OFFSET)
            else
                plate:Above(self.active[i - 1], STACK_GAP)
            end
        end
    end;
}
