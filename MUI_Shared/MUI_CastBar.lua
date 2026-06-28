-- CastBar: Retail-style casting bar wired to a specific unit.
--
-- Usage:
--   local bar = CastBar(parent, "MUI_PlayerCastBar", "player", 186, 9)
--   local tgt = CastBar(parent, "MUI_TargetCastBar", "target", 130, 8)
--
-- The widget self-registers UNIT_SPELLCAST_* for its unit plus PLAYER_TARGET_CHANGED
-- (target variant only) so the bar hides on untarget and resyncs if you acquire a
-- unit that's already mid-cast.

local ATLAS = MUI_AtlasRegistry.CastBar
local TEX = MUI.TEX_SKIN .. "castbar\\"

local FLASH_STEP = 0.2
local HOLD_TIME  = 1

-- Finish flipbook: 2 cols x 8 rows = 16 frames, 212x13 cells in 512x128 texture.
local FLIPBOOK_TEX      = TEX .. "castbar-flipbook"
local FLIPBOOK_COLS     = 2
local FLIPBOOK_FRAMES   = 16
local FLIPBOOK_DURATION = 0.6
local FLIPBOOK_CELL_U   = 212 / 512
local FLIPBOOK_CELL_V   = 13 / 128

class "CastBar" : extends "Frame" {
    __init = function(self, parent, name, unit, width, height)
        Frame.__init(self, "Frame", parent, name)
        self._unit      = unit or "player"
        self._barWidth  = width or 186
        self._barHeight = height or 9

        self:SetSize(self._barWidth + 4, self._barHeight + 4)
        self:Hide()

        self:_CreateVisuals()
        self:_InitState()
        self:_RegisterEvents()

        self:SetScript("OnUpdate", function(_, elapsed) self:_OnUpdate(elapsed) end)
    end;

    _CreateVisuals = function(self)
        local W, H = self._barWidth, self._barHeight

        -- Draw order (bottom → top): textbox, bg, fill/finishFlip, border, glow, trail, pip.
        -- All textures on `self` so draw-layer sublevels fully control z-order.

        self._textbox = Texture(self, nil, "BACKGROUND")
        self._textbox:SetDrawLayer("BACKGROUND", -1)
        self._textbox:SetAtlas(ATLAS, "Textbox", true)
        self._textbox:SetSize(W+2, 16)
        self._textbox:Below(self, -7)

        self._bg = Texture(self, nil, "BACKGROUND")
        self._bg:SetDrawLayer("BACKGROUND", 0)
        self._bg:SetAtlas(ATLAS, "Background", true)
        self._bg:SetSize(W + 2, H + 2)
        self._bg:CenterInParent()

        self._fill = Texture(self, nil, "BORDER")
        self._fill:SetDrawLayer("BORDER", 0)
        self._fill:SetAtlas(ATLAS, "FillingStandard", true)
        self._fill:AlignLeft(self._bg, 1)
        self._fill:SetHeight(H)
        -- Fill width + texcoord crop update every frame during a cast at
        -- fractional precision; disable pixel-grid snapping so the fill
        -- grows smoothly instead of jumping one pixel at a time.
        self._fill:SetSubpixelRendering(true)
        self._fillRegion = "FillingStandard"

        self._finishFlip = Texture(self, nil, "BORDER")
        self._finishFlip:SetDrawLayer("BORDER", 1)
        self._finishFlip:SetTexture(FLIPBOOK_TEX)
        self._finishFlip:SetSize(W, H + 2)
        self._finishFlip:SetPoint("LEFT", self._bg, "LEFT", 0, 0)
        self._finishFlip:Hide()

        self._border = Texture(self, nil, "ARTWORK")
        self._border:SetDrawLayer("ARTWORK", 0)
        self._border:SetAtlas(ATLAS, "Frame", true)
        self._border:SetSize(W + 4, H + 4)
        self._border:CenterInParent()

        self._flash = Texture(self, nil, "OVERLAY")
        self._flash:SetDrawLayer("OVERLAY", 0)
        self._flash:SetAtlas(ATLAS, "FullGlowStandard", true)
        self._flash:SetSize(W + 4, H + 4)
        self._flash:CenterInParent()
        self._flash:SetBlendMode("ADD")
        self._flash:SetAlpha(0)
        self._flash:Hide()
        self._flashRegion = "FullGlowStandard"

		self._spark = Texture(self, nil, "OVERLAY")
        self._spark:SetDrawLayer("OVERLAY", 1)
        self._spark:SetAtlas(ATLAS, "Pip")
        self._spark:SetSize(5 * 1.2, 30 * 0.6)
        self._spark:SetSubpixelRendering(true)
        self._spark:Hide()

