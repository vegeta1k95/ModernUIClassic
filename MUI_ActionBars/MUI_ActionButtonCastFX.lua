-- ActionButtonCastFX: retail's cast animation on an action button. Era ships
-- it (ActionButtonSpellFXTemplate and its mixins in Blizzard_ActionBar), but
-- its button template switches it off (enableSpellFX = false) and leaves the
-- frames out, and turning it on would mean writing fields on secure buttons.
-- So this is the same animation on frames of ours over the button, played
-- from the button's own spellcast events (ModuleActionBars._OnCastEvent):
-- while a spell with a cast time is cast, a band of light crosses the icon
-- over the cast time (green, from the other side, for a channel) and ends in
-- a burst; an interrupted one just goes (retail's red interrupt frame is left
-- out). The cooldown swipe is hidden meanwhile, as on retail. The art ships
-- in assets/textures/skin/actionbars: Era's UI never draws its sheet.
--
-- Construction:
--   ActionButtonCastFX(nativeButton)
--
-- API:
--   :PlayCast(castType)         "cast" / "channel" of the button's spell began
--   :StopCast(force, castType)  it ended: the burst, or (force) nothing more
--   :Interrupt()                it was interrupted: nothing more

local TEX   = MUI.TEX_SKIN .. "actionbars\\"
local SHEET = TEX .. "cast-fx"

-- Retail's UI-HUD-ActionBar-* cells in our sheet: left, top, width, height.
local CAST_GLOW    = { 97, 1, 43, 43 }
local CHANNEL_GLOW = { 143, 1, 43, 43 }
local BURST_RING   = { 1, 1, 93, 93 }

-- Retail's sizes and offsets are for its 45 px buttons.
local RETAIL_BUTTON_SIZE = 45

-- The band (Cast-Fill / Channel-Fill) is alone at the top left of its own
-- file, so that past its edges there is nothing. Retail starts it 45 off the
-- icon's centre and moves it 43 across; here it is the band's texture that
-- moves, through a window as wide as the icon mask.
local BAND_FILE = 64
local BAND_WIDTH, BAND_HEIGHT = 49, 46
local BAND_WINDOW = 64
local BAND_START, BAND_TRAVEL = 45, 43

-- The cooldown swipe's colour on Era's action buttons.
local SWIPE_ALPHA = 0.8

local function SetCell(texture, cell)
    texture:SetTextureRegion(SHEET, 256, 128, cell[1], cell[2], cell[3], cell[4])
end

class "ActionButtonCastFX" : extends "Frame" {
    __init = function(self, native)
        local button = Button(native)
        Frame.__init(self, "Frame", button)
        self:SetSize(128, 128)
        self:CenterInParent()
        self:SetScale(button:GetWidth() / RETAIL_BUTTON_SIZE)
        self:Hide()
        self._cooldown = Cooldown(native.cooldown)
        self._castType = nil

        -- A glow inside the icon's frame, and a band that crosses the icon,
        -- clipped to it.
        self._glow = Texture(self, nil, "ARTWORK")
        self._glow:SetSize(43, 43)
        self._glow:CenterInParent()

        -- The band's quad stays put and its texture slides (_Slide): moved
        -- itself, it crept a fraction of a pixel a frame and stepped.
        self._band = Texture(self, nil, "ARTWORK")
        self._band:SetSize(BAND_WINDOW, BAND_HEIGHT)
        self._band:CenterInParent()
        self._band:SetBlendMode("ADD")
        local iconMask = MaskTexture(self, TEX .. "cast-fx-icon-mask")
        iconMask:SetSize(64, 64)
        iconMask:CenterInParent()
        self._band:AddMask(iconMask)

        -- The burst: a ring that grows out over the icon's edge.
        self._ring = Texture(self, nil, "ARTWORK")
        SetCell(self._ring, BURST_RING)
        self._ring:SetSize(93 * 0.25, 93 * 0.25)
        self._ring:CenterInParent()
        self._ring:SetBlendMode("ADD")
        self._ring:Hide()
        local ringMask = MaskTexture(self, TEX .. "cast-fx-burst-mask")
        ringMask:SetSize(64, 64)
        ringMask:CenterInParent()
        self._ring:AddMask(ringMask)

