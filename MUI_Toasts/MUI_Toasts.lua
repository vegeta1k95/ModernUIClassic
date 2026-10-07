-- MUI_Toasts: retail's top-of-screen toast banner (Blizzard_FrameXML/
-- EventToastManager, Mainline-only — Era has none). A 418x72 box with two
-- gold lines growing out of the centre along its top and bottom edges and a
-- dark gradient rising behind them; a toast's content fades in, holds and
-- fades out inside it, then the banner fades. Toasts queue up and play one
-- after another. Art is retail's levelup sheet; geometry and cadence are
-- retail's.
--
-- Toasts so far: the level-up ("You've Reached" / "Level N") in the banner,
-- and the achievement earned plate (MUI_AchievementToast), its own frame at
-- the bottom of the screen with its own queue.

local WIDTH, HEIGHT = 418, 72
local TOP_OFFSET    = 190
local SHADOW_ALPHA  = 0.6
local TEXT_GAP      = 5       -- between the two lines, and under "Level N"

-- Retail's cadence, except the lead-in: retail waits 1.8 s after the fade-in
-- for its own level-up flash, which felt like a stall here.
local FADE_IN      = 0.5
local START_DELAY  = 0.3      -- after the fade-in: lines, shadow and content start together
local LINE_GROW    = 0.5
local SHADOW_DELAY = 0.25     -- on top of START_DELAY
local SHADOW_GROW  = 3.15
local TEXT_FADE    = 0.5
local TEXT_HOLD    = 1.8
local FADE_OUT     = 0.5

-- Order-1 step holding the region invisible for `delay`, so it appears
-- exactly when its real animation begins.
local function AddHold(group, delay)
    local hold = group:CreateAnimation("Alpha")
    hold:SetFromAlpha(0)
    hold:SetToAlpha(0)
    hold:SetDuration(delay)
    hold:SetOrder(1)
end

-- Keeps the region at `alpha` through its order-2 animation and on from
-- there: the group never finishes on its own (a finishing group drops the
-- region to its base alpha 0 for a frame — a blink); _Reset stops it.
local HOLD_VISIBLE = 600
local function AddVisible(group, alpha, duration)
    local show = group:CreateAnimation("Alpha")
    show:SetFromAlpha(alpha)
    show:SetToAlpha(alpha)
    show:SetDuration(duration)
    show:SetOrder(2)
    local hold = group:CreateAnimation("Alpha")
    hold:SetFromAlpha(alpha)
    hold:SetToAlpha(alpha)
    hold:SetDuration(HOLD_VISIBLE)
    hold:SetOrder(3)
end