        self._sparkTrail = Texture(self, nil, "OVERLAY")
        self._sparkTrail:SetDrawLayer("OVERLAY", 2)
        self._sparkTrail:SetTexture(TEX .. "castbar-trail")
        self._sparkTrail:SetSize(37, 14)
        self._sparkTrail:SetBlendMode("ADD")
        self._sparkTrail:SetSubpixelRendering(true)
        self._sparkTrail:Hide()

        self._shield = Texture(self, nil, "OVERLAY")
        self._shield:SetDrawLayer("OVERLAY", 3)
        self._shield:SetAtlas(ATLAS, "Shield")
        self._shield:AlignParentLeft(-20)
        self._shield:Hide()

        -- Spell icon on the left; off by default, toggle via SetIconEnabled(true).
        -- Sits just outside the bar's left edge. Default size roughly matches bar + textbox.
        self._icon = Texture(self, nil, "ARTWORK")
        self._icon:SetDrawLayer("ARTWORK", 1)
        self._icon:SetSize(H + 8)
		self._icon:AlignTop(self._bg, 1.5)
        self._icon:LeftOf(self._textbox, 3.5)
        self._icon:SetTexCoord(0, 1, 0, 1)  -- crop default icon borders
        self._icon:Hide()
        self._iconEnabled = false

        self._spellText = FontString(self, nil, "OVERLAY")
        self._spellText:SetFont(MUI.FONT, 9)
        self._spellText:SetTextColor(1, 1, 1, 1)
        self._spellText:SetShadowOffset(1, -1)
        self._spellText:AlignBottom(self._textbox)

        self.timeText = FontString(self, nil, "OVERLAY")
        self.timeText:SetFont(MUI.FONT, 9)
        self.timeText:SetTextColor(1, 1, 1, 1)
        self.timeText:SetShadowOffset(1, -1)
        self.timeText:AlignRight(self._textbox, 2)
        self.timeText:AlignBottom(self._textbox, 0)
    end;

    _InitState = function(self)
        self._casting      = nil
        self._channeling   = nil
        self._fadeOut      = nil
        self._flashState   = nil
        self._holdTime     = 0
        self._startTime    = 0
        self._maxValue     = 0
        self._endTime      = 0
        self._finishTime   = 0
        self._finishFrame  = -1
        self._finishing    = nil
    end;

    _RegisterEvents = function(self)
        self._events = Frame()
        local reg = {
            "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
            "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
            "UNIT_SPELLCAST_DELAYED",
            "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
        }
        local function dispatch(_, event, unit) self:_OnEvent(event, unit) end
        for _, e in ipairs(reg) do
            self._events:RegisterEventHandler(e, dispatch)
        end
        if self._unit == "target" then
            self._events:RegisterEventHandler("PLAYER_TARGET_CHANGED", dispatch)
        end
    end;

    SetIconEnabled = function(self, enabled)
        self._iconEnabled = enabled and true or false
        if not enabled then self._icon:Hide() end
    end;

    -- Edit-mode preview: paint a static, fully-filled bar (no spark/FX) so the
    -- bar's size and position are visible while it isn't actually casting. A real
    -- cast takes over normally (_StartCast/_StartChannel guard against overwrite).
    ShowPreview = function(self, text)
        if self._casting or self._channeling then return end
        self:_SetFillAtlas("FillingStandard")
        self:_SetProgress(1)
        self._spellText:SetText(text or "")
        self.timeText:SetText("")
        self._spark:Hide()
        self._sparkTrail:Hide()
        self._flash:Hide()
        self._finishFlip:Hide()
        self._shield:Hide()
        self:SetAlpha(1.0)
        self._previewing = true
        self:Show()
    end;

    HidePreview = function(self)
        if not self._previewing then return end
        self._previewing = nil
        if not (self._casting or self._channeling) then
            self:_HideFull()
        end
    end;

    _SetFillAtlas = function(self, regionName)
        if self._fillRegion == regionName then return end
        self._fillRegion = regionName
        self._fill:SetAtlas(ATLAS, regionName, true)
    end;

    _SetFlashAtlas = function(self, regionName)
        if self._flashRegion == regionName then return end
        self._flashRegion = regionName
        self._flash:SetAtlas(ATLAS, regionName, true)
    end;

    _SetProgress = function(self, progress)
        if progress < 0 then progress = 0 end
        if progress > 1 then progress = 1 end
        local w = progress * self._barWidth
        if w < 1 then w = 1 end
        self._fill:SetWidth(w)
        local info = ATLAS:GetRegion(self._fillRegion)
        local cropRight = info.left + (info.right - info.left) * progress
        self._fill:SetTexCoord(info.left, cropRight, info.top, info.bottom)
    end;

