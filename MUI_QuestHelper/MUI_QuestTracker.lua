-- QuestTracker: retail-style on-screen tracker. Three-level hierarchy:
--
--   Primary header "All Objectives"  [▼]   ← whole-tracker collapse
--     ├── Category "Quests"           [▼]   ← per-category collapse
--     │     (!) Quest Title
--     │         - Kill 10 Kobolds: 3/10     ← white dash = in-progress
--     │         ✔ Speak with NPC             ← check atlas = finished
--     │     (!) Quest Title 2
--     │         Can Turn In.                 ← grey line replaces
--     │                                        objectives when
--     │                                        entry.isComplete
--     ├── Category "Achievements"     [▼]   ← achievements ticked "Track"
--     │     Achievement Name
--     │         - 12/50 Quests completed      ← unfinished criteria
--     └── Category "Profession"       [▼]   ← recipes ticked "Track Recipe"
--           Recipe Name
--               - 3/5 Linen Cloth              ← reagents, from the bags
--
-- Retail conventions respected:
--   * Only categories have expander buttons, not individual quests.
--   * Quest rows have no background; title is golden, objectives are
--     white — both slightly dimmed when the block isn't hovered.
--   * Objective bullet is a text "-" by default, swapped to the
--     TrackerCheck / ObjectiveFail atlas when the objective's state
--     flips.
--   * POI button super-tracks on click (see QuestPoiButton).
--
-- Animations (polish, matches Blizzard_ObjectiveTrackerAnimTemplates):
--   * Quest-row shine sweep on new-quest accept.
--   * Scale-pulse + glow halo on objective-finish transition.

local WIDTH               = 250.5
local OUTER_PAD           = 6
local CATEGORY_GAP        = 0      -- primary header bottom → first category
local HEADER_QUEST_PAD    = -2.5      -- category header bottom → first quest
local QUEST_GAP           = -4      -- between consecutive quests
local OBJECTIVE_GAP       = 2      -- between objective rows inside a quest

local PRIMARY_H           = 36
local SECONDARY_H         = 27
local SECONDARY_BTN       = 14

local TITLE_H             = 20
local OBJECTIVE_H         = 12
local BULLET_W            = 6
local BULLET_ICON_SIZE    = 14

-- Quest item button at a block's right edge, centred on the block's text
-- (retail's QuestObjectiveItemButtonTemplate is 26 px at the block's top
-- right; rightEdgeFrameSpacing 2).
local ITEM_BTN_SIZE       = 22
local ITEM_BTN_GAP        = 2

