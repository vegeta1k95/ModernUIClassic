-- AnimatedBar: Status bar with smooth fill animation, pulse, and cutout effects
-- Usage:
--   local bar = AnimatedBar(parent, "MyBar", 130, 30)
--   bar:SetFillColor(0, 1, 0, 1)
--   bar:SetMaxValue(100)
--   bar:SetBarValue(75)

local ANIM_SPEED = 0.1
local PULSE_DURATION = 0.3
local PULSE_FADE_IN = 0.1
local PULSE_CURVE = 0.7
local PULSE_SCALE = 1.05
local CUTOUT_DURATION = 0.3
local CUTOUT_ALPHA = 1

-- Single ticker drives every AnimatedBar's animation state in one OnUpdate.
-- The three tables (animations / pulses / cutouts) live on the singleton, not
-- at file scope, so external code can introspect or pause via the singleton.
-- IMPORTANT: AnimatedBar calls this through `MUI_BarsAnimator:Method(...)` —
-- the instance auto-created by `object`. Calling `BarsAnimator:Method(...)`
-- on the class table passes the class as self and the data tables are nil.
object "BarsAnimator" {

    __init = function(self)
        self._animations = {}
        self._pulses = {}
        self._cutouts = {}

        self._ticker = Frame()
        self._ticker:SetScript("OnUpdate", function()
            local now = GetTime()

            -- Smooth fill animations
            for bar in pairs(self._animations) do
                if bar._animEnabled then
                    if bar._displayVal == bar._val then
                        self._animations[bar] = nil
                    else
                        bar._displayVal = bar._displayVal + (bar._val - bar._displayVal) * ANIM_SPEED
                    end
                    bar:_UpdateFill()
                else
                    self._animations[bar] = nil
                end
            end

            -- Pulse color animations
            for bar, endTime in pairs(self._pulses) do
                if bar._pulseEnabled then
                    if now >= endTime then
                        bar._fill:SetVertexColor(bar._baseColor[1], bar._baseColor[2], bar._baseColor[3], bar._baseColor[4])
                        bar:_UpdateFill()
                        self._pulses[bar] = nil
                    else
                        local timeLeft = endTime - now
                        local progress
                        if timeLeft > PULSE_DURATION * (1 - PULSE_FADE_IN) then
                            progress = 1 - ((timeLeft - PULSE_DURATION * (1 - PULSE_FADE_IN)) / (PULSE_DURATION * PULSE_FADE_IN))
                        else
                            progress = (timeLeft / (PULSE_DURATION * (1 - PULSE_FADE_IN))) ^ PULSE_CURVE
                        end
                        local r = bar._baseColor[1] + (bar._pulseColor[1] - bar._baseColor[1]) * progress
                        local g = bar._baseColor[2] + (bar._pulseColor[2] - bar._baseColor[2]) * progress
                        local b = bar._baseColor[3] + (bar._pulseColor[3] - bar._baseColor[3]) * progress
                        bar._fill:SetVertexColor(r, g, b, 1)
                    end
                else
                    self._pulses[bar] = nil
                end
            end

            -- Cutout fade animations
            for cutout, data in pairs(self._cutouts) do
                if now >= data.endTime then
                    cutout:SetTexture(nil)
                    cutout:Hide()
                    self._cutouts[cutout] = nil
                else
                    local progress = (data.endTime - now) / data.duration
                    cutout:SetAlpha(CUTOUT_ALPHA * progress)
                end
            end
        end)
    end;

    SetAnimation = function(self, bar, state)
        self._animations[bar] = state
    end;

    SetPulse = function(self, bar, state)
        self._pulses[bar] = state
    end;

    SetCutout = function(self, cutout, data)
        self._cutouts[cutout] = data
    end;
}

class "AnimatedBar" : extends "Frame" {
    __init = function(self, parent, name, width, height)
        Frame.__init(self, "Frame", parent, name)
        self:SetSize(width or 200, height or 20)

        -- Fill texture
        self._fill = Texture(self, nil, "ARTWORK")
        self._fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        self._fill:SetVertexColor(0, 0.9, 0.2, 1)
        self._fill:AlignParentTopLeft()

        -- State
        self._val = 0
        self._displayVal = 0
        self._maxVal = 1
        self._baseColor = {0, 0.9, 0.2, 1}
        self._pulseColor = {1, 1, 1, 1}
        self._cutoutColor = {0, 0.9, 0.2, 1}
        self._cutoutTexturePath = "Interface\\TargetingFrame\\UI-StatusBar"
        self._fillDir = "LEFT"
        self._cutoutSuppressedUntil = 0