    _StartCast = function(self)
        local name, _, texture, startTime, endTime, isTradeSkill = UnitCastingInfo(self._unit)
        if not name then return false end
        self:_InitState()  -- reset BEFORE assigning, otherwise it would clobber our values
        self._isCraft = isTradeSkill and true or false
        self:_SetFillAtlas(self._isCraft and "FillingCraft" or "FillingStandard")
        self:_SetFlashAtlas(self._isCraft and "FullGlowCraft" or "FullGlowStandard")
        self:_SetProgress(0)
        self._spark:Show()
        self._sparkTrail:Show()
        self._startTime = startTime / 1000
        self._maxValue = endTime / 1000
        self._spellText:SetText(name)
        self.timeText:SetText("")
        self:SetAlpha(1.0)
        self._casting = true
        self._flash:Hide()
        self._finishFlip:Hide()
        self._shield:Hide()
        self:_UpdateIcon(texture)
        self:Show()
        return true
    end;

    _StartChannel = function(self)
        local name, _, texture, startTime, endTime = UnitChannelInfo(self._unit)
        if not name then return false end
        self:_InitState()
        self:_SetFillAtlas("FillingChannel")
        self:_SetProgress(1)
        self._spark:Show()
        self._sparkTrail:Show()
        self._startTime = startTime / 1000
        self._endTime = endTime / 1000
        self._spellText:SetText(name)
        self.timeText:SetText("")
        self:SetAlpha(1.0)
        self._channeling = true
        self._flash:Hide()
        self._finishFlip:Hide()
        self._shield:Hide()
        self:_UpdateIcon(texture)
        self:Show()
        return true
    end;

    _UpdateIcon = function(self, texture)
        if self._iconEnabled and texture then
            self._icon:SetTexture(texture)
            self._icon:Show()
        else
            self._icon:Hide()
        end
    end;

    _OnEvent = function(self, event, unit)
        if event == "PLAYER_TARGET_CHANGED" then
            if UnitExists(self._unit) then
                if not self:_StartCast() then
                    if not self:_StartChannel() then
                        self:_HideFull()
                    end
                end
            else
                self:_HideFull()
            end
            return
        end

        if unit ~= self._unit then return end

        if event == "UNIT_SPELLCAST_START" then
            self:_StartCast()

        elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
            self:_StartChannel()

        elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            if not self:IsShown() then return end
            self._spark:Hide()
            self._sparkTrail:Hide()
            self.timeText:SetText("")
            self._flash:SetAlpha(0)
            self._flash:Show()
            self._flashState = true
            self._fadeOut = true

            if event == "UNIT_SPELLCAST_STOP" then
                self:_SetProgress(1)
                self:_SetFillAtlas(self._isCraft and "FullCraft" or "FillingStandard")
                self._casting = nil
                -- The finish flipbook is keyed to the standard fill texture;
                -- showing it on craft completion flashes the standard look
                -- on top of FullCraft for one frame. Skip it for crafts —
                -- the FullGlowCraft flash already covers the completion FX.
                if self._isCraft then
                    self._finishFlip:Hide()
                    self._finishing = nil
                else
                    self._finishFlip:Show()
                    self._finishTime = 0
                    self._finishFrame = -1
                    self._finishing = true
                end
            else
                self._channeling = nil
                self._finishFlip:Hide()
                self._finishing = nil
            end

        elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
            if self:IsShown() and not self._channeling then
                self:_SetProgress(1)
                self:_SetFillAtlas("Interrupted")
                self._spark:Hide()
                self._sparkTrail:Hide()
                self._flash:Hide()
                self._finishFlip:Hide()
                self._finishing = nil
                self._spellText:SetText(event == "UNIT_SPELLCAST_FAILED" and FAILED or INTERRUPTED)
                self.timeText:SetText("")
                self:SetAlpha(1.0)
                self._casting = nil
                self._fadeOut = true
                self._flashState = nil
                self._holdTime = GetTime() + HOLD_TIME
            end

        elseif event == "UNIT_SPELLCAST_DELAYED" then
            if self:IsShown() then
                local name, _, _, startTime, endTime = UnitCastingInfo(self._unit)
                if name then
                    self._startTime = startTime / 1000
                    self._maxValue = endTime / 1000
                end
            end

        elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
            if self:IsShown() then
                local name, _, _, startTime, endTime = UnitChannelInfo(self._unit)
                if name then
                    self._startTime = startTime / 1000
                    self._endTime = endTime / 1000
                end
            end
        end
    end;