-- An achievement block lists this many unfinished criteria, then "..."
-- (retail's MAX_CRITERIA_PER_ACHIEVEMENT).
local MAX_ACHIEVEMENT_CRITERIA = 5

-- specialFlags bit 0 = repeatable (Questie's QuestieDB.IsRepeatable).
local function _isRepeatable(questId)
    if not MUI_QuestDB then return false end
    local q = MUI_QuestDB:Get(questId)
    if not q then return false end
    local f = q.specialFlags
    return f and (f % 2) >= 1 or false
end

local _DIFF_RED    = { 1.00, 0.10, 0.10 }
local _DIFF_ORANGE = { 1.00, 0.50, 0.25 }
local _DIFF_YELLOW = { 1.00, 1.00, 0.00 }
local _DIFF_GREEN  = { 0.25, 0.75, 0.25 }
local _DIFF_GRAY   = { 0.62, 0.62, 0.62 }
local _GOLD        = { 1.00, 0.82, 0.00 }

local function _difficultyColor(level)

    if level == nil then
        return _GOLD[1], _GOLD[2], _GOLD[3]
    end

    local diffOn = MUI_DB and MUI_DB.settings and MUI_DB.settings.questHelper
                   and MUI_DB.settings.questHelper.showQuestDifficultyColor

    if not diffOn then 
        return _GOLD[1], _GOLD[2], _GOLD[3]
    end

    local playerLevel = UnitLevel("player")
    local diff = level - playerLevel
    local color = _GOLD
    if     diff >=  5                                   then color = _DIFF_RED
    elseif diff >=  3                                   then color = _DIFF_ORANGE
    elseif diff >= -2                                   then color = _DIFF_YELLOW
    elseif -diff <= (GetQuestGreenRange("player") or 5) then color = _DIFF_GREEN
    else                                                     color = _DIFF_GRAY
    end

    return color[1], color[2], color[3]

end


-- ---------------------------------------------------------------------
-- QuestTrackerCollapseBtn: two-state arrow (collapse ↔ expand) backed
-- by QuestTracker atlas regions. `variant` chooses the size family:
--   "primary"    → Primary{Collapse,CollapsePressed,Expand,ExpandPressed}
--                   + HighlightRed
--   "secondary"  → Secondary{Collapse,CollapsePressed,Expand,ExpandPressed}
--                   + HighlightYellow
-- ---------------------------------------------------------------------
class "QuestTrackerCollapseBtn" : extends "Frame" {
    __init = function(self, parent, name, variant, size)
        Frame.__init(self, "Frame", parent, name)
        self:SetSize(size, size)
        self:EnableMouse(true)
        self._variant  = variant
        self._expanded = true
        self._pressed  = false

        self.icon = Texture(self, nil, "ARTWORK")
        self.icon:SetAllPoints(self)

        self.highlight = Texture(self, nil, "HIGHLIGHT")
        self.highlight:SetAllPoints(self)
        self.highlight:SetAtlas(MUI_AtlasRegistry.QuestTracker,
            variant == "primary" and "HighlightRed" or "HighlightYellow", true)
        self.highlight:SetBlendMode("ADD")

        self:SetScript("OnMouseDown", function()
            self._pressed = true
            self:_Refresh()
        end)
        self:SetScript("OnMouseUp", function()
            local was = self._pressed
            self._pressed = false
            self:_Refresh()
            if was and MouseIsOver(self._native) and self.OnClick then
                -- Expand vs collapse click sounds mirror the checkbox
                -- on/off pair used elsewhere in MUI.
                PlaySound(self._expanded
                    and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
                    or  SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                self:OnClick()
            end
        end)

        self:_Refresh()
    end;

    SetExpanded = function(self, expanded)
        expanded = expanded and true or false
        if self._expanded == expanded then return end
        self._expanded = expanded
        self:_Refresh()
    end;

    IsExpanded = function(self) return self._expanded end;

    _Refresh = function(self)
        local prefix = (self._variant == "primary") and "Primary" or "Secondary"
        local state  = self._expanded and "Collapse" or "Expand"
        local region = prefix .. state .. (self._pressed and "Pressed" or "")
        self.icon:SetAtlas(MUI_AtlasRegistry.QuestTracker, region, true)
    end;
}


-- ---------------------------------------------------------------------
-- QuestPoiButton: layered POI widget.
--   outerGlow BACKGROUND  — halo (2× ring size)
--   ring      ARTWORK     — Bg / BgFocused / BgPressed /
--                            BgFocusedPressed / TurnIn (when complete)
--   dots      OVERLAY     — DotsYellow / DotsBrown, hidden on complete;
--                            a quest type glyph instead after SetGlyph
--   innerGlow HIGHLIGHT   — auto-shown on mouseover
-- Recurring quests swap to QuestPoiRecurring atlas family.
-- ---------------------------------------------------------------------
-- Quest type glyphs (SetGlyph): atlas region and size as a fraction of
-- the button. `underlay` is a region drawn behind the ring (the elite
-- dragon, as around retail's elite quest POIs), so the ring keeps showing
-- the focused / pressed state. A glyph that covers the whole disc hides its
-- gold, so a `focusRing` glyph gets a gold ring drawn around it while focused.
local POI_GLYPHS = {
    elite   = { region = "Boss",    scale = 0.5, underlay = "Dragon" },
    dungeon = { region = "SwirlDungeon", scale = 0.6, focusRing = true },
    kill    = { region = "Kill",    scale = 0.55 },
    loot    = { region = "Loot",    scale = 0.55 },
    pvp     = { region = "TagPvP",  scale = 0.72 },
    raid    = { region = "SwirlRaid", scale = 0.6, focusRing = true },
}

class "QuestPoiButton" : extends "Frame" {
    __init = function(self, parent, name, size)
        Frame.__init(self, "Frame", parent, name)

        self:SetSize(size or 29)
        self:EnableMouse(true)

        -- All pulse-target textures are CENTER-anchored + sized — the
        -- accept-pulse scales them by mutating SetSize (grows around
        -- the centre). SetAllPoints would lock them to the POI frame's
        -- rect and no SetSize change would register; texture-level
        -- SetScale is a no-op in WoW.
        self.outerGlow = Texture(self, nil, "BACKGROUND")
        self.outerGlow:SetSize(self:GetWidth()*2, self:GetHeight()*2)
		self.outerGlow:SetSubpixelRendering(true)
        self.outerGlow:ClearAllPoints()
        self.outerGlow:CenterInParent()

        self.underlay = Texture(self, nil, "BORDER")
        self.underlay:SetSize(self:GetWidth(), self:GetHeight())
		self.underlay:SetSubpixelRendering(true)
        self.underlay:ClearAllPoints()
        self.underlay:CenterInParent()
        self.underlay:Hide()

        self.ring = Texture(self, nil, "ARTWORK")
        self.ring:SetSize(self:GetWidth(), self:GetHeight())
		self.ring:SetSubpixelRendering(true)
        self.ring:ClearAllPoints()
        self.ring:CenterInParent()
        
        self.dots = Texture(self, nil, "OVERLAY")
        self.dots:SetSize(self:GetWidth(), self:GetHeight())
		self.dots:SetSubpixelRendering(true)
        self.dots:ClearAllPoints()
        self.dots:CenterInParent()

        -- Gold frame over a disc-covering glyph while focused (see POI_GLYPHS).
        self.focusRing = Texture(self, nil, "OVERLAY")
        self.focusRing:SetDrawLayer("OVERLAY", 1)
        self.focusRing:SetAtlas(MUI_AtlasRegistry.QuestPoiGlyphs, "FocusRing", true)
		self.focusRing:SetSubpixelRendering(true)
        self.focusRing:SetAllPoints(self.ring)
        self.focusRing:SetVertexColor(0.82, 0.82, 0.82, 1)
        self.focusRing:Hide()

        -- innerGlow doesn't pulse (it's the hover highlight); stays
        -- pinned to the POI rect so it matches the button bounds.
        self.innerGlow = Texture(self, nil, "OVERLAY")
        self.innerGlow:SetAllPoints(self.ring)
		self.innerGlow:SetSubpixelRendering(true)
        self.innerGlow:Hide()

        self._recurring = false
        self._focused   = false
        self._pressed   = false
        self._complete  = false
        self._legendGlow = false
        self._dotScale  = 1

        self:SetScript("OnMouseDown", function()
            self:_SetPressed(true) end)
        self:SetScript("OnMouseUp", function()
            local was = self._pressed
            self:_SetPressed(false)
            if was and self:IsMouseOver() and self.OnClick then
                -- Focus-toggle click sound. Matches the checkbox
                -- convention — ON when entering focus, OFF when
                -- clearing it.
                PlaySound(self._focused
                    and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
                    or  SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                self:OnClick()
            end
        end)

        self:SetScript("OnEnter", function()
            self.innerGlow:Show()
        end)
        self:SetScript("OnLeave", function()
            self.innerGlow:Hide()
        end)

        self:_Refresh()
    end;

    SetSize = function(self, w, h)
        Frame.SetSize(self, w, h)
        self:_Resize()
    end;

    _Resize = function(self)
        if self.outerGlow then self.outerGlow:SetSize(self:GetWidth()*2, self:GetHeight()*2) end
        if self.ring then self.ring:SetSize(self:GetWidth(), self:GetHeight()) end
        if self.underlay then self.underlay:SetSize(self:GetWidth(), self:GetHeight()) end
        if self.dots then self.dots:SetSize(self:GetWidth() * self._dotScale, self:GetHeight() * self._dotScale) end
    end;

    -- Quest type glyph shown in place of the in-progress dots: "elite",
    -- "dungeon", "kill", "loot", "pvp", "raid"; nil for the plain dots.
    SetGlyph = function(self, glyph)
        if self._glyph == glyph then return end
        self._glyph = glyph
        self:_Refresh()
    end;

    SetRecurring = function(self, rec)
        rec = rec and true or false
        if self._recurring == rec then return end
        self._recurring = rec
        self:_Refresh()
    end;

    SetFocused = function(self, focused)
        focused = focused and true or false
        if self._focused == focused then return end
        self._focused = focused
        self:_Refresh()
    end;

    SetComplete = function(self, complete)
        complete = complete and true or false
        if self._complete == complete then return end
        self._complete = complete
        self:_Refresh()
    end;

    _SetPressed = function(self, pressed)
        if self._pressed == pressed then return end
        self._pressed = pressed
        self:_Refresh()
    end;

    _Refresh = function(self)
        local family = self._recurring
                and MUI_AtlasRegistry.QuestPoiRecurring
                or  MUI_AtlasRegistry.QuestPoiDefault

        self.outerGlow:SetAtlas(family, "GlowOuter", true)
        self.innerGlow:SetAtlas(family, "GlowInner", true)
		
		if self._focused or self._legendGlow then
			self.outerGlow:Show()
		else
			self.outerGlow:Hide()
		end
		
		local ringRegion
		if self._pressed then
			ringRegion = self._focused and "BgFocusedPressed" or "BgPressed"
		else
			ringRegion = self._focused and "BgFocused" or "Bg"
		end
		self.ring:SetAtlas(family, ringRegion, true)

        local glyph = not self._complete and POI_GLYPHS[self._glyph]
        self._dotScale = glyph and glyph.scale or 1
        self.dots:SetSize(self:GetWidth() * self._dotScale, self:GetHeight() * self._dotScale)
        if glyph and glyph.underlay then
            self.underlay:SetAtlas(MUI_AtlasRegistry.QuestPoiGlyphs, glyph.underlay, true)
            self.underlay:Show()
        else
            self.underlay:Hide()
        end

        if self._complete then
			self.dots:SetTextureRegion(MUI.TEX_SKIN .. "questtracker\\poi-checkmark", 32, 32, 0, 0, 32, 32)
		elseif glyph then
			self.dots:SetAtlas(MUI_AtlasRegistry.QuestPoiGlyphs, glyph.region, true)
		else
			self.dots:SetAtlas(MUI_AtlasRegistry.QuestPoiInProgress,
				self._focused and "DotsBrown" or "DotsYellow", true)
		end

        if glyph and glyph.focusRing and self._focused then
            self.focusRing:Show()
        else
            self.focusRing:Hide()
        end
        
    end;

    -- What the map legend calls this pin: "turnin", the quest type glyph
    -- it shows, or "inprogress" for the plain dots.
    GetLegendKind = function(self)
        if self._complete then return "turnin" end
        return POI_GLYPHS[self._glyph] and self._glyph or "inprogress"
    end;

    -- Outer glow while the pin's map legend row is hovered.
    SetLegendGlow = function(self, on)
        on = on and true or false
        if self._legendGlow == on then return end
        self._legendGlow = on
        self:_Refresh()
    end;

    -- Hover highlight driven from outside the button: the quest-log row
    -- and the map pin of the same quest mirror each other's hover.
    SetHighlighted = function(self, on)
        if on then self.innerGlow:Show() else self.innerGlow:Hide() end
    end;

    PlayPulse = function(self)
        -- Grow/shrink each POI texture around its CENTER anchor by
        -- mutating SetSize each frame. Leaves the POI frame rect
        -- (28×28) untouched, so siblings anchored to it (the title)
        -- don't shift. SetScale on a frame would scale its effective
        -- anchor rect; SetScale on a texture is a no-op in WoW.
        local layers = {
            { tex = self.outerGlow, w = self:GetWidth()*2, h = self:GetHeight()*2 },
            { tex = self.ring,      w = self:GetWidth(),   h = self:GetHeight() },
            { tex = self.underlay,  w = self:GetWidth(),   h = self:GetHeight() },
            { tex = self.dots,      w = self:GetWidth() * self._dotScale, h = self:GetHeight() * self._dotScale },
        }
        local function setAll(s)
            for _, L in ipairs(layers) do L.tex:SetSize(L.w * s, L.h * s) end
        end

        local DELAY, UP, DOWN, PEAK = 0.05, 0.04, 0.16, 1.5
        local elapsed = 0
        setAll(1)
        self:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            local t = elapsed - DELAY
            if t < 0 then return end
            if t < UP then
                setAll(1 + (PEAK - 1) * (t / UP))
            elseif t < UP + DOWN then
                setAll(PEAK - (PEAK - 1) * ((t - UP) / DOWN))
            else
                setAll(1)
                self:SetScript("OnUpdate", nil)
            end
        end)
    end;

}


-- ---------------------------------------------------------------------
-- QuestTrackerObjective: one objective row.
-- Bullet is a text "-" when the objective is in progress. When finished
-- / failed, the dash hides and a texture shows in its place. Text colour
-- also swaps (grey when finished).
-- ---------------------------------------------------------------------
class "QuestTrackerObjective" : extends "Frame" {
    __init = function(self, parent, name)
        Frame.__init(self, "Frame", parent, name)
        self:SetHeight(OBJECTIVE_H)

        self.text = FontString(self, nil, "ARTWORK")
        self.text:SetFont(MUI.FONT, 10.5)
        self.text:SetShadowOffset(1, -1)
        self.text:SetJustifyH("LEFT")
        self.text:ClearAllPoints()
		self.text:AlignParentTopLeft(0, BULLET_W-1)
		self.text:AlignParentRight(20)
		
		self.bulletText = FontString(self, nil, "ARTWORK")
        self.bulletText:SetFont(MUI.FONT, 10.5)
        self.bulletText:SetShadowOffset(1, -1)
        self.bulletText:SetJustifyH("LEFT")
        self.bulletText:SetWidth(BULLET_W)
        self.bulletText:ClearAllPoints()
        self.bulletText:AlignParentTopLeft(-1, -1)
        self.bulletText:SetText("-")

        self.bulletIcon = Texture(self, nil, "ARTWORK")
        self.bulletIcon:SetSize(BULLET_ICON_SIZE, BULLET_ICON_SIZE)
        self.bulletIcon:ClearAllPoints()
        self.bulletIcon:AlignParentTopLeft(-1.5, -11)
        self.bulletIcon:Hide()

        -- Completion halo (invisible until PlayCompleteAnim fires).
        self.checkGlow = Texture(self, nil, "OVERLAY")
        self.checkGlow:SetSize(BULLET_ICON_SIZE * 2, BULLET_ICON_SIZE * 2)
        self.checkGlow:SetPoint("CENTER", self.bulletIcon, "CENTER", 0, 0)
        self.checkGlow:SetAtlas(MUI_AtlasRegistry.QuestTracker,
            "TrackerCheckGlow", true)
        self.checkGlow:SetBlendMode("ADD")
        self.checkGlow:Hide()
		
    end;

    SetObjective = function(self, o)
        local atlas = MUI_AtlasRegistry.QuestTracker
        if o.finished then
            self.bulletText:Hide()
            self.bulletIcon:SetAtlas(atlas, "TrackerCheck", true)
            self.bulletIcon:SetSize(BULLET_ICON_SIZE)
            self.bulletIcon:ClearAllPoints()
            self.bulletIcon:AlignParentTopLeft(-1.5, -11)
            self.bulletIcon:Show()
            self.text:SetTextColor(0.7, 0.7, 0.7, 1)
        elseif o.failed then
            -- The "x" reads heavier than the check; draw it smaller, centred
            -- on the same spot.
            local size, inset = BULLET_ICON_SIZE - 4, 2
            self.bulletText:Hide()
            self.bulletIcon:SetAtlas(atlas, "ObjectiveFail", true)
            self.bulletIcon:SetSize(size)
            self.bulletIcon:ClearAllPoints()
            self.bulletIcon:AlignParentTopLeft(-1.5 + inset, -11 + inset)
            self.bulletIcon:Show()
            self.text:SetTextColor(0.85, 0.3, 0.3, 1)
        else
            self.bulletIcon:Hide()
            self.bulletText:SetVisible(not o.noDash)
            self.bulletText:SetTextColor(0.95, 0.95, 0.95, 1)
            self.text:SetTextColor(0.95, 0.95, 0.95, 1)
        end
        self.text:SetText(o.text or "")
        -- Long objective strings wrap within the row's width; grow the
        -- row height to fit so the next row doesn't overlap. The FontString
        -- has TOPLEFT + RIGHT anchors (no BOTTOM), so GetStringHeight
        -- reports the actual wrapped block height.
        local sh = self.text:GetStringHeight() or 0
        self:SetHeight(math.max(OBJECTIVE_H, sh + 2))
    end;

    -- 0→1 scale pulse + fade-out halo, matches retail CheckAnim.
    PlayCompleteAnim = function(self)
        self.checkGlow:Show()
        self.checkGlow:SetAlpha(1)

        local ag = AnimationGroup(self)
        local s1 = ag:CreateAnimation("Scale")
        s1:SetTarget(self.checkGlow)
        s1:SetScaleFrom(1, 1)
        s1:SetScaleTo(1.3, 1.3)
        s1:SetDuration(0.075)
        local s2 = ag:CreateAnimation("Scale")
        s2:SetTarget(self.checkGlow)
        s2:SetScaleFrom(1.3, 1.3)
        s2:SetScaleTo(1, 1)
        s2:SetDuration(0.075)
        s2:SetStartDelay(0.075)
        local fade = ag:CreateAnimation("Alpha")
        fade:SetTarget(self.checkGlow)
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0)
        fade:SetDuration(0.58)
        fade:SetStartDelay(0.15)
        ag:SetScript("OnFinished", function() self.checkGlow:Hide() end)
        ag:Play()
    end;
}


-- ---------------------------------------------------------------------
-- QuestTrackerQuest: one tracked quest. No bg, no expander — just the
-- POI button + golden title + objective lines (or "Can Turn In." grey
-- line when all objectives are finished).
--
-- Hover-dim: the whole block is mouse-enabled; when the cursor is in
-- the block (including over the POI child), the textual layer goes to
-- BRIGHT_ALPHA; unhovered drops to DIM_ALPHA. Uses the pattern of
-- listening to OnEnter/OnLeave on both parent and POI child and
-- recomputing MouseIsOver(self._native) — handles the transition where
-- the mouse moves from block body onto POI (which would otherwise fire
-- block.OnLeave even though the block is still effectively hovered).
-- ---------------------------------------------------------------------
-- ---------------------------------------------------------------------
-- QuestTrackerItemButton: the quest's usable item (retail's
-- QuestObjectiveItemButtonTemplate), a secure item-use button seated at the
-- block's top-right. Deliberately NOT a child of the block: a protected
-- descendant makes Show / SetPoint / SetHeight on the block — and on the
-- whole tracker above it — protected in combat, which is exactly what froze
-- the layout back when quest rows were secure. Parented to the root instead
-- and positioned by absolute offsets from the block's rect by the tracker's
-- item driver. In combat it can't be moved, re-bound, shown or hidden; only
-- the cooldown and range indicators stay live.
-- ---------------------------------------------------------------------
class "QuestTrackerItemButton" : extends "SecureActionButton" {
    __init = function(self, name)
        SecureActionButton.__init(self, nil, name)
        self:SetSize(ITEM_BTN_SIZE, ITEM_BTN_SIZE)
        self:SetFrameStrata("LOW")
        self:SetAttribute("type", "item")
        self.rangeTimer = 0

        local atlas = MUI_AtlasRegistry.ActionBar

        self.bg = Texture(self, nil, "BACKGROUND")
        self.bg:SetAtlas(atlas, "IconFrameSlot", true)
        self.bg:FillParent(-2)

        self.icon = Texture(self, nil, "ARTWORK")
        self.icon:FillParent()
        self.icon:SetTexCoord(0.05, 0.96, 0.06, 0.96)

        self.cooldown = Cooldown(self)
        self.cooldown:FillParent()
        self.cooldown:SetSwipeColor(0, 0, 0, 0.8)
        self.cooldown:SetDrawEdge(false)

        -- Border, count and range dot sit on a raised child so they draw
        -- over the cooldown swipe, like the action bars' border frame.
        self.overlay = Frame("Frame", self)
        self.overlay:FillParent()
        self.overlay:SetFrameLevel(self:GetFrameLevel() + 2)

        self.border = Texture(self.overlay, nil, "ARTWORK")
        self.border:SetTextureRegion(MUI.TEX_SKIN .. "actionbars\\actionbar-slot", 128, 128, 17, 16, 92, 95)
        self.border:FillParentPadding(-2, -2, -1.5, -2.4)

        self.count = FontString(self.overlay, nil, "OVERLAY")
        self.count:SetFont(MUI.FONT, 9, "OUTLINE")
        self.count:SetJustifyH("RIGHT")
        self.count:AlignParentBottomRight(2, 1)

        self.range = FontString(self.overlay, nil, "OVERLAY")
        self.range:SetFont(MUI.FONT, 12, "OUTLINE")
        self.range:SetText("•")
        self.range:AlignParentTopRight(1, -3)
        self.range:Hide()

        local hl = atlas:GetRegion("IconFrameMouseover")
        local hlTex = self:SetHighlightTexture(hl.file)
        hlTex:SetTexCoord(hl.left, hl.right, hl.top, hl.bottom)
        hlTex:SetBlendMode("ADD")
        local pushed = atlas:GetRegion("IconFrameDown")
        local pushedTex = self:SetPushedTexture(pushed.file)
        pushedTex:SetTexCoord(pushed.left, pushed.right, pushed.top, pushed.bottom)

        -- To the left: the tracker hugs the screen's right edge.
        self:SetTooltip("ANCHOR_LEFT", function(tip)
            if self.logIndex then tip:SetQuestLogSpecialItem(self.logIndex) end
        end)
    end;

    -- Bind to a quest's item. Out of combat only — attributes of a protected
    -- frame are locked in combat.
    SetItem = function(self, questId, logIndex, link, icon)
        self.questId  = questId
        self.logIndex = logIndex
        self.itemId   = tonumber(link:match("item:(%d+)"))
        self:SetAttribute("item", link)
        self.icon:SetTexture(icon)
        local _, _, charges = GetQuestLogSpecialItemInfo(logIndex)
        self.count:SetText((charges and charges > 1) and tostring(charges) or "")
        self:UpdateCooldown()
        self.rangeTimer = 0
    end;

    -- Put the top-right corner at screen point (right, top) in the tracker's
    -- scale. No-op when nothing moved, so the per-frame driver stays cheap.
    Seat = function(self, scale, right, top)
        if self.seatScale == scale and self.seatRight == right and self.seatTop == top then return end
        self.seatScale, self.seatRight, self.seatTop = scale, right, top
        self:SetScale(scale)
        self:ClearAllPoints()
        self:SetPoint("TOPRIGHT", MUI_Root, "BOTTOMLEFT", right, top)
    end;

    -- Read by item ID, as bag slots do: Era's own UI never calls
    -- GetQuestLogSpecialItemCooldown (only the Wrath watch frame does).
    UpdateCooldown = function(self)
        if not self.itemId then return end
        local start, duration, enable = C_Container.GetItemCooldown(self.itemId)
        self.cooldown:SetCooldown(start, duration, enable)
        local c = (duration and duration > 0 and enable == 0) and 0.4 or 1
        self.icon:SetVertexColor(c, c, c)
    end;

    -- Retail polls the range check every TOOLTIP_UPDATE_TIME: red dot out of
    -- range, grey in range, nothing when the item has no range.
    UpdateRange = function(self, elapsed)
        self.rangeTimer = self.rangeTimer - elapsed
        if self.rangeTimer > 0 or not self.logIndex then return end
        self.rangeTimer = 0.2
        local inRange = IsQuestLogSpecialItemInRange(self.logIndex)
        if inRange == 0 then
            self.range:SetTextColor(1, 0.1, 0.1)
            self.range:Show()
        elseif inRange == 1 then
            self.range:SetTextColor(0.6, 0.6, 0.6)
            self.range:Show()
        else
            self.range:Hide()
        end
    end;
}

-- Header glow bar that sweeps across a block's title (quest accept, recipe
-- tracked) — Blizzard_ObjectiveTrackerAnimTemplates.xml's HeaderGlow block:
--   • Alpha 0→1 at t=0 instantly (duration 0).
--   • Scale (origin LEFT) scaleX 0→1 over 0.31s starting at t=0.15.
--       Creates the left-to-right "reveal" sweep — texture width
--       visually grows from 0 to full.
--   • Alpha 1→0 over 0.41s starting at t=0.33. Fades the bar while
--       the sweep is still finishing.
-- `block` needs a `shine` texture anchored to its title.
local function PlayShineSweep(block)
    if block._shineAnim and block._shineAnim:IsPlaying() then
        block._shineAnim:Stop()
    end
    block.shine:Show()
    block.shine:SetAlpha(0)

    local ag = AnimationGroup(block)

    local aIn = ag:CreateAnimation("Alpha")
    aIn:SetTarget(block.shine)
    aIn:SetFromAlpha(0)
    aIn:SetToAlpha(1)
    aIn:SetDuration(0)

    local sweep = ag:CreateAnimation("Scale")
    sweep:SetTarget(block.shine)
    sweep:SetScaleFrom(0, 1)
    sweep:SetScaleTo(1, 1)
    sweep:SetDuration(0.31)
    sweep:SetStartDelay(0.15)
    sweep:SetOrigin("LEFT", 0, 0)

    local aOut = ag:CreateAnimation("Alpha")
    aOut:SetTarget(block.shine)
    aOut:SetFromAlpha(1)
    aOut:SetToAlpha(0)
    aOut:SetDuration(0.41)
    aOut:SetStartDelay(0.33)

    ag:SetScript("OnFinished", function() block.shine:Hide() end)
    ag:Play()
    block._shineAnim = ag