        -- Feature flags
        self._animEnabled = true
        self._pulseEnabled = true
        self._cutoutEnabled = true
    end;

    _UpdateFill = function(self)
        local pct = self._displayVal / self._maxVal
        if pct <= 0.001 then pct = 0.001 end

        local w = self:GetWidth()
        local h = self:GetHeight()

        if self._fillDir == "RIGHT" then
            self._fill:SetTexCoord(1 - pct, 1, 0, 1)
        else
            self._fill:SetTexCoord(0, pct, 0, 1)
        end
        self._fill:SetSize(w * pct, h)
    end;

    SetBarValue = function(self, val, instant)
        if self._val == val then return end

        local now = GetTime()

        -- Cutout effect on health decrease
        if val < self._val and not instant and self._cutoutEnabled and now > self._cutoutSuppressedUntil then
            local oldPct = self._val / self._maxVal
            local newPct = val / self._maxVal
            local w = self:GetWidth()
            local h = self:GetHeight()
            local cutW = w * (oldPct - newPct)

            local cutout = Texture(self, nil, "ARTWORK")
            cutout:SetTexture(self._cutoutTexturePath)
            cutout:SetVertexColor(self._cutoutColor[1], self._cutoutColor[2], self._cutoutColor[3], CUTOUT_ALPHA)

            if self._fillDir == "RIGHT" then
                cutout:SetTexCoord(1 - oldPct, 1 - newPct, 0, 1)
                cutout:SetPoint("TOPLEFT", self, "TOPLEFT", w * (1 - oldPct), 0)
            else
                cutout:SetTexCoord(newPct, oldPct, 0, 1)
                cutout:SetPoint("TOPLEFT", self, "TOPLEFT", w * newPct, 0)
            end
            cutout:SetSize(math.min(cutW, w), h)

            MUI_BarsAnimator:SetCutout(cutout, { endTime = now + CUTOUT_DURATION, duration = CUTOUT_DURATION })
        end

        local useInstant = instant or (now <= self._cutoutSuppressedUntil)
        self._val = val

        if not useInstant and (self._animEnabled or self._pulseEnabled) then
            if self._animEnabled then
                MUI_BarsAnimator:SetAnimation(self, true)
            end
            if self._pulseEnabled then
                MUI_BarsAnimator:SetPulse(self, now + PULSE_DURATION)
            end
            if not self._animEnabled then
                self._displayVal = val
                self:_UpdateFill()
            end
        else
            MUI_BarsAnimator:SetPulse(self, nil)
            self._fill:SetVertexColor(self._baseColor[1], self._baseColor[2], self._baseColor[3], self._baseColor[4])
            self._displayVal = val
            self:_UpdateFill()
        end
    end;

    SetMaxValue = function(self, max)
        self._maxVal = max
        self:_UpdateFill()
    end;

    SetFillColor = function(self, r, g, b, a)
        self._baseColor = {r, g, b, a or 1}
        self._fill:SetVertexColor(r, g, b, a or 1)
    end;

    SetPulseColor = function(self, r, g, b, a)
        self._pulseColor = {r, g, b, a or 1}
    end;

    SetCutoutColor = function(self, r, g, b, a)
        self._cutoutColor = {r, g, b, a or 1}
    end;

    SetBgColor = function(self, r, g, b, a)
        self.bg:SetVertexColor(r, g, b, a or 0.5)
    end;

    SetFillTexture = function(self, path)
        self._fill:SetTexture(path)
        self._cutoutTexturePath = path
    end;

    SetBgTexture = function(self, path)
        self.bg:SetTexture(path)
    end;

    SetFillDirection = function(self, dir)
        self._fillDir = dir
        self._fill:ClearAllPoints()
        if dir == "RIGHT" then
            self._fill:AlignParentTopRight()
        else
            self._fill:AlignParentTopLeft()
        end
        self:_UpdateFill()
    end;

    SetAnimEnabled = function(self, enabled)
        self._animEnabled = enabled
        if not enabled then MUI_BarsAnimator:SetAnimation(self, nil) end
    end;

    SetPulseEnabled = function(self, enabled)
        self._pulseEnabled = enabled
        if not enabled then MUI_BarsAnimator:SetPulse(self, nil) end
    end;

    SetCutoutEnabled = function(self, enabled)
        self._cutoutEnabled = enabled
    end;

    SuppressCutout = function(self, duration)
        self._cutoutSuppressedUntil = GetTime() + (duration or 0.1)
    end;
}