    _HideFull = function(self)
        self:Hide()
        self:_InitState()
        self._flash:Hide()
        self._finishFlip:Hide()
        self._spark:Hide()
        self._sparkTrail:Hide()
        self:SetAlpha(1.0)
    end;

    _OnUpdate = function(self, elapsed)
        if self._casting then
            local now = GetTime()
            if now > self._maxValue then now = self._maxValue end
            self._flash:Hide()

            local progress = (now - self._startTime) / (self._maxValue - self._startTime)
            self:_SetProgress(progress)
            self:_UpdateSparkPosition(progress * self._barWidth - 1)

            local remaining = self._maxValue - now
            if remaining > 0 then
                self.timeText:SetText(string.format("%.1f", remaining))
            end

        elseif self._channeling then
            local now = GetTime()
            if now > self._endTime then now = self._endTime end
            if now == self._endTime then
                self._channeling = nil
                self._fadeOut = true
                return
            end
            self._flash:Hide()

            local progress = (self._endTime - now) / (self._endTime - self._startTime)
            self:_SetProgress(progress)
            self:_UpdateSparkPosition(progress * self._barWidth)

            local remaining = self._endTime - now
            if remaining > 0 then
                self.timeText:SetText(string.format("%.1f", remaining))
            end

        elseif GetTime() < self._holdTime then
            return

        elseif self._flashState then
            local alpha = self._flash:GetAlpha() + FLASH_STEP
            if alpha < 1 then
                self._flash:SetAlpha(alpha)
            else
                self._flash:SetAlpha(1.0)
                self._flashState = nil
            end
            if self._finishing then self:_UpdateFinishFlipbook(elapsed) end

        elseif self._fadeOut then
            local alpha = self:GetAlpha() - elapsed / FLIPBOOK_DURATION
            if alpha > 0 then
                self:SetAlpha(alpha)
            else
                self._fadeOut = nil
                self._finishing = nil
                self._finishFlip:Hide()
                self:Hide()
            end
            if self._finishing then self:_UpdateFinishFlipbook(elapsed) end
        end
    end;

    _UpdateSparkPosition = function(self, sparkX)
        self._spark:ClearAllPoints()
        self._spark:SetPoint("CENTER", self._bg, "LEFT", sparkX+0.5, 0)
        self._sparkTrail:ClearAllPoints()
        self._sparkTrail:SetPoint("RIGHT", self._spark, "LEFT", 2, 0)
        local maxW = 37
        local available = math.max(0, sparkX)
        if available >= maxW then
            self._sparkTrail:SetWidth(maxW)
            self._sparkTrail:SetTexCoord(0, 1, 0, 1)
        elseif available > 0 then
            self._sparkTrail:SetWidth(available)
            local frac = available / maxW
            self._sparkTrail:SetTexCoord(1 - frac, 1, 0, 1)
        else
            self._sparkTrail:SetWidth(1)
            self._sparkTrail:SetTexCoord(1, 1, 0, 1)
        end

        -- Fade spark + trail as the pip approaches the rounded pill caps, so they don't
        -- render outside the curve (no true shape-masking available in Classic Era).
        local EDGE_FADE_START = 48
        local EDGE_FADE_END   = 6
        local edgeAlpha = 1
        if sparkX < EDGE_FADE_START then
            edgeAlpha = math.max(0, sparkX / EDGE_FADE_START)
        elseif sparkX > (self._barWidth - EDGE_FADE_END) then
            edgeAlpha = math.max(0, (self._barWidth - sparkX) / EDGE_FADE_END)
        end
        self._spark:SetAlpha(edgeAlpha)
        self._sparkTrail:SetAlpha(edgeAlpha)
    end;

    _UpdateFinishFlipbook = function(self, elapsed)
        self._finishTime = self._finishTime + elapsed
        if self._finishTime >= FLIPBOOK_DURATION then
            self._finishing = nil
            self._finishFlip:Hide()
            return
        end
        local fi = math.floor(self._finishTime / FLIPBOOK_DURATION * FLIPBOOK_FRAMES)
        if fi > FLIPBOOK_FRAMES - 1 then fi = FLIPBOOK_FRAMES - 1 end
        if fi ~= self._finishFrame then
            self._finishFrame = fi
            local col = mod(fi, FLIPBOOK_COLS)
            local row = math.floor(fi / FLIPBOOK_COLS)
            local u = col * FLIPBOOK_CELL_U
            local v = row * FLIPBOOK_CELL_V
            self._finishFlip:SetTexCoord(u, u + FLIPBOOK_CELL_U, v, v + FLIPBOOK_CELL_V)
        end
    end;
}