end

class "QuestTrackerQuest" : extends "Frame" {
    __init = function(self, parent, name)
        Frame.__init(self, "Frame", parent, name)
        self:EnableMouse(true)

        self.poi = QuestPoiButton(self)
        self.poi:ClearAllPoints()
        self.poi:AlignParentTopLeft(0, 6)
        self.poi.OnClick = function()
            if not self.questId then return end
            if MUI_QuestHelper:IsFocused(self.questId) then
                MUI_QuestHelper:SetFocusedQuest(nil)
            else
                MUI_QuestHelper:SetFocusedQuest(self.questId)
            end
        end

        self.title = FontString(self, nil, "ARTWORK")
        self.title:SetFont(MUI.FONT, 10.5)
        self.title:SetShadowOffset(1, -1)
        self.title:SetTextColor(1, 0.82, 0, 1)
        self.title:SetJustifyH("LEFT")
        self.title:SetWordWrap(false)
        self.title:RightOf(self.poi, 2, -0.5)

        -- Header glow bar that sweeps across the title on accept + on
        -- completion. Scale animation with LEFT origin grows the
        -- rendered width 0→1, producing the left-to-right reveal seen
        -- in retail. Matches Blizzard_ObjectiveTrackerAnimTemplates.xml
        -- (AddAnim / TurnInAnim on HeaderGlow using
        -- `ui-questtracker-objfx-barglow`).
        self.shine = Texture(self, nil, "OVERLAY")
        self.shine:SetAtlas(MUI_AtlasRegistry.QuestTracker, "AnimBarGlow", true)
        self.shine:SetBlendMode("ADD")
        self.shine:SetSize(200, TITLE_H + 6)
        self.shine:ClearAllPoints()
        self.shine:SetPoint("LEFT", self.title, "LEFT", -2, 0)
        self.shine:SetAlpha(0)
        self.shine:Hide()