        -- Retail's CastingAnim, as a clock: the cast time, then (if no end
        -- came first) band and glow fade.
        self._casting = AnimationGroup(self)
        self._sweep = self._casting:CreateAnimation("Animation")
        self._sweep:SetOrder(1)
        self._sweep:SetEndDelay(0.5)
        for _, texture in ipairs({ self._band, self._glow }) do
            local fade = self._casting:CreateAnimation("Alpha")
            fade:SetTarget(texture)
            fade:SetOrder(2)
            fade:SetDuration(0.25)
            fade:SetSmoothing("OUT")
            fade:SetFromAlpha(1)
            fade:SetToAlpha(0)
        end
        self._casting:SetScript("OnFinished", function() self:_Burst() end)

        self._burst = AnimationGroup(self)
        local grow = self._burst:CreateAnimation("Scale")
        grow:SetTarget(self._ring)
        grow:SetDuration(0.5)
        grow:SetSmoothing("OUT")
        grow:SetScaleFrom(0, 0)
        grow:SetScaleTo(5, 5)
        self._burst:SetScript("OnFinished", function() self:Hide() end)

        self:SetScript("OnUpdate", function() self:_Slide() end)
        self:SetScript("OnHide", function()
            self._cooldown:SetSwipeColor(0, 0, 0, SWIPE_ALPHA)
        end)
    end;

    -- A cast ("cast") or channel ("channel") of the button's spell began: the
    -- band crosses in the time it takes.
    PlayCast = function(self, castType)
        local channel = castType == "channel"
        local startTime, endTime
        if channel then
            startTime, endTime = select(4, UnitChannelInfo("player"))
        else
            startTime, endTime = select(4, UnitCastingInfo("player"))
        end

        self._cooldown:SetSwipeColor(0, 0, 0, 0)
        self._ring:Hide()
        self._glow:Show()
        self._band:Show()
        self._casting:Stop()
        self._burst:Stop()

        -- A cast's band starts left of the icon and moves right, a channel's
        -- the other way: in band file widths, where the window's left edge
        -- falls in it at the start, and how far that goes.
        local centre = channel and BAND_START or -BAND_START
        self._bandFrom = (-BAND_WINDOW / 2 - (centre - BAND_WIDTH / 2)) / BAND_FILE
        self._bandTravel = (channel and BAND_TRAVEL or -BAND_TRAVEL) / BAND_FILE
        self._band:SetTexture(TEX .. (channel and "cast-fx-fill-channel" or "cast-fx-fill-cast"),
                              "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        SetCell(self._glow, channel and CHANNEL_GLOW or CAST_GLOW)

        self._castStart = (startTime or GetTime() * 1000) / 1000
        self._castLength = startTime and endTime and (endTime - startTime) / 1000 or 0
        self._sweep:SetDuration(self._castLength)
        self:_Slide()
        self._casting:Play()
        self:Show()
        self._castType = castType
    end;

    -- The cast of that type ended. Completed, the band is cut short for the
    -- burst; `force` (stopped) takes it all away.
    StopCast = function(self, force, castType)
        if self._castType ~= castType then return end
        if force then
            self._casting:Stop()
            self._burst:Stop()
            self:Hide()
        elseif self._casting:IsPlaying() then
            self._casting:Stop()
            self:_Burst()
        end
        self._castType = nil
    end;

    -- Retail's PlaySpellInterruptedAnim, without the red frame it shows next.
    Interrupt = function(self)
        self:StopCast(true, self._castType)
    end;

    -- The band where the cast is now, by the clock the cast bar goes by.
    _Slide = function(self)
        if not self._band:IsShown() then return end
        local progress = 1
        if self._castLength > 0 then
            progress = math.min(math.max((GetTime() - self._castStart) / self._castLength, 0), 1)
        end
        local left = self._bandFrom + progress * self._bandTravel
        self._band:SetTexCoord(left, left + BAND_WINDOW / BAND_FILE, 0, BAND_HEIGHT / BAND_FILE)
    end;

    -- The ring flashes in place of the band and glow, which would otherwise
    -- stay up until the burst ends.
    _Burst = function(self)
        self._band:Hide()
        self._glow:Hide()
        self._ring:Show()
        self._burst:Play()
    end;
}