object "ModuleToasts" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Toasts")
    end;

    OnEnable = function(self)
        self._queue = {}
        self:_BuildBanner()
        self:_BuildLevelToast()
        self.achievementToast = AchievementToast(function(id) MUI_ModuleAchievements:Open(id) end)

        self.driver = Frame("Frame", nil, "MUI_ToastsDriver")
        self.driver:RegisterEventHandler("PLAYER_LEVEL_UP", function(_, _, level)
            self:Queue({ kind = "level", level = level })
        end)
        -- A loading screen cuts the banner; the toast plays again afterwards.
        self.driver:RegisterEventHandler("LOADING_SCREEN_ENABLED", function()
            if self._current then
                table.insert(self._queue, 1, self._current)
                self:_Reset()
            end
        end)
        self.driver:RegisterEventHandler("LOADING_SCREEN_DISABLED", function()
            self:_Next()
        end)

        ChatCommand("muitoast", function(_, msg)
            local kind, arg = string.match(msg or "", "^%s*(%S*)%s*(.-)%s*$")
            if kind == "" or kind == "levelup" then
                self:Queue({ kind = "level", level = tonumber(arg) or UnitLevel("player") })
            elseif kind == "achievement" then
                self:ShowAchievement({ name = arg ~= "" and arg or "Level 10", pts = 10,
                    icon = MUI.TEX_BASE .. "achievementicons\\236562" })
            end
        end)
    end;

    -- data = { id, name, pts, icon }: the "Achievement Earned!" plate.
    ShowAchievement = function(self, data)
        self.achievementToast:Present(data)
    end;

    -- ---- banner --------------------------------------------------------

    _BuildBanner = function(self)
        self.frame = Frame("Frame", nil, "MUI_ToastBanner")
        self.frame:SetSize(WIDTH, HEIGHT)
        self.frame:SetFrameStrata("HIGH")
        self.frame:AlignParentTop(TOP_OFFSET)
        self.frame:EnableMouse(true)
        self.frame:SetScript("OnMouseDown", function() self:_Dismiss() end)
        self.frame:SetAlpha(0)
        self.frame:Hide()

        local atlas = MUI_AtlasRegistry.LevelUp

        -- Lines and shadow sit at alpha 0 until their animations bring them in.
        self.shadow = Texture(self.frame, nil, "BACKGROUND")
        self.shadow:SetAtlas(atlas, "ShadowUpper")
        self.shadow:AlignParentBottom()
        self.shadow:SetAlpha(0)

        self.lineTop = Texture(self.frame, nil, "BACKGROUND")
        self.lineTop:SetDrawLayer("BACKGROUND", 2)
        self.lineTop:SetAtlas(atlas, "BarGold")
        self.lineTop:AlignParentTop()
        self.lineTop:SetAlpha(0)

        self.lineBottom = Texture(self.frame, nil, "BACKGROUND")
        self.lineBottom:SetDrawLayer("BACKGROUND", 2)
        self.lineBottom:SetAtlas(atlas, "BarGold")
        self.lineBottom:AlignParentBottom()
        self.lineBottom:SetAlpha(0)

        self.zoneText    = Frame(ZoneTextFrame)
        self.subZoneText = Frame(SubZoneTextFrame)

        self.fadeIn = AnimationGroup(self.frame)
        self.fadeIn:SetToFinalAlpha(true)
        local anim = self.fadeIn:CreateAnimation("Alpha")
        anim:SetFromAlpha(0)
        anim:SetToAlpha(1)
        anim:SetDuration(FADE_IN)

        self.fadeOut = AnimationGroup(self.frame)
        self.fadeOut:SetToFinalAlpha(true)
        anim = self.fadeOut:CreateAnimation("Alpha")
        anim:SetFromAlpha(1)
        anim:SetToAlpha(0)
        anim:SetDuration(FADE_OUT)
        self.fadeOut:SetScript("OnFinished", function()
            self:_Reset()
            self:_Next()
        end)

        -- The lines grow out of the centre.
        self.lineGrow = {}
        for i, line in ipairs({ self.lineTop, self.lineBottom }) do
            local group = AnimationGroup(line)
            AddHold(group, FADE_IN + START_DELAY)
            anim = group:CreateAnimation("Scale")
            anim:SetOrigin("CENTER", 0, 0)
            anim:SetScaleFrom(0.001, 1)
            anim:SetScaleTo(1, 1)
            anim:SetDuration(LINE_GROW)
            anim:SetOrder(2)
            AddVisible(group, 1, LINE_GROW)
            self.lineGrow[i] = group
        end

        -- The shadow rises from the bottom line.
        self.shadowGrow = AnimationGroup(self.shadow)
        AddHold(self.shadowGrow, FADE_IN + START_DELAY + SHADOW_DELAY)
        anim = self.shadowGrow:CreateAnimation("Scale")
        anim:SetOrigin("BOTTOM", 0, 0)
        anim:SetScaleFrom(1, 0.001)
        anim:SetScaleTo(1, 1)
        anim:SetDuration(SHADOW_GROW)
        anim:SetOrder(2)
        AddVisible(self.shadowGrow, SHADOW_ALPHA, SHADOW_GROW)
    end;

    -- A content frame's run: hidden through the delay, in, hold, out; the
    -- banner follows it out. Without SetToFinalAlpha a finished group puts
    -- the frame back at the alpha its last step started from (1): the text
    -- came back solid for the banner's fade.
    _ContentAnimation = function(self, content)
        local group = AnimationGroup(content)
        group:SetToFinalAlpha(true)
        AddHold(group, FADE_IN + START_DELAY)
        local anim = group:CreateAnimation("Alpha")
        anim:SetFromAlpha(0)
        anim:SetToAlpha(1)
        anim:SetDuration(TEXT_FADE)
        anim:SetOrder(2)
        anim = group:CreateAnimation("Alpha")
        anim:SetFromAlpha(1)
        anim:SetToAlpha(1)
        anim:SetDuration(TEXT_HOLD)
        anim:SetOrder(3)
        anim = group:CreateAnimation("Alpha")
        anim:SetFromAlpha(1)
        anim:SetToAlpha(0)
        anim:SetDuration(TEXT_FADE)
        anim:SetOrder(4)
        group:SetScript("OnFinished", function() self:_Dismiss() end)
        return group
    end;

    -- ---- the level-up toast --------------------------------------------

    _BuildLevelToast = function(self)
        local content = Frame("Frame", self.frame)
        content:FillParent()
        content:SetAlpha(0)

        local level = FontString(content, nil, "ARTWORK")
        level:SetFont(MUI.FONT, 32)
        level:SetShadowOffset(1, -1)
        level:SetTextColor(1, 0.82, 0)
        level:AlignParentBottom(TEXT_GAP)

        local reached = FontString(content, nil, "ARTWORK")
        reached:SetFont(MUI.FONT, 16)
        reached:SetShadowOffset(1, -1)
        reached:SetTextColor(1, 1, 1)
        reached:Above(level, TEXT_GAP)
        -- Retail's LEVEL_UP_YOU_REACHED; Era's string table may not carry it.
        reached:SetText("You've Reached")

        self.levelToast = { frame = content, level = level, anim = self:_ContentAnimation(content) }
    end;

    -- ---- queue ---------------------------------------------------------

    Queue = function(self, toast)
        table.insert(self._queue, toast)
        if not self._current then self:_Next() end
    end;

    _Next = function(self)
        if self._current or #self._queue == 0 then return end
        local toast = table.remove(self._queue, 1)
        self._current = toast

        self.levelToast.level:SetText(string.format(LEVEL_GAINED, toast.level))

        -- As retail: the banner outranks the zone text.
        self.zoneText:Hide()
        self.subZoneText:Hide()
        self.frame:Show()
        self.fadeIn:Play()
        for _, group in ipairs(self.lineGrow) do group:Play() end
        self.shadowGrow:Play()
        self.levelToast.anim:Play()
    end;

    -- Fade the banner out (end of the content, or a click). Still fading in
    -- means nothing is visible yet: drop it on the spot.
    _Dismiss = function(self)
        if not self._current or self.fadeOut:IsPlaying() then return end
        if self.fadeIn:IsPlaying() then
            self:_Reset()
            self:_Next()
            return
        end
        self.fadeOut:Play()
    end;

    -- Back to the empty, hidden banner.
    _Reset = function(self)
        self.fadeIn:Stop()
        self.fadeOut:Stop()
        for _, group in ipairs(self.lineGrow) do group:Stop() end
        self.shadowGrow:Stop()
        self.levelToast.anim:Stop()
        self.lineTop:SetAlpha(0)
        self.lineBottom:SetAlpha(0)
        self.shadow:SetAlpha(0)
        self.levelToast.frame:SetAlpha(0)
        self.frame:SetAlpha(0)
        self.frame:Hide()
        self._current = nil
    end;
}