        self.objContainer = Frame("Frame", self)
        self.objContainer:ClearAllPoints()
        self.objContainer:SetPoint("TOPLEFT",  self.title, "BOTTOMLEFT", 0, -4)
        self.objContainer:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)

        -- Dual-purpose text row shown when there are no per-objective
        -- rows. Grey "Can Turn In." when entry.isComplete; white DB
        -- objectivesText (e.g. "Speak with Marshal McBride.") when the
        -- quest simply has no leaderboard objectives.
        self.turnInLabel = FontString(self.objContainer, nil, "ARTWORK")
        self.turnInLabel:SetFont(MUI.FONT, 10.5)
        self.turnInLabel:SetShadowOffset(1, -1)
        self.turnInLabel:SetJustifyH("LEFT")
        self.turnInLabel:ClearAllPoints()
        self.turnInLabel:AlignParentTopLeft(0, BULLET_W)
        self.turnInLabel:AlignParentTopRight(0, 20)
        self.turnInLabel:Hide()

        self.objectives     = {}
        self._prevFinished  = {}
        self._prevIsComplete = false
        -- Elements whose alpha mirrors the hover state. POI stays bright.
        self._dimTargets = { self.title, self.objContainer, }

        self.title:SetScript("OnEnter", function() self:_SyncHover(true) end)
        self.title:SetScript("OnLeave", function() self:_SyncHover(false) end)

        -- Left-click anywhere on the row (outside the POI button which
        -- has its own focus-toggle handler) opens the world map with
        -- the quest description tab on this quest. Mirrors the behavior
        -- of the world-map quest log rows.
        --
        -- This was a SecureActionButtonTemplate so /click WorldMapMicroButton
        -- could open the map mid-combat. The cost was severe: every quest
        -- row inherited Blizzard's "moving a secure descendant in combat is
        -- protected" rule, so SetPoint/SetHeight/Show on the row (and its
        -- parents) were blocked the moment combat started, freezing the
        -- tracker's layout. Quest progress events that arrived during
        -- combat couldn't apply until PLAYER_REGEN_ENABLED.
        --
        -- We now use a plain Button. The click still navigates the world
        -- map to the quest's zone and switches its tab. Opening the map
        -- when it's closed works out of combat (ToggleWorldMap is callable
        -- from addon code there) and is a silent no-op in combat — that's
        -- the only feature we give up to unblock combat-time row updates.
        self._titleClick = Button(self)
        self._titleClick:ClearAllPoints()
        self._titleClick:SetPoint("TOPLEFT",     self, "TOPLEFT",   31, 0)
        self._titleClick:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT",   0, -TITLE_H - 6)
        self._titleClick.OnClick = function()
            if not self.questId then return end
            -- Shift-click with a chat box open links the quest (Questie's format).
            if IsModifiedClick("CHATLINK") and MUI_ModuleQuestLinks:InsertLink(self.questId) then
                return
            end
            -- Open the map out of combat. ToggleWorldMap is protected in
            -- combat, so this is silently skipped there — the navigation
            -- below still runs and will be reflected when the player next
            -- opens the map manually.
            if not InCombatLockdown() and WorldMapFrame
               and not WorldMapFrame:IsShown() and ToggleWorldMap then
                ToggleWorldMap()
            end
            if MUI_ModuleMap then
                MUI_ModuleMap:ShowQuestDescription(self.questId)
                local target = MUI_FocusManager:PickTarget("quest", self.questId, true)
                if target and target.continent then
                    local zoneMap = MUI_MapMath:GetBestMapForWorld(
                        target.continent, target.wx, target.wy)
                    if zoneMap and WorldMapFrame then WorldMapFrame:SetMapID(zoneMap) end
                end
            end
            PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end

    end;

    SetQuest = function(self, questId, entry)
        local questChanged = (self.questId ~= questId)
        self.questId = questId
        
        -- Pool reuse safety: a prior turn-in anim leaves this block at
        -- alpha 0. Reset every bind so a freshly-assigned quest is
        -- always fully visible.
        self:SetAlpha(1)

        local r,g,b = _difficultyColor(entry.level)
        self.title:SetTextColor(r, g, b, 0.75)

        -- Hover events: the title FontString itself can't take SetScript
        -- (regions don't fire mouse events) so the original
        -- `self.title:SetScript("OnEnter", …)` calls below are dead.
        -- Routing through the SecureButton overlay revives the dim /
        -- bright transition.
        self._titleClick:SetScript("OnEnter", function() self:_SyncHover(true, entry.level)  end)
        self._titleClick:SetScript("OnLeave", function() self:_SyncHover(false, entry.level) end)

        self.poi:SetRecurring(_isRepeatable(questId))
        self.poi:SetComplete(entry.isComplete and true or false)
        self.poi:SetGlyph(MUI_QuestHelper:GetQuestGlyph(questId, entry))
        self:RefreshFocus()

        local showLvl = MUI_DB and MUI_DB.settings
            and MUI_DB.settings.questHelper
            and MUI_DB.settings.questHelper.showQuestLevel

        local title = MUI_QuestHelper:GetQuestDisplayName(questId, entry.title or ("quest " .. questId))
        if showLvl then 
            title = "[" .. entry.level .. "] " .. title
        end
        if entry.isFailed then title = title .. " |cffff2020(Failed)|r" end
        self.title:SetText(title)

        -- Quest item: a usable item the quest gave (retail shows it while in
        -- progress, or when complete if the item is flagged for that). The
        -- tracker's pooled buttons render it; the block records what to bind
        -- and reserves the right-edge room so text can't run under it.
        self.logIndex = entry.logIndex
        self.isComplete = entry.isComplete and true or false
        self:RefreshItem()

        -- "All objectives complete" transition → replay the add anim so
        -- the row visually celebrates the milestone the same way it
        -- celebrated the initial accept (shine sweep + POI pulse).
        -- Suppressed when the block is being bound to a different quest
        -- (fresh state, not a live flip). The real turn-in animation is
        -- played separately from the tracker's OnQuestRemoved path.
        local isComplete = entry.isComplete and true or false
        if not questChanged and isComplete and not self._prevIsComplete then
            self:PlayAddAnim()
        end
        self._prevIsComplete = isComplete

        for _, row in ipairs(self.objectives) do row:Hide() end

        if entry.isComplete then
            self.turnInLabel:SetText("Can Turn In.")
            self.turnInLabel:SetTextColor(0.7, 0.7, 0.7, 1)
            self.turnInLabel:Show()
            -- Floor to OBJECTIVE_H so a "Can Turn In." block lines up
            -- with a single-objective block of the same quest.
            self.objContainer:SetHeight(math.max(OBJECTIVE_H,
                self.turnInLabel:GetStringHeight() or 0))
            self:_LayoutAndRebaseline(entry, questChanged, {})
            return
        end

        local y, count = 0, 0
        local flipped = {}
        if entry.objectives then
            for idx, o in ipairs(entry.objectives) do
                if o and o.text and o.text ~= "" then
                    count = count + 1
                    local row = self.objectives[count]
                    if not row then
                        row = QuestTrackerObjective(self.objContainer)
                        self.objectives[count] = row
                    end
                    row:ClearAllPoints()
					row:AlignParentTop(y)
					row:FillWidth()
                    row:SetObjective(o)
                    row:Show()
                    -- Advance by the row's actual height, not the nominal
                    -- OBJECTIVE_H — SetObjective grows the row when the
                    -- text wraps onto multiple lines.
                    y = y + (row:GetHeight() or OBJECTIVE_H) + OBJECTIVE_GAP

                    if not questChanged and o.finished
                            and not self._prevFinished[idx] then
                        flipped[#flipped + 1] = row
                    end
                end
            end
        end

        if count == 0 then
            -- No leaderboard objectives — fall back to the DB's
            -- objectivesText so rows like "A Threat Within" still show a
            -- description ("Speak with Marshal McBride.") under the
            -- title. Reuses the turnInLabel element in white.
            local q = MUI_QuestDB and MUI_QuestDB:Get(questId)
            local lines = q and q.objectivesText
            if lines and #lines > 0 then
                local text = type(lines) == "table"
                             and table.concat(lines, "\n")
                             or tostring(lines)
                self.turnInLabel:SetText(text)
                self.turnInLabel:SetTextColor(1, 1, 1, 1)
                self.turnInLabel:Show()
                y = math.max(OBJECTIVE_H,
                    self.turnInLabel:GetStringHeight() or 0)
            else
                self.turnInLabel:Hide()
            end
        else
            self.turnInLabel:Hide()
        end

        self.objContainer:SetHeight(y == 0 and 1 or (y - OBJECTIVE_GAP))
        self:_LayoutAndRebaseline(entry, questChanged, flipped)
    end;

    _LayoutAndRebaseline = function(self, entry, questChanged, flipped)
        -- Re-baseline the per-objective finished cache for next diff.
        if questChanged then self._prevFinished = {} end
        if entry.objectives then
            for idx, o in ipairs(entry.objectives) do
                self._prevFinished[idx] = o.finished and true or false
            end
        end

        -- Height = title row + objectives. Ensure at least the POI fits.
        local body = self.objContainer:GetHeight() or 0
        local h = math.max(self.poi:GetHeight(), TITLE_H + 2 + body + 4)
        self:SetHeight(h)

        for _, row in ipairs(flipped) do row:PlayCompleteAnim() end
    end;

    -- AddAnim — the shine sweep (shared with recipe blocks) plus the POI
    -- pulse: brief linear scale-up + scale-back centred on the POI button.
    -- Plays only on accept (retail behaviour). Done via manual OnUpdate
    -- interpolation rather than two back-to-back Scale animations because
    -- WoW releases a Scale animation's transform when it ends — pulseUp →
    -- pulseDown in the same group caused a 1-frame snap back to scale 1.0
    -- between the two. Driving the scale directly avoids that gap entirely.
    PlayAddAnim = function(self)
        PlayShineSweep(self)
        self.poi:PlayPulse()
    end;

    -- TurnInAnim — HeaderGlow sweep (0.51s) + shine fade-out (0.33s)
    -- + whole-block fade to 0 (0.33s). Matches retail's TurnInAnim
    -- with setToFinalAlpha behaviour. `onComplete` fires when the
    -- anim finishes so the caller can trigger removal / Rebuild after
    -- the block has visually faded. Block stays at alpha 0 until the
    -- caller's onComplete callback dismisses / reassigns it.
    PlayTurnInAnim = function(self, onComplete)
        if self._shineAnim and self._shineAnim:IsPlaying() then
            self._shineAnim:Stop()
        end
        self.shine:Show()
        self.shine:SetAlpha(0)

        local ag = AnimationGroup(self)

        local aIn = ag:CreateAnimation("Alpha")
        aIn:SetTarget(self.shine)
        aIn:SetFromAlpha(0)
        aIn:SetToAlpha(1)
        aIn:SetDuration(0)

        local sweep = ag:CreateAnimation("Scale")
        sweep:SetTarget(self.shine)
        sweep:SetScaleFrom(0, 1)
        sweep:SetScaleTo(1, 1)
        sweep:SetDuration(0.51)
        sweep:SetOrigin("LEFT", 0, 0)

        local shineOut = ag:CreateAnimation("Alpha")
        shineOut:SetTarget(self.shine)
        shineOut:SetFromAlpha(1)
        shineOut:SetToAlpha(0)
        shineOut:SetDuration(0.33)
        shineOut:SetStartDelay(0.33)

        -- Fade the whole block alongside the shine trail.
        local blockFade = ag:CreateAnimation("Alpha")
        blockFade:SetTarget(self)
        blockFade:SetFromAlpha(1)
        blockFade:SetToAlpha(0)
        blockFade:SetDuration(0.33)
        blockFade:SetStartDelay(0.33)

        ag:SetScript("OnFinished", function()
            self.shine:Hide()
            self:SetAlpha(0)   -- hold the faded state until Rebuild
            if onComplete then onComplete() end
        end)
        ag:Play()
        self._shineAnim = ag
    end;

    -- The quest's usable item, read at the quest's live log index: indices
    -- shift whenever a quest is added or removed, so the watcher's copy can
    -- be a slot behind and name another quest's item.
    RefreshItem = function(self)
        local logIndex = GetQuestLogIndexByID(self.questId)
        if not logIndex or logIndex == 0 then logIndex = self.logIndex end
        self.logIndex = logIndex
        local link, icon, _, showWhenComplete
        if logIndex and logIndex > 0 then
            link, icon, _, showWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
        end
        self.itemLink = (link and (not self.isComplete or showWhenComplete)) and link or nil
        self.itemIcon = icon
        local inset = self.itemLink and (ITEM_BTN_SIZE + ITEM_BTN_GAP) or 0
        self.title:SetWidth(WIDTH - self.poi:GetWidth() - 2 - inset)
        self.objContainer:ClearAllPoints()
        self.objContainer:SetPoint("TOPLEFT",  self.title, "BOTTOMLEFT", 0, -4)
        self.objContainer:SetPoint("TOPRIGHT", self, "TOPRIGHT", -inset, 0)
    end;

    RefreshFocus = function(self)
        if not self.questId then return end
        self.poi:SetFocused(MUI_QuestHelper:IsFocused(self.questId))
    end;

    _SyncHover = function(self, isOver, level)
        local r,g,b = _difficultyColor(level)
        if isOver then
            self.title:SetTextColor(r, g, b, 1)
			self.objContainer:SetAlpha(1)
		else
			self.title:SetTextColor(r, g, b, 0.75)
			self.objContainer:SetAlpha(0.85)
		end
		
    end;
}


-- ---------------------------------------------------------------------
-- QuestTrackerRecipe: a tracked profession recipe (retail's
-- ProfessionsRecipeTracker block) — the recipe's name over one line per
-- reagent, "have/need Name", checked once the bags hold enough. Same
-- shape as a quest row so the category lays it out the same way; the
-- title stands where quest titles do, past the POI column. Right-click
-- untracks (Untrack); a left click is Open, nothing for a recipe.
-- ---------------------------------------------------------------------
class "QuestTrackerRecipe" : extends "Frame" {
    __init = function(self, parent, name)
        Frame.__init(self, "Frame", parent, name)
        self:EnableMouse(true)

        -- Stands in for a quest row's POI button, so the title lines up.
        self.anchor = Frame("Frame", self)
        self.anchor:SetSize(29, 29)
        self.anchor:AlignParentTopLeft(0, 6)

        self.title = FontString(self, nil, "ARTWORK")
        self.title:SetFont(MUI.FONT, 10.5)
        self.title:SetShadowOffset(1, -1)
        self.title:SetTextColor(1, 0.82, 0, 1)
        self.title:SetJustifyH("LEFT")
        self.title:SetWordWrap(false)
        self.title:RightOf(self.anchor, 2, -0.5)
        self.title:SetWidth(WIDTH - 29 - 2)

        self.shine = Texture(self, nil, "OVERLAY")
        self.shine:SetAtlas(MUI_AtlasRegistry.QuestTracker, "AnimBarGlow", true)
        self.shine:SetBlendMode("ADD")
        self.shine:SetSize(200, TITLE_H + 6)
        self.shine:ClearAllPoints()
        self.shine:SetPoint("LEFT", self.title, "LEFT", -2, 0)
        self.shine:SetAlpha(0)
        self.shine:Hide()

        self.objContainer = Frame("Frame", self)
        self.objContainer:ClearAllPoints()
        self.objContainer:SetPoint("TOPLEFT",  self.title, "BOTTOMLEFT", 0, -4)
        self.objContainer:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)

        self.objectives = {}

        self:SetScript("OnEnter", function() self:_SyncHover(true) end)
        self:SetScript("OnLeave", function() self:_SyncHover(false) end)
        self:SetScript("OnMouseUp", function(_, button)
            if not self.questId or not self:IsMouseOver() then return end
            if button == "RightButton" then
                self:Untrack()
            elseif button == "LeftButton" then
                self:Open()
            end
        end)
    end;

    Open = function(self) end;

    Untrack = function(self)
        MUI_RecipeTracker:SetTracked(self.questId, false)
    end;

    -- `entry` = { title, objectives = { { text, finished } } }; `spellID`
    -- plays the quest id's part for the category's bookkeeping.
    SetQuest = function(self, spellID, entry)
        self.questId = spellID
        self:SetAlpha(1)    -- a pooled block may still sit faded from its removal
        self.title:SetText(entry.title)

        for _, row in ipairs(self.objectives) do row:Hide() end
        local y = 0
        for i, o in ipairs(entry.objectives) do
            local row = self.objectives[i]
            if not row then
                row = QuestTrackerObjective(self.objContainer)
                self.objectives[i] = row
            end
            row:ClearAllPoints()
            row:AlignParentTop(y)
            row:FillWidth()
            row:SetObjective(o)
            row:Show()
            y = y + (row:GetHeight() or OBJECTIVE_H) + OBJECTIVE_GAP
        end
        self.objContainer:SetHeight(y == 0 and 1 or (y - OBJECTIVE_GAP))

        local body = self.objContainer:GetHeight() or 0
        self:SetHeight(math.max(self.anchor:GetHeight(), TITLE_H + 2 + body + 4))
    end;

    RefreshFocus = function(self) end;

    -- Tracked: the shine sweep. Untracked: the quest turn-in farewell.
    PlayAddAnim = function(self)
        PlayShineSweep(self)
    end;

    PlayTurnInAnim = QuestTrackerQuest.PlayTurnInAnim;

    _SyncHover = function(self, isOver)
        self.title:SetTextColor(1, 0.82, 0, isOver and 1 or 0.75)
        self.objContainer:SetAlpha(isOver and 1 or 0.85)
    end;
}


-- ---------------------------------------------------------------------
-- QuestTrackerAchievement: a tracked achievement (retail's
-- AchievementObjectiveTracker block) — its name over its unfinished
-- criteria, shaped like a recipe block. A click opens it in the
-- achievement panel; right-click untracks.
-- ---------------------------------------------------------------------
class "QuestTrackerAchievement" : extends "QuestTrackerRecipe" {
    __init = function(self, parent, name)
        QuestTrackerRecipe.__init(self, parent, name)
    end;

    Open = function(self)
        MUI_ModuleAchievements:Open(self.questId)
    end;

    Untrack = function(self)
        MUI_ModuleAchievements.engine:Untrack(self.questId)
    end;
}


-- ---------------------------------------------------------------------
-- QuestTrackerCategory: SecondaryHeader strip + list of rows. Supplies
-- rows via SetQuests({entry,…}); collapse hides the body. `rowClass`
-- (default QuestTrackerQuest) is what each entry is shown with.
-- ---------------------------------------------------------------------
class "QuestTrackerCategory" : extends "Frame" {
    __init = function(self, parent, name, label, rowClass)
        Frame.__init(self, "Frame", parent, name)
        self._rowClass = rowClass or QuestTrackerQuest

        self.header = Frame("Frame", self)
        self.header:SetHeight(SECONDARY_H)
        self.header:ClearAllPoints()
        self.header:AlignParentTop()
		self.header:FillWidth()

        self.headerBg = Texture(self.header, nil, "BACKGROUND")
        self.headerBg:SetAtlas(MUI_AtlasRegistry.QuestTracker,
            "SecondaryHeader", true)
        self.headerBg:ClearAllPoints()
        self.headerBg:SetAllPoints(self.header)

        self.collapse = QuestTrackerCollapseBtn(self.header, nil, "secondary", SECONDARY_BTN)
        self.collapse:ClearAllPoints()
        self.collapse:AlignParentRight(0)
        self.collapse.OnClick = function() self:ToggleCollapsed() end

        self.label = FontString(self.header, nil, "OVERLAY")
        self.label:SetFont(MUI.FONT, 13)
        self.label:SetShadowOffset(1, -1)
        self.label:SetTextColor(1, 0.82, 0, 1)
        self.label:SetJustifyH("LEFT")
        self.label:ClearAllPoints()
        self.label:AlignParentLeft(22)
		self.label:LeftOf(self.collapse)
        self.label:SetText(label or "")

        -- Parent to the category (not UIParent) so Hide() cascades: collapsing
        -- "All Objectives" hides the category, which must take its quest rows
        -- with it. The position still comes from the SetPoint to header.
        self.body = Frame("Frame", self)
        self.body:ClearAllPoints()
        self.body:SetPoint("TOPLEFT",  self.header, "BOTTOMLEFT",  0, -HEADER_QUEST_PAD)
        self.body:SetPoint("TOPRIGHT", self.header, "BOTTOMRIGHT", 0, -HEADER_QUEST_PAD)

        self.quests     = {}
        self._collapsed = false
    end;

    SetQuests = function(self, entries, pendingAddAnim)
        local seen  = {}
        local bY    = 0
        for _, row in ipairs(self.quests) do row:Hide() end

        for i, entry in ipairs(entries or {}) do
            local row = self.quests[i]
            if not row then
                row = self._rowClass(self.body)
                self.quests[i] = row
            end
            row:ClearAllPoints()
			row:AlignParentTop(bY)
			row:FillWidth()
            row:SetQuest(entry.questId, entry)
            row:Show()
            row:_SyncHover(false, entry.level)   -- initial dim-state
            -- Quests flagged as just-accepted (via the watcher's isNew
            -- path) get the shine-sweep on first appearance. Consume the
            -- entry so a second Rebuild in the same session won't replay.
            if pendingAddAnim and pendingAddAnim[entry.questId] then
                row:PlayAddAnim()
                pendingAddAnim[entry.questId] = nil
            end
            bY = bY + row:GetHeight() + QUEST_GAP
            seen[entry.questId] = true
        end

        self.body:SetHeight(bY == 0 and 1 or (bY - QUEST_GAP))
        self:_ApplyCollapsed()
        return seen
    end;

    RefreshFocus = function(self)
        for _, row in ipairs(self.quests) do
            if row:IsShown() then row:RefreshFocus() end
        end
    end;

    -- Locate the currently-visible block bound to `questId`, or nil.
    -- Used by the tracker to play the turn-in anim on the correct row
    -- before the Rebuild removes it.
    FindBlock = function(self, questId)
        for _, row in ipairs(self.quests) do
            if row:IsShown() and row.questId == questId then
                return row
            end
        end
        return nil
    end;

    ToggleCollapsed = function(self)
        self._collapsed = not self._collapsed
        self.collapse:SetExpanded(not self._collapsed)
        self:_ApplyCollapsed()
        if self._OnLayoutChanged then self:_OnLayoutChanged() end
    end;

    _ApplyCollapsed = function(self)
        if self._collapsed then
            self.body:Hide()
            self:SetHeight(SECONDARY_H)
        else
            self.body:Show()
            self:SetHeight(SECONDARY_H + HEADER_QUEST_PAD + math.max(self.body:GetHeight() or 0, 0))
        end
    end;

    IsEmpty = function(self)
        for _, row in ipairs(self.quests) do
            if row:IsShown() then return false end
        end
        return true
    end;
}


-- ---------------------------------------------------------------------
-- QuestTracker: top-level container. PrimaryHeader strip + stack of
-- categories. For v1 we use a single "Quests" category fed from the
-- watcher. A future "Local Quests" (zone-triggered auto-accept quests)
-- category plugs in by adding a second QuestTrackerCategory and
-- partitioning tracked quests between them.
-- ---------------------------------------------------------------------
class "QuestTracker" : extends {"Frame", "Editable"} {
    __init = function(self, watcher)
        Frame.__init(self, "Frame", nil, "MUI_QuestTracker")
        Editable.__init(self)

        self:EditModeSetLabel("Quest Tracker")
        self:EditModeSetupSettings(function(content) end)
        self:EditModeSetDefaultPosition(function() self:_ApplyAnchor() end)
        -- The list grows top→down, so a dragged tracker pins its TOP edge.
        self:EditModeSetDragAnchor("TOPLEFT")

        self:SetSize(WIDTH, PRIMARY_H + 2 * OUTER_PAD)
        self:SetFrameStrata("LOW")
        self:_ApplyAnchor()
        -- Re-anchor whenever any side-bar visibility changes (Blizzard's
        -- MultiActionBar_Update is the single entry point) or on world entry —
        -- but never once the user has moved the tracker in edit mode.
        if MultiActionBar_Update then
            hooksecurefunc("MultiActionBar_Update", function()
                if not self:EditModeIsMoved() then self:_ApplyAnchor() end
            end)
        end
        self:RegisterEventHandler("PLAYER_ENTERING_WORLD",
            function() if not self:EditModeIsMoved() then self:_ApplyAnchor() end end)

        -- Re-anchor when the durability frame appears/disappears so the tracker
        -- docks under it (or back under the minimap) — see _ApplyAnchor.
        if DurabilityFrame then
            local function reanchor() if not self:EditModeIsMoved() then self:_ApplyAnchor() end end
            Frame(DurabilityFrame):HookScript("OnShow", reanchor)
            Frame(DurabilityFrame):HookScript("OnHide", reanchor)
        end

        -- Defeat Blizzard's tracker by auto-untracking everything it
        -- puts on its watch list — the native tracker renders from that
        -- list, so keeping it empty keeps the frame empty. Runs once at
        -- init and on every QUEST_WATCH_LIST_CHANGED / QUEST_LOG_UPDATE
        -- so fresh accepts (which Blizzard auto-watches) get removed
        -- before a frame of native chrome can render.
        --
        -- MUI's own tracker uses `MUI_QuestHelper:IsTracked(questId)`
        -- which is a separate opt-out state stored in MUI_DB — the
        -- Blizzard watch list being empty has no effect on what MUI
        -- shows.
        local function _clearNativeWatches()
            if C_QuestLog and C_QuestLog.GetNumQuestWatches
                          and C_QuestLog.RemoveQuestWatch
                          and C_QuestLog.GetQuestIDForQuestWatchIndex then
                for i = (C_QuestLog.GetNumQuestWatches() or 0), 1, -1 do
                    local qid = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
                    if qid then C_QuestLog.RemoveQuestWatch(qid) end
                end
            elseif GetNumQuestWatches and RemoveQuestWatch
                   and GetQuestIndexForWatch then
                for i = (GetNumQuestWatches() or 0), 1, -1 do
                    local logIdx = GetQuestIndexForWatch(i)
                    if logIdx then RemoveQuestWatch(logIdx) end
                end
            end
        end
        self:RegisterEventHandler("QUEST_WATCH_LIST_CHANGED",
            function() _clearNativeWatches() end)
        self:RegisterEventHandler("QUEST_LOG_UPDATE",
            function() _clearNativeWatches() end)
        _clearNativeWatches()

        self.watcher    = watcher
        self._collapsed = false

        self.primary = Frame("Frame", self, "MUI_QuestTracker_Primary")
        self.primary:SetHeight(PRIMARY_H)
        self.primary:ClearAllPoints()
        self.primary:FillWidth()
		self.primary:AlignParentTop()

        self.primaryBg = Texture(self.primary, nil, "BACKGROUND")
        self.primaryBg:SetAtlas(MUI_AtlasRegistry.QuestTracker,
            "PrimaryHeader", true)
        self.primaryBg:ClearAllPoints()
        self.primaryBg:SetAllPoints(self.primary)

        self.primaryCollapse = QuestTrackerCollapseBtn(self.primary,
            "MUI_QuestTracker_PrimaryCollapse", "primary", 16)
		self.primaryCollapse:SetSize(17, 17)
        self.primaryCollapse:ClearAllPoints()
        self.primaryCollapse:AlignRight(self.primary, 0)
        self.primaryCollapse.OnClick = function() self:ToggleCollapsed() end

        self.primaryLabel = FontString(self.primary, nil, "OVERLAY")
        self.primaryLabel:SetFont(MUI.FONT, 13)
        self.primaryLabel:SetShadowOffset(1, -1)
        self.primaryLabel:SetTextColor(1, 0.82, 0, 1)
        self.primaryLabel:SetJustifyH("LEFT")
        self.primaryLabel:ClearAllPoints()
		self.primaryLabel:AlignParentLeft(24)
		self.primaryLabel:LeftOf(self.primaryCollapse)
        self.primaryLabel:SetText("All Objectives")

        self.questsCategory = QuestTrackerCategory(self,
            "MUI_QuestTracker_Quests", "Quests")
        self.questsCategory._OnLayoutChanged = function() self:_Restack() end

        -- Tracked achievements: fed once the achievement engine is up
        -- (SetAchievementEngine), redrawn as its tallies move.
        self.achievementCategory = QuestTrackerCategory(self,
            "MUI_QuestTracker_Achievements", "Achievements", QuestTrackerAchievement)
        self.achievementCategory._OnLayoutChanged = function() self:_Restack() end
        self._pendingAchievementAnim = {}

        -- Tracked recipes: redrawn on every bag change for the reagent counts.
        self.professionCategory = QuestTrackerCategory(self,
            "MUI_QuestTracker_Profession", "Profession", QuestTrackerRecipe)
        self.professionCategory._OnLayoutChanged = function() self:_Restack() end
        -- A newly tracked recipe gets the add shine, an untracked one the
        -- farewell sweep + fade before its block goes.
        self._pendingRecipeAnim = {}
        MUI_RecipeTracker:RegisterCallback(function(spellID, tracked)
            if tracked then
                self._pendingRecipeAnim[spellID] = true
            else
                local block = self.professionCategory:FindBlock(spellID)
                if block then
                    block:PlayTurnInAnim(function() self:Rebuild() end)
                    return
                end
            end
            self:Rebuild()
        end)
        self:RegisterEventHandler("BAG_UPDATE_DELAYED", function()
            self:_RebuildRecipes()
            self:_Restack()
        end)

        -- Quest IDs accepted live (via QUEST_ACCEPTED → watcher's `isNew`)
        -- that haven't yet played their add-shine. Consumed by
        -- QuestTrackerCategory:SetQuests on the next Rebuild. /reload
        -- re-hydrations arrive with isNew=false so existing quests don't
        -- replay the animation.
        self._pendingAddAnim = {}

        -- Track-order: monotonically-increasing counter assigned the
        -- moment a quest becomes tracked (either freshly accepted or
        -- toggled untracked → tracked from the QuestLog). Rebuild sorts
        -- quests with an order DESCENDING (newest first), so freshly
        -- tracked quests land at the top of the tracker. Pre-existing
        -- tracked quests at /reload have no order and fall to the
        -- bottom in logIndex order.
        self._trackOrder    = {}
        self._nextTrackOrd  = 0
        local function bumpOrder(qid)
            self._nextTrackOrd = self._nextTrackOrd + 1
            self._trackOrder[qid] = self._nextTrackOrd
        end

        watcher:RegisterCallback("OnQuestAdded", function(questId, _, isNew)
            if isNew then
                self._pendingAddAnim[questId] = true
                bumpOrder(questId)
            end
            self:Rebuild()
        end)
        watcher:RegisterCallback("OnQuestRemoved", function(questId, reason)
            self._pendingAddAnim[questId] = nil
            self._trackOrder[questId] = nil
            -- Real turn-in plays the farewell sweep + block fade before
            -- the block disappears. Abandons remove instantly (no
            -- animation — the player explicitly dismissed the quest).
            if reason == "turned_in" then
                local block = self.questsCategory:FindBlock(questId)
                if block then
                    block:PlayTurnInAnim(function() self:Rebuild() end)
                    return
                end
            end
            self:Rebuild()
        end)
        watcher:RegisterCallback("OnQuestChanged", function() self:Rebuild() end)
        MUI_QuestHelper:RegisterTrackingListener(function(questId, tracked)
            -- Treat untracked → tracked as a "fresh appearance" so the
            -- shine sweep + POI pulse fire when re-tracking from the
            -- map's quest log (or anywhere else). Same _pendingAddAnim
            -- table the watcher's QUEST_ACCEPTED path uses, plus a
            -- track-order bump so the re-tracked quest jumps to the top.
            if questId then
                if tracked then
                    self._pendingAddAnim[questId] = true
                    bumpOrder(questId)
                else
                    self._trackOrder[questId] = nil
                end
            end
            self:Rebuild()
        end)
        MUI_FocusManager:RegisterChangeListener(function() self:RefreshFocus() end)

        -- Quest item buttons: pooled secure buttons outside the tracker's
        -- frame tree (see QuestTrackerItemButton), seated against the blocks
        -- every frame by an always-running driver so they follow rebuilds,
        -- collapse, edit-mode drags and scale.
        self._itemButtons = {}
        self._itemsDirty  = true
        self._itemDriver  = Frame("Frame", nil, "MUI_QuestTrackerItemDriver")
        self._itemDriver:SetScript("OnUpdate", function(_, elapsed) self:_SyncItemButtons(elapsed) end)
        local function markItemsDirty() self._itemsDirty = true end
        self._itemDriver:RegisterEventHandler("BAG_UPDATE",           markItemsDirty)
        self._itemDriver:RegisterEventHandler("PLAYER_REGEN_ENABLED", markItemsDirty)
        self._itemDriver:RegisterEventHandler("QUEST_LOG_UPDATE",     markItemsDirty)
        -- Cooldowns stay live in combat: the swipe isn't protected, unlike the
        -- re-binding the dirty pass does out of combat. SPELL_UPDATE_COOLDOWN
        -- adds the global cooldown, as on the action bars.
        local function updateCooldowns()
            for _, btn in ipairs(self._itemButtons) do
                if btn:IsShown() then btn:UpdateCooldown() end
            end
        end
        self._itemDriver:RegisterEventHandler("BAG_UPDATE_COOLDOWN",   updateCooldowns)
        self._itemDriver:RegisterEventHandler("SPELL_UPDATE_COOLDOWN", updateCooldowns)
        self._itemDriver:RegisterEventHandler("PLAYER_TARGET_CHANGED", function()
            for _, btn in ipairs(self._itemButtons) do btn.rangeTimer = 0 end
        end)

        self:Rebuild()
    end;

    ToggleCollapsed = function(self)
        self._collapsed = not self._collapsed
        self.primaryCollapse:SetExpanded(not self._collapsed)
        self:_Restack()
    end;

    -- Anchor: top follows the minimap's bottom, right edge hugs the
    -- leftmost visible side multibar (MultiBarLeft first, then
    -- MultiBarRight, finally UIParent's right with a padded inset when
    -- both side bars are off). Two SetPoints each addressing a separate
    -- edge so the vertical minimap anchor and the horizontal sidebar
    -- anchor don't collide — size stays fixed via SetSize.
    _ApplyAnchor = function(self)
        self:ClearAllPoints()
        -- Dock under the durability ("equipment broken") frame when it's showing,
        -- otherwise under the minimap.
        if DurabilityFrame and DurabilityFrame:IsShown() then
            self:Below(DurabilityFrame, 5, 0)
        else
            self:Below(Minimap, 24, 0)
        end
        if MUI_ModuleActionBars.bars.MULTIBAR4:IsShown() then
            self:LeftOf(MUI_ModuleActionBars.bars.MULTIBAR4, 8, 0)
        elseif MUI_ModuleActionBars.bars.MULTIBAR3:IsShown() then
            self:LeftOf(MUI_ModuleActionBars.bars.MULTIBAR3, 8, 0)
        else
            self:AlignParentRight(14, 0)
        end
    end;

    -- The achievement engine comes up after the tracker; from here on it
    -- feeds the Achievements category. A newly tracked achievement gets the
    -- add shine, an untracked one the farewell before its block goes, and
    -- the lines redraw a moment after the engine's progress moves.
    SetAchievementEngine = function(self, engine)
        self.achievementEngine = engine
        engine:RegisterTrackListener(function(id, tracked)
            if tracked then
                self._pendingAchievementAnim[id] = true
            elseif id then
                local block = self.achievementCategory:FindBlock(id)
                if block then
                    block:PlayTurnInAnim(function() self:Rebuild() end)
                    return
                end
            end
            self:Rebuild()
        end)
        engine:RegisterDirty(function()
            if self._achievementsQueued then return end
            self._achievementsQueued = true
            C_Timer.After(0.2, function()
                self._achievementsQueued = false
                self:_RebuildAchievements()
                self:_Restack()
            end)
        end)
        self:Rebuild()
    end;

    Rebuild = function(self)
        local tracked = {}
        for _, entry in pairs(self.watcher:GetWatched()) do
            if MUI_QuestHelper:IsTracked(entry.questId) then
                tracked[#tracked + 1] = entry
            end
        end
        -- Quests with a track-order (assigned the moment they became
        -- tracked — either via QUEST_ACCEPTED isNew or via SetTracked
        -- toggling untracked → tracked) sort first, newest at the top.
        -- Pre-existing tracked quests from /reload have no track-order
        -- and fall to the bottom in logIndex order, preserving the
        -- prior behaviour.
        local order = self._trackOrder
        table.sort(tracked, function(a, b)
            local oa, ob = order[a.questId], order[b.questId]
            if oa and ob then return oa > ob end
            if oa then return true end
            if ob then return false end
            return (a.logIndex or 0) < (b.logIndex or 0)
        end)

        self.questsCategory:SetQuests(tracked, self._pendingAddAnim)
        self:_RebuildAchievements()
        self:_RebuildRecipes()
        self._itemsDirty = true
        self:_Restack()
    end;

    -- Tracked achievements as rows (retail's AchievementObjectiveTracker):
    -- the unfinished criteria, a bar as "cur/max label", five at most and
    -- then "...", or the description when there is nothing to list.
    _RebuildAchievements = function(self)
        local engine = self.achievementEngine
        local entries = {}
        for _, id in ipairs(engine and engine:GetTracked() or {}) do
            local _, name, _, _, _, _, _, desc = engine:GetInfo(id)
            local rows = engine:GetCriteria(id) or {}
            local objectives, shown = {}, 0
            for _, row in ipairs(rows) do
                if row.done or shown > MAX_ACHIEVEMENT_CRITERIA then
                    -- not shown
                elseif shown == MAX_ACHIEVEMENT_CRITERIA and #rows > MAX_ACHIEVEMENT_CRITERIA + 1 then
                    objectives[#objectives + 1] = { text = "...", noDash = true }
                    shown = shown + 1
                else
                    local text = row.label
                    if row.bar then text = row.bar.text:gsub(" / ", "/") .. " " .. text end
                    objectives[#objectives + 1] = { text = text }
                    shown = shown + 1
                end
            end
            if #objectives == 0 then objectives[1] = { text = desc } end
            entries[#entries + 1] = { questId = id, title = name, objectives = objectives }
        end
        self.achievementCategory:SetQuests(entries, self._pendingAchievementAnim)
    end;

    -- Tracked recipes as rows: one objective per reagent, met when the bags
    -- hold enough (retail: "have/need Name", checked when met).
    _RebuildRecipes = function(self)
        local entries = {}
        for _, recipe in ipairs(MUI_RecipeTracker:GetAll()) do
            local objectives = {}
            for i, reagent in ipairs(recipe.reagents) do
                local have = reagent.itemID and C_Item.GetItemCount(reagent.itemID) or 0
                local need = reagent.count or 0
                local name = reagent.name or (reagent.itemID and C_Item.GetItemInfo(reagent.itemID)) or ""
                objectives[i] = { text = string.format("%d/%d %s", have, need, name), finished = have >= need }
            end
            entries[#entries + 1] = { questId = recipe.spellID, title = recipe.name, objectives = objectives }
        end
        self.professionCategory:SetQuests(entries, self._pendingRecipeAnim)
    end;

    -- Stack the non-empty categories under the primary header.
    _Restack = function(self)
        local n = #MUI_RecipeTracker:GetAll()
        if self.achievementEngine then n = n + #self.achievementEngine:GetTracked() end
        for _, entry in pairs(self.watcher:GetWatched()) do
            if MUI_QuestHelper:IsTracked(entry.questId) then n = n + 1 end
        end
        if n == 0 then self:Hide(); return end

        self:Show()
        local categories = { self.questsCategory, self.achievementCategory, self.professionCategory }
        if self._collapsed then
            for _, category in ipairs(categories) do category:Hide() end
            self:SetHeight(PRIMARY_H)
            return
        end

        local h, last = PRIMARY_H, self.primary
        for _, category in ipairs(categories) do
            if category:IsEmpty() then
                category:Hide()
            else
                category:Show()
                category:ClearAllPoints()
                category:Below(last, CATEGORY_GAP)
                category:SetWidth(WIDTH)
                h = h + CATEGORY_GAP + (category:GetHeight() or 0)
                last = category
            end
        end
        self:SetHeight(h + OUTER_PAD)
    end;

    -- One pooled item button per visible block with a quest item, top to
    -- bottom (MUI_QuestItemButton1 is always the topmost, so it can be
    -- driven from a macro with /click). Binding, geometry and show / hide
    -- only out of combat: the buttons are protected frames. Cooldown / range
    -- indicators stay live in combat.
    _SyncItemButtons = function(self, elapsed)
        local locked = InCombatLockdown()
        local used = 0
        if self:IsVisible() then
            local scale = self:GetScale()
            for _, row in ipairs(self.questsCategory.quests) do
                -- a dirty pass re-reads each item at the quest's live log index
                if self._itemsDirty and not locked and row:IsVisible() then row:RefreshItem() end
                if row.itemLink and row:IsVisible() then
                    used = used + 1
                    local btn = self._itemButtons[used]
                    if not btn and not locked then
                        btn = QuestTrackerItemButton("MUI_QuestItemButton" .. used)
                        btn:SetFrameLevel(self:GetFrameLevel() + 10)
                        self._itemButtons[used] = btn
                    end
                    if btn then
                        if not locked then
                            if self._itemsDirty or btn.questId ~= row.questId then
                                btn:SetItem(row.questId, row.logIndex, row.itemLink, row.itemIcon)
                            end
                            -- Centred on the entry's text: title top through the last
                            -- objective line (the block's own edges carry padding).
                            local right = row:GetRight()
                            local textTop, textBottom = row.title:GetTop(), row.objContainer:GetBottom()
                            if right and textTop and textBottom then
                                btn:Seat(scale, right, (textTop + textBottom + ITEM_BTN_SIZE) / 2)
                            end
                            if not btn:IsShown() then btn:Show() end
                        end
                        if btn:IsShown() then btn:UpdateRange(elapsed) end
                    end
                end
            end
        end
        if not locked then
            for i = used + 1, #self._itemButtons do
                local btn = self._itemButtons[i]
                if btn:IsShown() then btn:Hide() end
                btn.questId = nil
            end
            self._itemsDirty = false
        end
    end;

    RefreshFocus = function(self)
        self.questsCategory:RefreshFocus()
    end;
}
