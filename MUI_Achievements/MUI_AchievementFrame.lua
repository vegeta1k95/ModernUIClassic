-- MUI_AchievementFrame: retail's achievements panel (Blizzard_AchievementUI)
-- rebuilt over our engine — Era has no AchievementFrame to reskin.
--
-- Chrome and geometry are retail's: a 768x500 window, wood corners over
-- metal rails, the parchment category rail on the left (175 wide), the
-- achievement list on the right (504 wide), the floating header plate with
-- the points shield, two tabs along the bottom. Rows follow
-- AchievementTemplate: collapsed 84 high, expanding to show the objectives
-- pane (progress bars first, then check-mark criteria in columns, then meta
-- members two-up; a completed progressive achievement shows its chain as a
-- strip of minis instead). Art is retail's UI-Achievement-* family shipped
-- in assets/textures/achievements.
--
--   AchievementWindow(engine)     the window; Toggle(), Open(id)
--     AchievementTab              bottom tab (Achievements / Statistics)
--     AchievementCategoryRow      rail entry
--     AchievementRow              list entry
--     AchievementRowHighlight     the 8-piece hover glow rows share the look of
--     AchievementObjectives       the one shared objectives pane
--     AchievementSummary          the Summary page: recent earns, category bars
--     AchievementSearch           the header's search box, preview and results
--     AchievementStatistics       the Statistics tab's rows

local TEX = MUI.TEX_BASE .. "achievements\\"
local function Art(name) return TEX .. "ui-achievement-" .. name end

local FRAME_W, FRAME_H       = 700, 500
-- The window is drawn at 694x450, retail's 768x500 layout at nine tenths:
-- every length inside is retail's number times S.
local S                      = 0.9
local CATS_W                 = 175 * S
local CAT_ROW_H              = 24 * S
local ROW_COLLAPSED_H        = 84 * S
-- the Track checkbox: its top in the row, and the least an expanded row
-- can be for it to clear the bottom border
local TRACK_TOP              = 71 * S
local TRACK_H                = 13
local MIN_EXPANDED_H         = TRACK_TOP + TRACK_H + 12 * S
local ROW_ART_H              = 84       -- the parchment texels a collapsed row shows
local DESCRIPTION_H          = 20 * S
local DESCRIPTION_FONT       = 11      -- AchievementDescriptionFont, before S
local CRITERIA_ROW_H         = 15 * S
local META_ROW_H             = 28 * S
local MAXCONTENTWIDTH        = 330 * S
local CRITERIACHECKWIDTH     = 20 * S
local FORCE_COLUMNS_MAX_WIDTH    = 220 * S
local FORCE_COLUMNS_MIN_CRITERIA = 20
local FORCE_COLUMNS_LEFT_OFFSET  = -10 * S
local FORCE_COLUMNS_RIGHT_OFFSET = 24 * S
local PROGRESSIVE_H, PROGRESSIVE_W = 50 * S, 42 * S
local MAX_LINES_COLLAPSED    = 3
local STAT_ROW_H             = 24 * S

-- title bar bands on UI-Achievement-Borders
local TITLEBAR_DONE = { 0, 0.9765625, 0.66015625, 0.73828125 }
local TITLEBAR_TODO = { 0, 0.9765625, 0.91796875, 0.99609375 }
-- account-wide achievements: the blue header (AccountLevel-AchievementHeader)
local ACCOUNT_HEADER = TEX .. "accountlevel-achievementheader"
local ACCOUNT_DONE   = { 0, 1, 0, 0.375 }
local ACCOUNT_TODO   = { 0, 1, 0.40625, 0.78125 }
local GOLD_BORDER   = { 1, 0.675, 0.125 }
local RED_BORDER    = { 0.7, 0.15, 0.05 }
local BLUE_BORDER   = { 0.129, 0.671, 0.875 }

-- The title bar's art for an achievement: the account-wide blue or the
-- character red, saturated or not.
local function TitleBarArt(account, saturated)
    if account then return ACCOUNT_HEADER, saturated and ACCOUNT_DONE or ACCOUNT_TODO end
    return Art("borders"), saturated and TITLEBAR_DONE or TITLEBAR_TODO
end
local TOOLTIP_BORDER = {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 * S,
    insets = { left = 4 * S, right = 4 * S, top = 4 * S, bottom = 4 * S },
}
local REP_HIGHLIGHT = "Interface\\PaperDollInfoFrame\\UI-Character-ReputationBar-Highlight"

-- Retail's AchievementMenuOpen / Close kits; Era's client lacks the files,
-- so they ship with the addon and play by path.
local SOUNDS = "Interface\\AddOns\\ModernUI\\assets\\sounds\\"
local SOUND_OPEN  = SOUNDS .. "achievementmenuopen.ogg"
local SOUND_CLOSE = SOUNDS .. "achievementmenuclose.ogg"

-- A texture of a file, with texcoords.
local function Tex(parent, layer, file, coords, sublevel)
    local t = Texture(parent, nil, layer)
    if sublevel then t:SetDrawLayer(layer, sublevel) end
    if file then t:SetTexture(file) end
    if coords then t:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end
    return t
end

-- Friz at retail's `size` times S, coloured, with the usual drop shadow
-- (off a font object: that is how the shadow renders here).
local function Label(parent, size, r, g, b, layer)
    local fs = FontString(parent, nil, layer or "OVERLAY", MUI.FontBySize(size * S))
    fs:SetTextColor(r, g, b, 1)
    return fs
end

local function ShortDate(month, day, year)
    return string.format("%d/%d/%02d", day, month, year % 100)
end

-- Retail's AchivementGoldBorderBackdrop: the tooltip nine-slice in gold with
-- no fill, filling `parent`, a level above where a child would sit so it
-- rides over the parent's art.
local function GoldBorder(parent)
    local b = Frame("Frame", parent, nil, "TooltipBackdropTemplate")
    b:FillParent()
    b:SetBackdropColor(0, 0, 0, 0)
    b:SetBackdropBorderColor(GOLD_BORDER[1], GOLD_BORDER[2], GOLD_BORDER[3])
    b:SetFrameLevel(b:GetFrameLevel() + 1)
    return b
end

-- One of retail's UI-Frame border atlases on `parent`, tiling along its run.
local function FramePiece(parent, atlasName, sublevel)
    local t = Texture(parent, nil, "BORDER")
    if sublevel then t:SetDrawLayer("BORDER", sublevel) end
    t:SetBlizzardAtlas(atlasName, true)
    if atlasName:find("^_") then t:SetHorizTile(true) end
    if atlasName:find("^!") then t:SetVertTile(true) end
    return t
end


-- ---------------------------------------------------------------------
-- AchievementRowHighlight: the hover glow (ReputationBar-Highlight cut
-- into corners, edges and sides, additive).
-- ---------------------------------------------------------------------
class "AchievementRowHighlight" : extends "Frame" {
    __init = function(self, parent)
        Frame.__init(self, "Frame", parent)
        self:FillParent()
        self:EnableMouse(false)
        self:Hide()

        local function piece(coords)
            local t = Tex(self, "OVERLAY", REP_HIGHLIGHT, coords)
            t:SetBlendMode("ADD")
            return t
        end
        local tl = piece({ 0.06640625, 0, 0.4375, 0.65625 })
        tl:SetSize(16 * S, 16 * S)
        tl:AlignParentTopLeft(-2 * S, -1 * S)
        local bl = piece({ 0.06640625, 0, 0.65625, 0.4375 })
        bl:SetSize(16 * S, 16 * S)
        bl:AlignParentBottomLeft(-2 * S, -1 * S)
        local tr = piece({ 0, 0.06640625, 0.4375, 0.65625 })
        tr:SetSize(16 * S, 16 * S)
        tr:AlignParentTopRight(-2 * S, -1 * S)
        local br = piece({ 0, 0.06640625, 0.65625, 0.4375 })
        br:SetSize(16 * S, 16 * S)
        br:AlignParentBottomRight(-2 * S, -1 * S)
        local top = piece({ 0, 0.015, 0.4375, 0.65625 })
        top:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
        top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT", 0, 0)
        local bottom = piece({ 0, 0.015, 0.65625, 0.4375 })
        bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
        local left = piece({ 0.06640625, 0, 0.65625, 0.6 })
        left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
        left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT", 0, 0)
        local right = piece({ 0, 0.06640625, 0.65625, 0.6 })
        right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT", 0, 0)
        right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
    end;
}


-- ---------------------------------------------------------------------
-- AchievementTab: a bottom tab (AchievementFrameTabButtonTemplate) — the
-- dimmed 49-high set when inactive, the full 59-high set when selected,
-- its own three hover pieces.
-- ---------------------------------------------------------------------
class "AchievementTab" : extends "Frame" {
    __init = function(self, parent, text, onClick)
        Frame.__init(self, "Frame", parent)
        self:SetSize(115 * S, 32 * S)
        self:EnableMouse(true)

        self._inactive = self:_Pieces(49, 0)
        self._active   = self:_Pieces(59, 1)
        for _, t in ipairs(self._inactive) do t:SetVertexColor(0.6, 0.6, 0.6) end

        self.label = Label(self, 10, 1, 0.82, 0)
        self.label:CenterInParent(0, -3 * S)
        self.label:SetText(text)
        self:SetWidth(math.max(78 * S, self.label:GetStringWidth() + 50 * S))

        local function hover(coords, w)
            local t = Tex(self, "HIGHLIGHT", Art("header"), coords)
            t:SetBlendMode("ADD")
            t:SetSize(w * S, 49 * S)
            return t
        end
        local l = hover({ 0.720703125, 0.783203125, 0.76953125, 1 }, 32)
        l:SetPoint("TOPLEFT", self._inactive[1], "TOPLEFT", -3 * S, 0)
        local r = hover({ 0.923828125, 0.986328125, 0.76953125, 1 }, 18)
        r:SetPoint("TOPRIGHT", self._inactive[3], "TOPRIGHT", 0, 0)
        local m = hover({ 0.783203125, 0.923828125, 0.76953125, 1 }, 88)
        m:RightOf(l)
        m:LeftOf(r)
        self._hover = { l, m, r }

        self:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and not self._selected and self:IsMouseOver() then
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
                onClick()
            end
        end)
    end;

    _Pieces = function(self, height, sublevel)
        local function piece(coords, w)
            local t = Tex(self, "BACKGROUND", Art("header"), coords, sublevel)
            t:SetSize(w * S, height * S)
            return t
        end
        local l = piece({ 0.47265625, 0.513671875, 0.76953125, 1 }, 21)
        l:AlignParentTopLeft(0, -4 * S)
        local r = piece({ 0.685546875, 0.720703125, 0.76953125, 1 }, 18)
        r:AlignParentTopRight(0, -4 * S)
        local m = piece({ 0.513671875, 0.685546875, 0.76953125, 1 }, 88)
        m:RightOf(l)
        m:LeftOf(r)
        return { l, m, r }
    end;

    SetSelected = function(self, selected)
        self._selected = selected
        for _, t in ipairs(self._active)   do t:SetVisible(selected) end
        for _, t in ipairs(self._inactive) do t:SetVisible(not selected) end
        for _, t in ipairs(self._hover)    do t:SetVisible(not selected) end
        self.label:ClearAllPoints()
        self.label:CenterInParent(0, (selected and -5 or -3) * S)
        if selected then
            self.label:SetTextColor(1, 1, 1, 1)
        else
            self.label:SetTextColor(1, 0.82, 0, 1)
        end
    end;
}


-- ---------------------------------------------------------------------
-- AchievementCategoryRow: an entry of the category rail
-- (AchievementCategoryTemplate). A sub-category's button is narrower,
-- so it sits indented on both sides, white on a dimmed plate. Hovering
-- an achievement category shows its progress; clicking selects it.
-- ---------------------------------------------------------------------
class "AchievementCategoryRow" : extends "Frame" {
    __init = function(self, parent, owner, cat)
        Frame.__init(self, "Frame", parent)
        self:SetSize(CATS_W - (cat.parent and 25 or 10) * S, CAT_ROW_H)
        self:EnableMouse(true)
        self.cat = cat

        local bg = Tex(self, "BACKGROUND", Art("category-background"), { 0, 0.6640625, 0, 1 })
        bg:SetHeight(32 * S)
        bg:AlignParentTopLeft()
        bg:AlignParentTopRight()
        if cat.parent then bg:SetVertexColor(0.6, 0.6, 0.6) end

        self.label = Label(self, 12, 1, 0.82, 0, "ARTWORK")
        self.label:SetJustifyH("LEFT")
        self.label:SetJustifyV("BOTTOM")
        self.label:SetWordWrap(false)
        self.label:AlignParentBottomLeft(4 * S, 16 * S)
        self.label:AlignParentTopRight(4 * S, 8 * S)
        self.label:SetText(cat.name)
        self:SetSelected(false)

        local hl = Tex(self, "HIGHLIGHT", Art("category-highlight"), { 0, 0.6640625, 0, 1 })
        hl:SetBlendMode("ADD")
        hl:AlignParentTopLeft()
        hl:AlignParentBottomRight(-7 * S, 1 * S)

        self:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and self:IsMouseOver() then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
                if cat.stats then owner:SelectStatCategory(cat.id) else owner:SelectCategory(cat.id) end
            end
        end)
        -- a statistics category has no progress to tell
        if not cat.stats then
            self:SetTooltip("ANCHOR_RIGHT", function(tooltip)
                local total, done = owner:CategoryProgress(cat.id)
                tooltip:AddLine(cat.name, 1, 1, 1, false, 13)
                tooltip:AddLine(done .. " / " .. total, 1, 0.82, 0)
            end)
        end
    end;

    -- GameFontNormal for a category, GameFontHighlight for a sub-category
    -- and for the selection.
    SetSelected = function(self, selected)
        if selected or self.cat.parent then
            self.label:SetTextColor(1, 1, 1, 1)
        else
            self.label:SetTextColor(1, 0.82, 0, 1)
        end
    end;
}


-- ---------------------------------------------------------------------
-- AchievementObjectives: the one objectives pane, parented to whichever
-- row is expanded. Pools of criteria lines, progress bars, meta members
-- and progressive minis (AchievementsObjectivesMixin).
-- ---------------------------------------------------------------------
class "AchievementObjectives" : extends "Frame" {
    __init = function(self, parent, owner)
        Frame.__init(self, "Frame", parent)
        self.owner = owner
        self.criterias, self.bars, self.metas, self.minis = {}, {}, {}, {}
        self:Hide()
    end;

    Clear = function(self)
        for _, pool in ipairs({ self.criterias, self.bars, self.metas, self.minis }) do
            for _, w in ipairs(pool) do w:Hide() end
        end
        self:ClearAllPoints()
        self:SetHeight(0.1)
        self.id = nil
    end;

    -- AchievementCriteriaTemplate: check 20x16 + the criteria's name
    GetCriteria = function(self, i)
        local c = self.criterias[i]
        if not c then
            c = Frame("Frame", self)
            c:SetSize(350 * S, 15 * S)
            c.check = Tex(c, "ARTWORK", Art("criteria-check"), { 0, 0.625, 0, 1 })
            c.check:SetSize(20 * S, 16 * S)
            c.check:AlignParentLeft(0, -3 * S)
            c.name = Label(c, 10, 1, 1, 1)
            c.name:SetHeight(15 * S)
            c.name:RightOf(c.check, 5 * S, 2 * S)
            self.criterias[i] = c
        end
        c:Show()
        return c
    end;

    -- AchievementProgressBarTemplate: 212x14 green bar in a 3-piece border
    GetBar = function(self, i)
        local b = self.bars[i]
        if not b then
            b = StatusBar(self)
            b:SetSize(212 * S, 14 * S)
            b:SetStatusBarColor(0, 0.6, 0, 1)
            b:SetBackgroundColor(0, 0, 0, 0.4)
            b.text = Label(b, 10, 1, 1, 1)
            b.text:CenterInParent()
            local left = Tex(b, "ARTWORK", Art("progressbar-border"), { 0, 0.0625, 0, 0.75 })
            left:SetWidth(16 * S)
            left:AlignParentTopLeft(-5 * S, -6 * S)
            left:AlignParentBottomLeft(-5 * S, -6 * S)
            local right = Tex(b, "ARTWORK", Art("progressbar-border"), { 0.812, 0.8745, 0, 0.75 })
            right:SetWidth(16 * S)
            right:AlignParentTopRight(-5 * S, -6 * S)
            right:AlignParentBottomRight(-5 * S, -6 * S)
            local middle = Tex(b, "ARTWORK", Art("progressbar-border"), { 0.0625, 0.812, 0, 0.75 })
            middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
            middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
            self.bars[i] = b
        end
        b:Show()
        return b
    end;

    -- MetaCriteriaTemplate: 155x30, icon in its progressive border, check, label
    GetMeta = function(self, i)
        local m = self.metas[i]
        if not m then
            m = Frame("Frame", self)
            m:SetSize(155 * S, 30 * S)
            m:EnableMouse(true)
            m.icon = Texture(m, nil, "BACKGROUND")
            m.icon:SetSize(17 * S, 17 * S)
            m.icon:AlignParentTopLeft(6 * S, 6 * S)
            m.border = Tex(m, "BORDER", Art("progressive-iconborder"), { 0, 0.65625, 0, 0.65625 })
            m.border:SetSize(30 * S, 30 * S)
            m.border:AlignParentTopLeft()
            m.check = Tex(m, "ARTWORK", Art("criteria-check"), { 0, 0.65625, 0, 1 })
            m.check:SetSize(20 * S, 16 * S)
            m.check:LeftOf(m)
            m.label = Label(m, 10, 1, 1, 1, "ARTWORK")
            m.label:SetSize(125 * S, 20 * S)
            m.label:SetJustifyH("LEFT")
            m.label:AlignParentLeft(34 * S, 2 * S)
            local hl = Tex(m, "HIGHLIGHT", "Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")
            hl:SetBlendMode("ADD")
            hl:SetVertexColor(1, 1, 1, 0.15)
            hl:AlignParentTopLeft()
            hl:AlignParentBottomRight(-2 * S, 0)
            m:SetScript("OnMouseUp", function(_, button)
                if button == "LeftButton" and m.achId and m:IsMouseOver() then
                    self.owner:SelectAchievement(m.achId)
                end
            end)
            m:SetTooltip("ANCHOR_RIGHT", function(tooltip) self:_MemberTooltip(tooltip, m.achId) end)
            self.metas[i] = m
        end
        m:Show()
        return m
    end;

    -- MiniAchievementTemplate: 42x42 icon in a border, shield and points
    GetMini = function(self, i)
        local m = self.minis[i]
        if not m then
            m = Frame("Frame", self)
            m:SetSize(42 * S, 42 * S)
            m:EnableMouse(true)
            m.icon = Texture(m, nil, "BACKGROUND")
            m.icon:FillParent(8 * S)
            local border = Tex(m, "BORDER", Art("progressive-iconborder"), { 0, 0.65625, 0, 0.65625 })
            border:FillParent()
            m.shield = Tex(m, "ARTWORK", Art("progressive-shield"), { 0, 0.75, 0, 0.75 })
            m.shield:AlignParentTopLeft(12 * S, 12 * S)
            m.shield:AlignParentBottomRight(-16 * S, -16 * S)
            m.points = Label(m, 10, 1, 1, 1)
            m.points:SetSize(18 * S, 18 * S)
            m.points:SetJustifyV("BOTTOM")
            m.points:AlignParentBottomRight(3 * S, 2 * S)
            m:SetTooltip("ANCHOR_RIGHT", function(tooltip) self:_MemberTooltip(tooltip, m.achId) end)
            self.minis[i] = m
        end
        m:Show()
        return m
    end;

    _MemberTooltip = function(self, tooltip, id)
        if not id then return end
        local _, name, _, _, month, day, year, desc = self.owner.engine:GetInfo(id)
        tooltip:AddDoubleLine(name, month and ShortDate(month, day, year) or "", 1, 1, 1, 0.5, 0.5, 0.5)
        tooltip:AddLine(desc, 1, 1, 1, true)
    end;

    -- A completed progressive achievement: its chain as minis, six to a row
    -- (AchievementObjectives_DisplayProgressiveAchievement).
    DisplayProgressive = function(self, id)
        self:Clear()
        local engine = self.owner.engine
        local chain, walk = {}, id
        while walk do
            table.insert(chain, 1, walk)
            walk = engine:GetPrevious(walk)
        end
        for index, aid in ipairs(chain) do
            local _, _, pts, completed, _, _, _, _, iconPath = engine:GetInfo(aid)
            local mini = self:GetMini(index)
            mini.achId = aid
            mini.icon:SetTexture(iconPath)
            mini.icon:SetDesaturated(not completed)
            mini.points:SetText(pts)
            mini:ClearAllPoints()
            if index == 1 then
                mini:AlignParentTopLeft(4 * S, -4 * S)
            elseif math.fmod(index, 6) == 1 then
                mini:SetPoint("TOPLEFT", self:GetMini(index - 6), "BOTTOMLEFT", 0, -8 * S)
            else
                mini:SetPoint("TOPLEFT", self:GetMini(index - 1), "TOPRIGHT", 4 * S, 0)
            end
        end
        local n = #chain
        self:SetHeight(math.ceil(n / 6) * PROGRESSIVE_H)
        self:SetWidth(math.min(n, 6) * PROGRESSIVE_W)
    end;

    -- The criteria of an achievement (AchievementObjectives_DisplayCriteria):
    -- progress bars stacked first, check lines below in as many columns as
    -- fit, meta members two-up under those.
    DisplayCriteria = function(self, id, completed)
        self:Clear()
        local engine = self.owner.engine
        local rows = engine:GetCriteria(id)
        if not rows or #rows == 0 then return end

        -- the width of "- ", for measuring unfinished lines
        if not self._dashWidth then
            local c = self:GetCriteria(1)
            c.name:SetText("- ")
            self._dashWidth = c.name:GetStringWidth()
            c:Hide()
        end

        local textStrings, progressBars, metas = 0, 0, 0
        local numMetaRows, numCriteriaRows = 0, 0
        local firstMeta
        local maxCriteriaWidth = 0

        for _, row in ipairs(rows) do
            if row.meta then
                metas = metas + 1
                local m = self:GetMeta(metas)
                m:ClearAllPoints()
                if metas == 1 then
                    firstMeta = m
                    numMetaRows = numMetaRows + 1
                elseif math.fmod(metas, 2) == 0 then
                    m:RightOf(self:GetMeta(metas - 1), 35 * S)
                else
                    m:SetPoint("TOPLEFT", self:GetMeta(metas - 2), "BOTTOMLEFT", 0, 2 * S)
                    numMetaRows = numMetaRows + 1
                end
                m.achId = row.meta
                local _, name, _, _, _, _, _, _, iconPath = engine:GetInfo(row.meta)
                m.label:SetText(name)
                m.icon:SetTexture(iconPath)
                if row.done then
                    m.check:Show()
                    m.border:SetVertexColor(1, 1, 1, 1)
                    m.icon:SetVertexColor(1, 1, 1, 1)
                    if completed then
                        m.label:SetFontObject(MUI.FontBySize(10 * S, false))
                        m.label:SetTextColor(0, 0, 0, 1)
                    else
                        m.label:SetFontObject(MUI.FontBySize(10 * S))
                        m.label:SetTextColor(0, 1, 0, 1)
                    end
                else
                    m.check:Hide()
                    m.border:SetVertexColor(0.75, 0.75, 0.75, 1)
                    m.icon:SetVertexColor(0.55, 0.55, 0.55, 1)
                    m.label:SetFontObject(MUI.FontBySize(10 * S))
                    m.label:SetTextColor(0.6, 0.6, 0.6, 1)
                end
            elseif row.bar then
                progressBars = progressBars + 1
                local b = self:GetBar(progressBars)
                b:ClearAllPoints()
                if progressBars == 1 then
                    b:AlignParentTop(4 * S, 4 * S)
                else
                    b:Below(self:GetBar(progressBars - 1))
                end
                b.text:SetText(row.bar.text)
                b:SetMinMaxValues(0, row.bar.max)
                b:SetValue(row.bar.cur)
                numCriteriaRows = numCriteriaRows + 1
            else
                textStrings = textStrings + 1
                local c = self:GetCriteria(textStrings)
                c:ClearAllPoints()
                if textStrings == 1 then
                    if #rows == 1 then
                        c:AlignParentTop(0, -14 * S)
                    else
                        c:AlignParentTopLeft()
                    end
                else
                    c:SetPoint("TOPLEFT", self:GetCriteria(textStrings - 1), "BOTTOMLEFT", 0, 0)
                end

                if completed and row.done then
                    c.name:SetFontObject(MUI.FontBySize(10 * S, false))
                    c.name:SetTextColor(0, 0, 0, 1)
                elseif row.done then
                    c.name:SetFontObject(MUI.FontBySize(10 * S))
                    c.name:SetTextColor(0, 1, 0, 1)
                else
                    c.name:SetFontObject(MUI.FontBySize(10 * S))
                    c.name:SetTextColor(0.6, 0.6, 0.6, 1)
                end

                local stringWidth, maxW
                c.name:SetWidth(0)
                c.name:ClearAllPoints()
                c.check:ClearAllPoints()
                if row.done then
                    maxW = MAXCONTENTWIDTH - CRITERIACHECKWIDTH
                    -- the check sits where the "- " of an unfinished line
                    -- is, so the names of both kinds start at the same x
                    c.check:AlignParentLeft(5 * S + self._dashWidth, -3 * S)
                    c.name:RightOf(c.check, 0, 2 * S)
                    c.check:Show()
                    c.name:SetText(row.label)
                    stringWidth = math.min(c.name:GetStringWidth(), maxW)
                else
                    maxW = MAXCONTENTWIDTH - self._dashWidth
                    c.check:AlignParentLeft(0, -3 * S)
                    c.name:RightOf(c.check, 5 * S, 2 * S)
                    c.check:Hide()
                    c.name:SetText("- " .. row.label)
                    stringWidth = math.min(c.name:GetStringWidth() - self._dashWidth, maxW)
                end
                if c.name:GetStringWidth() > maxW then c.name:SetWidth(maxW) end
                c:SetWidth(stringWidth + CRITERIACHECKWIDTH)
                maxCriteriaWidth = math.max(maxCriteriaWidth, stringWidth + CRITERIACHECKWIDTH)
                numCriteriaRows = numCriteriaRows + 1
            end
        end

        if textStrings > 0 and progressBars > 0 then
            -- bars first, lines under them
            local c1 = self:GetCriteria(1)
            c1:ClearAllPoints()
            if textStrings == 1 then
                c1:Below(self:GetBar(progressBars), 4 * S, -14 * S)
            else
                c1:Below(self:GetBar(progressBars), 4 * S)
                c1:AlignParentLeft()
            end
        elseif textStrings > 1 then
            -- two columns at most (retail packs narrow lines three abreast)
            local numColumns = math.min(2, math.floor(MAXCONTENTWIDTH / math.max(maxCriteriaWidth, 1)))
            local forceColumns = false
            if numColumns == 1 and textStrings >= FORCE_COLUMNS_MIN_CRITERIA
                    and maxCriteriaWidth <= FORCE_COLUMNS_MAX_WIDTH then
                numColumns = 2
                forceColumns = true
            end
            if numColumns > 1 then
                local rowN, position = 1, 0
                for i = 1, textStrings do
                    position = position + 1
                    if position > numColumns then
                        position = position - numColumns
                        rowN = rowN + 1
                    end
                    local c = self:GetCriteria(i)
                    c:ClearAllPoints()
                    if rowN == 1 then
                        local xOffset = 0
                        if forceColumns then
                            xOffset = (position == 1) and FORCE_COLUMNS_LEFT_OFFSET or FORCE_COLUMNS_RIGHT_OFFSET
                        end
                        c:AlignParentTopLeft(0, (position - 1) * (MAXCONTENTWIDTH / numColumns) + xOffset)
                    else
                        c:SetPoint("TOPLEFT", self:GetCriteria(position + (rowN - 2) * numColumns), "BOTTOMLEFT", 0, 0)
                    end
                end
                numCriteriaRows = math.ceil(numCriteriaRows / numColumns)
            end
        end

        if firstMeta then
            local y = 8 * S + numCriteriaRows * CRITERIA_ROW_H
            if metas == 1 then
                firstMeta:AlignParentTop(y)
            else
                firstMeta:AlignParentTopLeft(y, 20 * S)
            end
        end

        local height = numMetaRows * META_ROW_H + numCriteriaRows * CRITERIA_ROW_H
        if metas > 0 or progressBars > 0 then height = height + 10 * S end
        self:SetHeight(math.max(height, 0.1))
    end;
}


-- ---------------------------------------------------------------------
-- AchievementRow: one achievement in the list (AchievementTemplate).
-- Collapsed: parchment, title band, icon on its ring, shield with points,
-- three lines of description. Expanded: the full description and the
-- objectives pane. Completed rows are saturated with the red border and
-- the date under the shield; incomplete rows are grey.
-- ---------------------------------------------------------------------
class "AchievementRow" : extends "Frame" {
    __init = function(self, parent, owner)
        Frame.__init(self, "Frame", parent, nil, "BackdropTemplate")
        self.owner = owner
        self:SetHeight(ROW_COLLAPSED_H)
        self:EnableMouse(true)
        self:SetBackdrop(TOOLTIP_BORDER)

        self.background = Tex(self, "BACKGROUND", Art("parchment-horizontal"), { 0, 1, 1 - ROW_ART_H / 256, 1 })
        self.background:FillParent(3 * S)

        self.titleBar = Tex(self, "ARTWORK", Art("borders"), TITLEBAR_DONE)
        self.titleBar:SetHeight(24 * S)
        self.titleBar:AlignParentTopLeft(4 * S, 5 * S)
        self.titleBar:AlignParentTopRight(4 * S, 5 * S)
        self.titleBar:SetAlpha(0.8)

        self.glow = Tex(self, "ARTWORK", Art("borders"), { 0, 1, 0.00390625, 0.25390625 })
        self.glow:SetPoint("TOPLEFT", self.titleBar, "BOTTOMLEFT", 0, 4 * S)
        self.glow:SetPoint("BOTTOMRIGHT", self, "RIGHT", 0, 4 * S)

        -- corner flourishes
        local bl = Tex(self, "BORDER", Art("tsunami-corners"), { 0, 0.5, 0, 1 })
        bl:SetSize(32 * S, 32 * S)
        bl:AlignParentBottomLeft(-2 * S, -2 * S)
        bl:SetAlpha(0.2)
        local br = Tex(self, "BORDER", Art("tsunami-corners"), { 0.5, 1, 0, 1 })
        br:SetSize(32 * S, 32 * S)
        br:AlignParentBottomRight(-2 * S, -2 * S)
        br:SetAlpha(0.2)
        local tl = Tex(self, "BORDER", Art("tsunami-corners"), { 1, 0.5, 1, 0 })
        tl:SetSize(32 * S, 32 * S)
        tl:AlignParentTopLeft(20 * S, -2 * S)
        tl:SetAlpha(0.1)
        local tr = Tex(self, "BORDER", Art("tsunami-corners"), { 0.5, 0, 1, 0 })
        tr:SetSize(32 * S, 32 * S)
        tr:AlignParentTopRight(20 * S, -2 * S)
        tr:SetAlpha(0.1)

        -- icon on its ring
        self.iconFrame = Frame("Frame", self)
        self.iconFrame:SetSize(60 * S, 60 * S)
        self.iconFrame:AlignParentTopLeft(9 * S, 8 * S)
        self.icon = Texture(self.iconFrame, nil, "ARTWORK")
        self.icon:SetSize(50 * S, 50 * S)
        self.icon:CenterInParent(0, 3 * S)
        local ring = Tex(self.iconFrame, "OVERLAY", Art("iconframe"), { 0, 0.5625, 0, 0.5625 })
        ring:SetSize(72 * S, 72 * S)
        ring:CenterInParent(-1 * S, 2 * S)

        -- points shield; its tooltip tells how the achievement was earned
        self.shield = Frame("Frame", self)
        self.shield:SetSize(64 * S, 64 * S)
        self.shield:AlignParentTopRight(0, 6 * S)
        self.shield:EnableMouse(true)
        self.shieldTex = Tex(self.shield, "BACKGROUND", Art("shields"), { 0, 0.5, 0, 0.5 })
        self.shieldTex:SetSize(66 * S, 64 * S)
        self.shieldTex:AlignParentTopRight(6 * S, 0)
        self.points = Label(self.shield, 12, 1, 0.82, 0)
        self.points:SetSize(42 * S, 16 * S)
        self.points:CenterInParent(-2 * S,-3 * S)
        self.dateCompleted = Label(self.shield, 10, 1, 0.82, 0)
        self.dateCompleted:SetSize(100 * S, 14 * S)
        self.dateCompleted:SetJustifyH("CENTER")
        self.dateCompleted:Below(self.shield, -6 * S, -2 * S)
        self.shield:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and self.shield:IsMouseOver() then self:_Click() end
        end)
        self.shield:SetScript("OnEnter", function() self.highlight:Show() end)
        self.shield:SetScript("OnLeave", function()
            if self.achId ~= owner.selectedAch then self.highlight:Hide() end
        end)
        self.shield:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            if not self.completed then return end
            tooltip:AddLine("Completed", 1, 1, 1)
            if self.backfilled then
                tooltip:AddLine("Earned before achievement tracking began.", 0.6, 0.6, 0.6, true)
            end
        end)

        self.label = Label(self, 14, 1, 1, 1)
        self.label:SetSize(320 * S, 20 * S)
        self.label:AlignTop(self.titleBar)

        self.description = Label(self, DESCRIPTION_FONT, 1, 1, 1)
        self.description:AlignParentTop(30 * S)
        self.description:RightOf(self.iconFrame, 8 * S)
        self.description:LeftOf(self.shield, 10 * S)
        self.description:SetJustifyH("CENTER")
        self.description:SetHeight(DESCRIPTION_FONT * S * MAX_LINES_COLLAPSED)

        -- the full-height twin shown while expanded; also measures the text
        self.hiddenDescription = Label(self, DESCRIPTION_FONT, 1, 1, 1)
        self.hiddenDescription:AlignParentTop(30 * S)
        self.hiddenDescription:SetWidth(MAXCONTENTWIDTH)
        self.hiddenDescription:SetJustifyH("CENTER")
        self.hiddenDescription:Hide()

        self.rewardBackground = Tex(self, "ARTWORK", Art("reward-background"), { 0, 0.69, 0, 0.75 })
        self.rewardBackground:SetHeight(24 * S)
        self.rewardBackground:AlignParentBottomLeft(-2 * S, 5 * S)
        self.rewardBackground:AlignParentBottomRight(5 * S, 5 * S)
        self.rewardBackground:Hide()
        self.reward = Label(self, 10, 1, 0.82, 0)
        self.reward:SetSize(355 * S, 20 * S)
        self.reward:AlignTop(self.rewardBackground, -1 * S)
        self.reward:Hide()

        self.plusMinus = Tex(self, "OVERLAY", Art("plusminus"), { 0, 0.5, 0, 0.25 })
        self.plusMinus:SetSize(15 * S, 15 * S)
        self.plusMinus:AlignParentTopLeft(9 * S, 72 * S)
        self.plusMinus:Hide()

        -- tracking: the blue check by the title while tracked, the checkbox
        -- bottom-left while expanded
        self.trackCheck = Tex(self, "OVERLAY", "Interface\\Buttons\\UI-CheckBox-Check")
        self.trackCheck:SetSize(20 * S, 16 * S)
        self.trackCheck:RightOf(self.label, 0, -1 * S)
        self.trackCheck:Hide()

        -- (the minimap tracking menu's checkbox: an 11 px box, 10.5 label)
        self.tracked = CheckBoxThin(self, nil, "Track")
        self.tracked:SetSize(50, 13)
        self.tracked:SetBoxSize(11, 11)
        self.tracked.label:SetFontSize(10.5)
        self.tracked:AlignParentTopLeft(TRACK_TOP, 12 * S)
        self.tracked:Hide()
        self.tracked.OnChanged = function() self:_ToggleTracking() end
        self.tracked:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            tooltip:AddLine(self.tracked:IsChecked() and "Stop tracking this achievement."
                or "Track this achievement on the objectives list.", 1, 1, 1, true)
        end)

        self.highlight = AchievementRowHighlight(self)

        self:SetScript("OnEnter", function() self.highlight:Show() end)
        self:SetScript("OnLeave", function()
            if self.achId ~= owner.selectedAch then self.highlight:Hide() end
        end)
        self:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and self:IsMouseOver() then self:_Click() end
        end)
    end;

    -- Modified clicks first: the name into chat, or the tracking toggle;
    -- a plain click expands or collapses.
    _Click = function(self)
        if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() then
            local _, name = self.owner.engine:GetInfo(self.achId)
            ChatEdit_InsertLink("[" .. (name or "") .. "]")
            return
        end
        if IsModifiedClick("QUESTWATCHTOGGLE") then
            self:_ToggleTracking()
            return
        end
        self.owner:SelectAchievement(self.achId == self.owner.selectedAch and nil or self.achId)
    end;

    _ToggleTracking = function(self)
        local engine, id = self.owner.engine, self.achId
        if engine:IsTracked(id) then
            engine:Untrack(id)
            self:SetTracked(false)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            return
        end
        local ok, reason = engine:Track(id)
        if not ok then
            UIErrorsFrame:AddMessage(reason == "max" and "You may only track 10 achievements at a time."
                or "You may not track completed achievements.", 1, 0.1, 0.1, 1)
            self:SetTracked(false)
            return
        end
        self:SetTracked(true)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end;

    SetTracked = function(self, tracked)
        self.trackCheck:SetVisible(tracked)
        self.tracked:SetChecked(tracked)
    end;

    -- The plus/minus glyph's quadrant: collapsed/expanded × saturated/grey.
    _UpdatePlusMinus = function(self)
        if not (self.hasObjectives or (self.completed and self.prev)) then
            self.plusMinus:Hide()
            return
        end
        self.plusMinus:Show()
        if self.collapsed and self.saturated then
            self.plusMinus:SetTexCoord(0, 0.5, 0, 0.25)
        elseif self.collapsed then
            self.plusMinus:SetTexCoord(0.5, 1, 0, 0.25)
        elseif self.saturated then
            self.plusMinus:SetTexCoord(0, 0.5, 0.25, 0.5)
        else
            self.plusMinus:SetTexCoord(0.5, 1, 0.25, 0.5)
        end
    end;

    _Saturate = function(self)
        self.saturated = true
        self.background:SetTexture(Art("parchment-horizontal"))
        local file, coords = TitleBarArt(self.account, true)
        self.titleBar:SetTexture(file)
        self.titleBar:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        local border = self.account and BLUE_BORDER or RED_BORDER
        self:SetBackdropBorderColor(border[1], border[2], border[3])
        self.glow:SetVertexColor(1, 1, 1)
        self.icon:SetDesaturated(false)
        self.shieldTex:SetTexCoord(0, 0.5, 0, 0.5)
        self.points:SetTextColor(1, 0.82, 0, 1)
        self.label:SetTextColor(1, 1, 1, 1)
        -- ink on parchment: no shadow
        self.description:SetFontObject(MUI.FontBySize(DESCRIPTION_FONT * S, false))
        self.description:SetTextColor(0, 0, 0, 1)
        self.hiddenDescription:SetFontObject(MUI.FontBySize(DESCRIPTION_FONT * S, false))
        self.hiddenDescription:SetTextColor(0, 0, 0, 1)
        self.reward:SetTextColor(1, 0.82, 0, 1)
        self:_UpdatePlusMinus()
    end;

    _Desaturate = function(self)
        self.saturated = false
        self.background:SetTexture(Art("parchment-horizontal-desaturated"))
        local file, coords = TitleBarArt(self.account, false)
        self.titleBar:SetTexture(file)
        self.titleBar:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        self:SetBackdropBorderColor(0.5, 0.5, 0.5)
        self.glow:SetVertexColor(0.22, 0.17, 0.13)
        self.icon:SetDesaturated(true)
        self.shieldTex:SetTexCoord(0.5, 1, 0, 0.5)
        self.points:SetTextColor(0.65, 0.65, 0.65, 1)
        self.label:SetTextColor(0.65, 0.65, 0.65, 1)
        self.description:SetFontObject(MUI.FontBySize(DESCRIPTION_FONT * S))
        self.description:SetTextColor(1, 1, 1, 1)
        self.hiddenDescription:SetFontObject(MUI.FontBySize(DESCRIPTION_FONT * S))
        self.hiddenDescription:SetTextColor(1, 1, 1, 1)
        self.reward:SetTextColor(0.8, 0.8, 0.8, 1)
        self:_UpdatePlusMinus()
    end;

    _Collapse = function(self)
        self.collapsed = true
        self:_UpdatePlusMinus()
        self:SetHeight(ROW_COLLAPSED_H)
        self.background:SetTexCoord(0, 1, 1 - ROW_ART_H / 256, 1)
        self.tracked:Hide()
        self.description:Show()
        self.hiddenDescription:Hide()
        if not self:IsMouseOver() then self.highlight:Hide() end
    end;

    _Expand = function(self, height)
        self.collapsed = false
        self:_UpdatePlusMinus()
        self:SetHeight(height)
        self.background:SetTexCoord(0, 1, math.max(0, 1 - height / S / 256), 1)
        self.hiddenDescription:Show()
        self.description:Hide()
    end;

    -- Fill in for `def`; `objectives` is the shared pane, taken when this
    -- row is the selected one.
    SetAchievement = function(self, def, objectives)
        local engine = self.owner.engine
        self.achId = def.id
        self.prev = def.prev
        local _, name, pts, completed, month, day, year, desc, iconPath, rewardText, backfilled = engine:GetInfo(def.id)
        self.completed = completed
        self.backfilled = backfilled
        self.account = def.account

        self.label:SetWidth(320 * S)
        self.label:SetText(name)
        self.icon:SetTexture(iconPath)
        self.description:SetText(desc)
        self.hiddenDescription:SetText(desc)
        self.numLines = math.ceil((self.hiddenDescription:GetStringHeight() or DESCRIPTION_FONT * S) / (DESCRIPTION_FONT * S))

        -- a progressive achievement shows its chain's total
        self.points:SetText(def.prev and engine:GetProgressivePoints(def.id) or pts)

        if completed then
            self.dateCompleted:SetText(ShortDate(month, day, year))
            self.dateCompleted:Show()
            self:_Saturate()
        else
            self.dateCompleted:Hide()
            self:_Desaturate()
        end

        if rewardText and rewardText ~= "" then
            self.reward:SetText(rewardText)
            self.reward:Show()
            self.rewardBackground:Show()
            local v = completed and 1 or 0.35
            self.rewardBackground:SetVertexColor(v, v, v)
        else
            self.reward:Hide()
            self.rewardBackground:Hide()
        end

        local rows = engine:GetCriteria(def.id)
        self.hasObjectives = rows ~= nil and #rows > 0

        self:SetTracked(engine:IsTracked(def.id))

        if def.id == self.owner.selectedAch then
            objectives:SetParent(self)
            objectives:SetFrameLevel(self:GetFrameLevel() + 1)
            local height = ROW_COLLAPSED_H
            if completed and def.prev then
                objectives:DisplayProgressive(def.id)
                objectives:Below(self.hiddenDescription, 8 * S)
            else
                objectives:DisplayCriteria(def.id, completed)
                if (objectives:GetHeight() or 0) > 1 then
                    objectives:Below(self.hiddenDescription, 8 * S)
                    objectives:RightOf(self.iconFrame, -5 * S, -25 * S)
                    objectives:LeftOf(self.shield, 10 * S)
                end
            end
            objectives:Show()
            objectives.id = def.id
            local paneH = objectives:GetHeight() or 0
            if paneH > 1 then height = height + paneH end
            if height ~= ROW_COLLAPSED_H or self.numLines > MAX_LINES_COLLAPSED then
                height = height + (self.hiddenDescription:GetStringHeight() or 0) - DESCRIPTION_H
                if self.reward:IsShown() then height = height + 4 * S end
            end
            -- room for the Track checkbox when there is little else to show
            if not completed then height = math.max(height, MIN_EXPANDED_H) end
            self:_Expand(height)
            self.highlight:Show()
            if not completed then self.tracked:Show() end
        else
            if objectives.id == def.id then
                objectives:Clear()
                objectives:Hide()
            end
            if not self:IsMouseOver() then self.highlight:Hide() end
            self:_Collapse()
        end
    end;
}


-- ---------------------------------------------------------------------
-- AchievementStatistics: the Statistics tab (AchievementFrameStats) —
-- retail's StatsBackground plate under striped rows
-- (AchievementStatTemplate): the category's own statistics under its
-- header, then each sub-category under its own.
-- ---------------------------------------------------------------------
class "AchievementStatistics" : extends "Frame" {
    __init = function(self, parent, owner, categories)
        Frame.__init(self, "Frame", parent)
        self.owner = owner
        self:SetWidth(506 * S)
        self:SetPoint("TOPLEFT", categories, "TOPRIGHT", 22 * S, -36 * S)
        self:AlignBottom(categories)

        -- the plate is 526 wide from 2 in, so its art runs on under the
        -- scroll bar, stops 3 short of the bottom, and sits a level down
        local plate = Frame("Frame", self)
        plate:SetWidth(526 * S)
        plate:AlignParentTopLeft(0, 2 * S)
        plate:AlignParentBottomLeft(3 * S, 2 * S)
        plate:SetFrameLevel(plate:GetFrameLevel() - 1)
        local bg = Tex(plate, "BACKGROUND", Art("statsbackground"))
        bg:FillParent()
        GoldBorder(self)

        self.scroll = ScrollFrame(self)
        self.scroll:AlignParentTopLeft(3 * S, 3 * S)
        self.scroll:AlignParentBottomRight(5 * S, 3 * S)
        self.scroll:SetFrameLevel(self:GetFrameLevel() + 3)
        self.content = Frame("Frame", self.scroll)
        self.content:SetSize(1, 1)
        self.scroll:SetScrollChild(self.content)
        self.bar = owner:MakeScrollBar(self, self.scroll)

        self.rows = {}
        self:Hide()
    end;

    _GetRow = function(self, i)
        local b = self.rows[i]
        if not b then
            b = Frame("Frame", self.content)
            b:SetHeight(STAT_ROW_H)
            b:AlignParentLeft()
            b:AlignParentRight()
            if i == 1 then
                b:AlignParentTop()
            else
                b:Below(self.rows[i - 1])
            end
            b.left = Tex(b, "BACKGROUND", Art("stat-buttons"), { 0, 0.08984375, 0, 0.1796875 })
            b.left:SetSize(23 * S, 23 * S)
            b.left:AlignParentBottomLeft(-1 * S, 0)
            b.right = Tex(b, "BACKGROUND", Art("stat-buttons"), { 0.91015625, 1, 0, 0.1796875 })
            b.right:SetSize(23 * S, 23 * S)
            b.right:AlignParentBottomRight(-1 * S, 0)
            b.middle = Tex(b, "BACKGROUND", Art("stat-buttons"), { 0.08984375, 0.91015625, 0, 0.1796875 })
            b.middle:SetHeight(23 * S)
            b.middle:SetPoint("TOPLEFT", b.left, "TOPRIGHT", 0, 0)
            b.middle:SetPoint("TOPRIGHT", b.right, "TOPLEFT", 0, 0)
            b.background = Tex(b, "BACKGROUND", Art("stat-buttons"))
            b.background:FillParent()
            b.title = Label(b, 16, 1, 0.82, 0, "ARTWORK")
            b.title:CenterInParent(0, -1 * S)
            b.text = Label(b, 12, 1, 1, 1, "ARTWORK")
            b.text:SetSize(400 * S, 13 * S)
            b.text:SetJustifyH("LEFT")
            b.text:AlignParentLeft(5 * S)
            b.value = Label(b, 12, 1, 1, 1, "ARTWORK")
            b.value:SetJustifyH("RIGHT")
            b.value:AlignParentRight(5 * S)
            self.rows[i] = b
        end
        b:Show()
        return b
    end;

    -- The header and rows of one category.
    _Section = function(self, list, cat)
        list[#list + 1] = { header = cat.name }
        for _, def in ipairs(MUI_StatisticsDB:GetAll()) do
            if def.cat == cat.id then list[#list + 1] = def end
        end
    end;

    Refresh = function(self, catId)
        local engine = self.owner.engine
        local list = {}
        for _, cat in ipairs(MUI_StatisticsDB:GetCategories()) do
            if cat.id == catId then self:_Section(list, cat) end
        end
        for _, cat in ipairs(MUI_StatisticsDB:GetCategories()) do
            if cat.parent == catId then self:_Section(list, cat) end
        end
        local stripe = 0
        for i, row in ipairs(list) do
            local b = self:_GetRow(i)
            if row.header then
                b.left:Show(); b.middle:Show(); b.right:Show()
                b.background:Hide()
                b.title:SetText(row.header)
                b.title:Show()
                b.text:SetText("")
                b.value:SetText("")
            else
                stripe = stripe + 1
                b.left:Hide(); b.middle:Hide(); b.right:Hide()
                b.title:Hide()
                b.background:Show()
                if stripe % 2 == 1 then
                    b.background:SetTexCoord(0, 1, 0.1875, 0.3671875)
                    b.background:SetBlendMode("BLEND")
                    b.background:SetAlpha(1)
                else
                    b.background:SetTexCoord(0, 1, 0.375, 0.5390625)
                    b.background:SetBlendMode("ADD")
                    b.background:SetAlpha(0.5)
                end
                b.text:SetText(row.name)
                b.value:SetText(engine:GetStatValue(row, 12 * S))
            end
        end
        for i = #list + 1, #self.rows do self.rows[i]:Hide() end
        self.owner:FitScroll(self.scroll, self.content, self.bar, #list * STAT_ROW_H)
    end;
}


-- ---------------------------------------------------------------------
-- AchievementSummary: the Summary page (AchievementFrameSummary) — the
-- latest achievements earned in a 210-high block, then the category
-- progress block with its bars two to a row. Retail's layout is fixed;
-- it doesn't scroll.
-- ---------------------------------------------------------------------
local RECENT_ROWS    = 3
local RECENT_BLOCK_H = 166

class "AchievementSummary" : extends "Frame" {
    __init = function(self, parent, owner, categories)
        Frame.__init(self, "Frame", parent)
        self.owner = owner
        self:SetSize(529 * S, 461 * S)
        self:AlignParentTopLeft(55 * S, 218 * S)
        self:AlignBottom(categories)
        local bg = Tex(self, "BACKGROUND", Art("achievementbackground"), { 0, 1, 0, 0.5 })
        bg:FillParent(3 * S)
        GoldBorder(self)

        -- the recent block: header plate, three rows 18 in from its sides,
        -- 45 apart, in retail's 210-high block
        local recent = Frame("Frame", self)
        recent:SetHeight(RECENT_BLOCK_H * S)
        recent:AlignParentTopLeft(10 * S, 5 * S)
        recent:AlignParentTopRight(10 * S, 5 * S)
        local recentHeader = self:_Plate(recent, "Latest Unlocked Achievements")
        self.emptyText = Label(recent, 12, 1, 1, 1, "BACKGROUND")
        self.emptyText:AlignParentTop(30 * S)
        self.emptyText:SetText("You have not completed any achievements yet.")
        self.recent = {}
        for i = 1, RECENT_ROWS do
            local row = self:_RecentRow(recent)
            if i == 1 then
                row:SetPoint("TOPLEFT", recentHeader, "BOTTOMLEFT", 18 * S, 2 * S)
                row:SetPoint("TOPRIGHT", recentHeader, "BOTTOMRIGHT", -18 * S, 2 * S)
            else
                row:SetPoint("TOPLEFT", self.recent[i - 1], "BOTTOMLEFT", 0, 3 * S)
                row:SetPoint("TOPRIGHT", self.recent[i - 1], "BOTTOMRIGHT", 0, 3 * S)
            end
            self.recent[i] = row
        end

        -- the progress block: header plate, the total bar, the eleven
        -- category bars two to a row (retail's 164 holds its eight)
        local progress = Frame("Frame", self)
        progress:SetHeight(226 * S)
        progress:SetPoint("TOPLEFT", recent, "BOTTOMLEFT", 0, 6 * S)
        progress:SetPoint("TOPRIGHT", recent, "BOTTOMRIGHT", 0, 6 * S)
        local progressHeader = self:_Plate(progress, "Category Progress")
        self.total = self:_Bar(progress, 488 * S)
        self.total:Below(progressHeader, 6 * S)
        self.total.title:SetText("Achievements Completed")
        self.bars = {}
        local left
        for _, cat in ipairs(owner.engine.categories) do
            if not cat.parent then
                local bar = self:_Bar(progress, 234 * S)
                bar.catId = cat.id
                bar.title:SetText(cat.name)
                local n = #self.bars + 1
                if n % 2 == 1 then
                    if left then
                        bar:SetPoint("TOPLEFT", left, "BOTTOMLEFT", 0, -10 * S)
                    else
                        bar:SetPoint("TOPLEFT", self.total, "BOTTOMLEFT", 0, -13 * S)
                    end
                    left = bar
                else
                    bar:SetPoint("TOPLEFT", left, "TOPRIGHT", 20 * S, 0)
                end
                self.bars[n] = bar
            end
        end
        self:Hide()
    end;

    -- A header plate (UI-Achievement-RecentHeader) across the top of `block`.
    _Plate = function(self, block, text)
        local plate = Frame("Frame", block)
        plate:SetHeight(20 * S)
        plate:AlignParentTopLeft()
        plate:AlignParentTopRight()
        local tex = Tex(plate, "BACKGROUND", Art("recentheader"), { 0, 1, 0, 0.71875 })
        tex:AlignParentTopLeft(0, -20 * S)
        tex:AlignParentBottomRight(0, -20 * S)
        local title = Label(plate, 12, 1, 0.82, 0, "BACKGROUND")
        title:SetHeight(20 * S)
        title:CenterInParent()
        title:SetText(text)
        return plate
    end;

    -- A recent achievement (SummaryAchievementTemplate over
    -- ComparisonPlayerTemplate, saturated): the list rows' border and title
    -- band (red, or blue for an account-wide one) at half alpha with its
    -- glow, parchment, the icon on its ring, the shield with white points,
    -- the date.
    _RecentRow = function(self, block)
        local b = Frame("Frame", block, nil, "BackdropTemplate")
        b:SetHeight(48 * S)
        b:EnableMouse(true)
        b:SetBackdrop(TOOLTIP_BORDER)
        b:SetBackdropBorderColor(RED_BORDER[1], RED_BORDER[2], RED_BORDER[3])
        local bg = Tex(b, "BACKGROUND", Art("parchment-horizontal"), { 0, 1, 0, 0.25 })
        bg:FillParent(3 * S)
        local band = Tex(b, "ARTWORK", Art("borders"), TITLEBAR_DONE)
        band:SetHeight(20 * S)
        band:AlignParentTopLeft(4 * S, 5 * S)
        band:AlignParentTopRight(4 * S, 5 * S)
        band:SetAlpha(0.5)
        b.band = band
        local glow = Tex(b, "ARTWORK", Art("borders"), { 0, 1, 0.00390625, 0.25390625 })
        glow:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 2 * S)
        glow:AlignParentBottomRight(4 * S, 0)

        local iconFrame = Frame("Frame", b)
        iconFrame:SetSize(48 * S, 48 * S)
        iconFrame:AlignParentTopLeft(3 * S, 3 * S)
        b.icon = Texture(iconFrame, nil, "ARTWORK")
        b.icon:SetSize(36 * S, 36 * S)
        b.icon:CenterInParent(0, 3 * S)
        local ring = Tex(iconFrame, "OVERLAY", Art("iconframe"), { 0, 0.5625, 0, 0.5625 })
        ring:SetSize(46 * S, 46 * S)
        ring:CenterInParent(-1 * S, 2 * S)

        local shield = Frame("Frame", b)
        shield:SetSize(48 * S, 48 * S)
        shield:AlignParentTopRight(4 * S, 10 * S)
        local shieldTex = Tex(shield, "BACKGROUND", Art("shields"), { 0, 0.5, 0, 0.5 })
        shieldTex:SetSize(48 * S, 48 * S)
        shieldTex:AlignParentTopRight()
        b.pts = Label(shield, 12, 1, 1, 1)
        b.pts:SetSize(40 * S, 26 * S)
        b.pts:SetJustifyH("CENTER")
        b.pts:CenterInParent(-0.5 * S, 2 * S)

        b.name = Label(b, 14, 1, 1, 1)
        b.name:SetSize(260 * S, 20 * S)
        b.name:SetWordWrap(false)
        b.name:AlignTop(band)
        b.date = Label(b, 10, 1, 0.82, 0)
        b.date:SetSize(100 * S, 14 * S)
        b.date:SetJustifyH("RIGHT")
        b.date:AlignParentTopRight(8 * S, 63 * S)
        b.desc = Label(b, DESCRIPTION_FONT, 0, 0, 0)
        b.desc:SetFontObject(MUI.FontBySize(DESCRIPTION_FONT * S, false))
        b.desc:SetTextColor(0, 0, 0, 1)
        b.desc:SetSize(380 * S, 13 * S)
        b.desc:SetJustifyH("CENTER")
        b.desc:SetJustifyV("TOP")
        b.desc:AlignParentTop(30 * S)

        b.highlight = AchievementRowHighlight(b)
        b:SetScript("OnEnter", function() b.highlight:Show() end)
        b:SetScript("OnLeave", function() b.highlight:Hide() end)
        b:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and b.achId and b:IsMouseOver() then
                self.owner:SelectAchievement(b.achId)
            end
        end)
        return b
    end;

    -- A progress bar (AchievementFrameSummaryCategoryTemplate): the skills
    -- bar's green fill framed by the header art's caps, the name on the
    -- left, the count on the right, a glow on hover; a click opens the
    -- category.
    _Bar = function(self, block, width)
        local bar = StatusBar(block)
        bar:SetSize(width, 21 * S)
        bar:SetStatusBarTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
        bar:SetStatusBarColor(0, 1, 0, 1)
        bar:SetBackgroundColor(0, 0, 0, 0.5)     -- retail's FillBar: the dark track
        bar:EnableMouse(true)
        bar.title = Label(bar, 12, 1, 0.82, 0)
        bar.title:AlignParentLeft(6 * S, 4 * S)
        bar.text = Label(bar, 12, 1, 1, 1)
        bar.text:SetHeight(14 * S)
        bar.text:AlignParentRight(5 * S, 3 * S)
        local capL = Tex(bar, "OVERLAY", Art("header"), { 0.423828125, 0.486, 0.56640625, 0.75 })
        capL:SetSize(32 * S, 48 * S)
        capL:AlignParentTopLeft(-16 * S, -15 * S)
        local capR = Tex(bar, "OVERLAY", Art("header"), { 0.486, 0.423828125, 0.56640625, 0.75 })
        capR:SetSize(32 * S, 48 * S)
        capR:AlignParentTopRight(-16 * S, -15 * S)
        local capM = Tex(bar, "OVERLAY", Art("header"), { 0.889224609375, 0.486, 0.56640625, 0.75 })
        capM:SetPoint("TOPLEFT", capL, "TOPRIGHT", 0, 0)
        capM:SetPoint("BOTTOMRIGHT", capR, "BOTTOMLEFT", 0, 0)

        local hl = Frame("Frame", bar)
        hl:FillParent()
        local hlL = Tex(hl, "OVERLAY", Art("statusbar-highlight"))
        hlL:SetBlendMode("ADD")
        hlL:SetSize(32 * S, 32 * S)
        hlL:AlignParentTopLeft(-8 * S, -7 * S)
        local hlR = Tex(hl, "OVERLAY", Art("statusbar-highlight"), { 1, 0, 0, 1 })
        hlR:SetBlendMode("ADD")
        hlR:SetSize(32 * S, 32 * S)
        hlR:AlignParentTopRight(-8 * S, -7 * S)
        local hlM = Tex(hl, "OVERLAY", Art("statusbar-highlight"), { 0.5, 1, 0, 1 })
        hlM:SetBlendMode("ADD")
        hlM:SetPoint("TOPLEFT", hlL, "TOPRIGHT", 0, 0)
        hlM:SetPoint("BOTTOMRIGHT", hlR, "BOTTOMLEFT", 0, 0)
        hl:Hide()
        bar:SetScript("OnEnter", function() if bar.catId then hl:Show() end end)
        bar:SetScript("OnLeave", function() hl:Hide() end)
        bar:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and bar.catId and bar:IsMouseOver() then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
                self.owner:SelectCategory(bar.catId)
            end
        end)
        return bar
    end;

    Refresh = function(self)
        local engine = self.owner.engine
        local recent = engine:GetRecent()
        for i, row in ipairs(self.recent) do
            local entry = recent[i]
            if entry then
                local _, name, pts, _, month, day, year, desc, iconPath = engine:GetInfo(entry.id)
                row.achId = entry.id
                local account = engine:GetDef(entry.id).account
                local file, coords = TitleBarArt(account, true)
                row.band:SetTexture(file)
                row.band:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                local border = account and BLUE_BORDER or RED_BORDER
                row:SetBackdropBorderColor(border[1], border[2], border[3])
                row.name:SetText(name)
                row.desc:SetText(desc)
                row.icon:SetTexture(iconPath)
                row.pts:SetFontObject(MUI.FontBySize((pts < 100 and 12 or 10) * S))
                row.pts:SetTextColor(1, 1, 1, 1)
                row.pts:SetText(pts > 0 and pts or "")
                row.date:SetText(month and ShortDate(month, day, year) or "")
                row:Show()
            else
                row:Hide()
            end
        end
        self.emptyText:SetVisible(#recent == 0)

        local total, done = #engine.list, engine:GetNumEarned()
        self.total:SetMinMaxValues(0, math.max(total, 1))
        self.total:SetValue(done)
        self.total.text:SetText(done .. "/" .. total)
        for _, bar in ipairs(self.bars) do
            total, done = engine:GetCategoryNum(bar.catId)
            bar:SetMinMaxValues(0, math.max(total, 1))
            bar:SetValue(done)
            bar.text:SetText(done .. "/" .. total)
        end
    end;
}


-- ---------------------------------------------------------------------
-- AchievementSearch: retail's SearchBoxTemplate in the details strip
-- (the window places it), its preview list (five matches and "Show all"
-- inside a UI-Frame border) and the full results window on the rock
-- background. Our search is client-side and instant; three characters
-- start it.
-- ---------------------------------------------------------------------
local PREVIEWS       = 5
local PREVIEW_ROW_H  = 27 * S
local RESULT_ROW_H   = 49 * S
local SEARCH_MIN     = 3
local SEARCH_TEXT    = { 0.96875, 0.8984375, 0.578125 }
local SEARCH_DIM     = { 0.66796875, 0.51171875, 0.3359375 }

class "AchievementSearch" : extends "Frame" {
    __init = function(self, details, owner)
        Frame.__init(self, "Frame", details)
        self:SetSize(1, 1)
        self:AlignParentTopLeft()
        self.owner = owner
        self.selected = 1
        self.found = {}

        self.box = EditBox(details, nil, "SearchBoxTemplate")
        self.box:SetSize(107 * S, 30 * S)

        self:_BuildPreview()
        self:_BuildResults()

        self.box.OnFocusGained = function()
            self.results:Hide()
            self:_UpdatePreview()
        end
        self.box.OnFocusLost = function()
            -- a click on a preview row takes the focus first; let it land
            C_Timer.After(0.15, function()
                if not self.box:HasFocus() then self.preview:Hide() end
            end)
        end
        self.box.OnTextChanged = function() self:_UpdatePreview() end
        self.box.OnEnterPressed = function() self:_Choose() end
        self.box:SetScript("OnKeyDown", function(_, key)
            if key == "UP" then
                self:_Select(self.selected - 1)
            elseif key == "DOWN" then
                self:_Select(self.selected + 1)
            end
        end)
    end;

    -- The dropdown under the box: the rows that show, wrapped by retail's
    -- UI-Frame border whose bottom corner follows the last of them.
    _BuildPreview = function(self)
        local atlas = MUI_AtlasRegistry.Search
        local pc = Frame("Frame", self.owner)
        pc:SetSize(206 * S, PREVIEW_ROW_H)
        pc:SetPoint("TOPLEFT", self.box, "BOTTOMLEFT", -4 * S, 3 * S)
        pc:SetFrameStrata("DIALOG")
        pc:Hide()
        self.preview = pc

        pc.anchor = FramePiece(pc, "UI-Frame-BotCornerLeft")
        pc.anchor:SetDrawLayer("OVERLAY")
        pc.anchor:AlignParentLeft(-7 * S)
        local cornerR = FramePiece(pc, "UI-Frame-BotCornerRight")
        cornerR:SetDrawLayer("OVERLAY")
        cornerR:SetPoint("BOTTOM", pc.anchor, "BOTTOM", 0, 0)
        cornerR:AlignParentRight(-4 * S)
        local bottom = FramePiece(pc, "_UI-Frame-Bot")
        bottom:SetDrawLayer("OVERLAY")
        bottom:SetPoint("BOTTOMLEFT", pc.anchor, "BOTTOMRIGHT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", cornerR, "BOTTOMLEFT", 0, 0)
        local left = FramePiece(pc, "!UI-Frame-LeftTile")
        left:SetDrawLayer("OVERLAY")
        left:AlignParentTop(-1 * S)
        left:SetPoint("BOTTOMLEFT", pc.anchor, "TOPLEFT", 0, 0)
        local right = FramePiece(pc, "!UI-Frame-RightTile")
        right:SetDrawLayer("OVERLAY")
        right:AlignParentTop(-1 * S)
        right:SetPoint("BOTTOMRIGHT", cornerR, "TOPRIGHT", 1 * S, 0)
        local top = FramePiece(pc, "_UI-Frame-Bot")
        top:SetDrawLayer("OVERLAY")
        top:AlignParentTopLeft(-3 * S, -2 * S)
        top:SetPoint("BOTTOMRIGHT", pc, "TOPRIGHT", 2 * S, -3 * S)

        pc.rows = {}
        for i = 1, PREVIEWS do
            local b = Frame("Frame", pc)
            b:SetSize(206 * S, PREVIEW_ROW_H)
            b:EnableMouse(true)
            if i == 1 then b:AlignParentTopLeft() else b:SetPoint("TOPLEFT", pc.rows[i - 1], "BOTTOMLEFT", 0, 0) end
            local rowBg = Texture(b, nil, "BACKGROUND")
            rowBg:SetAtlas(atlas, "RowBg", true)
            rowBg:FillParent()
            b.selected = Texture(b, nil, "OVERLAY")
            b.selected:SetDrawLayer("OVERLAY", 3)
            b.selected:SetAtlas(atlas, "Highlight", true)
            b.selected:FillParent()
            b.selected:Hide()
            local iconFrame = Texture(b, nil, "OVERLAY")
            iconFrame:SetDrawLayer("OVERLAY", 2)
            iconFrame:SetAtlas(atlas, "IconFrameLarge", true)
            iconFrame:SetSize(21 * S, 21 * S)
            iconFrame:AlignParentLeft(5 * S, 1 * S)
            b.icon = Texture(b, nil, "OVERLAY")
            b.icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1 * S, -2 * S)
            b.icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1 * S, 1 * S)
            b.name = Label(b, 10, SEARCH_TEXT[1], SEARCH_TEXT[2], SEARCH_TEXT[3])
            b.name:SetJustifyH("LEFT")
            b.name:SetWordWrap(false)
            b.name:RightOf(b.icon, 5 * S)
            b.name:AlignParentRight(5 * S)
            -- on the press: the release may come after the box lost focus
            b:SetScript("OnMouseDown", function(_, button)
                if button == "LeftButton" and b.achId then self:_Pick(b.achId) end
            end)
            pc.rows[i] = b
        end

        local all = Frame("Frame", pc)
        all:SetHeight(24 * S)
        all:EnableMouse(true)
        all:AlignLeft(pc.rows[1])
        all:AlignRight(pc.rows[1])
        all:Below(pc.rows[PREVIEWS])
        local allBg = Texture(all, nil, "BACKGROUND")
        allBg:SetAtlas(atlas, "RowBg", true)
        allBg:FillParent()
        all.selected = Texture(all, nil, "OVERLAY")
        all.selected:SetDrawLayer("OVERLAY", 2)
        all.selected:SetAtlas(atlas, "Highlight", true)
        all.selected:FillParent()
        all.selected:Hide()
        all.text = Label(all, 12, 1, 0.82, 0)
        all.text:CenterInParent()
        all:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" then self:_ShowAll() end
        end)
        pc.showAll = all
    end;

    -- The full results window: the rock background in retail's UI-Frame
    -- border, a title bar, the close button, the scrolling rows.
    _BuildResults = function(self)
        local res = Frame("Frame", self.owner)
        res:SetSize(600 * S, 382 * S)
        res:AlignParentBottom(7 * S)
        res:SetFrameStrata("DIALOG")
        res:EnableMouse(true)
        res:Hide()
        self.results = res

        local rock = Texture(res, nil, "BACKGROUND")
        rock:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
        rock:SetHorizTile(true)
        rock:SetVertTile(true)
        rock:SetVertexColor(0.9, 0.8, 0.7)
        rock:AlignParentTopLeft()
        rock:AlignParentBottomRight(8 * S, 0)

        local tl = FramePiece(res, "UI-Frame-TopCornerLeft")
        tl:AlignParentTopLeft(-4 * S, -7 * S)
        local tr = FramePiece(res, "UI-Frame-TopCornerRightSimple")
        tr:AlignParentTopRight(-4 * S, -4 * S)
        local topBorder = FramePiece(res, "_UI-Frame-Top")
        topBorder:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
        topBorder:SetPoint("TOPRIGHT", tr, "TOPLEFT", 0, 0)
        local bl = FramePiece(res, "UI-Frame-BotCornerLeft")
        bl:AlignParentBottomLeft(4 * S, -7 * S)
        local br = FramePiece(res, "UI-Frame-BotCornerRight")
        br:AlignParentBottomRight(4 * S, -4 * S)
        local bottomBorder = FramePiece(res, "_UI-Frame-Bot")
        bottomBorder:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, 0)
        bottomBorder:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
        local leftBorder = FramePiece(res, "!UI-Frame-LeftTile")
        leftBorder:SetPoint("BOTTOMLEFT", bl, "TOPLEFT", 0, 0)
        leftBorder:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
        local rightBorder = FramePiece(res, "!UI-Frame-RightTile")
        rightBorder:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
        rightBorder:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 1 * S, 0)
        local streaks = FramePiece(res, "_UI-Frame-TopTileStreaks", -1)
        streaks:AlignParentTopLeft()
        streaks:AlignParentTopRight()
        -- the second top row is the title bar's lower edge
        local tl2 = FramePiece(res, "UI-Frame-TopCornerLeft", 1)
        tl2:AlignParentTopLeft(20 * S, -7 * S)
        local tr2 = FramePiece(res, "UI-Frame-TopCornerRightSimple", 1)
        tr2:AlignParentTopRight(20 * S, -4 * S)
        local topBorder2 = FramePiece(res, "_UI-Frame-Top", 1)
        topBorder2:SetPoint("TOPLEFT", tl2, "TOPRIGHT", 0, 0)
        topBorder2:SetPoint("TOPRIGHT", tr2, "TOPLEFT", 0, 0)

        res.title = Label(res, 12, 1, 0.82, 0, "BORDER")
        res.title:AlignParentTop(7 * S)
        res.title:AlignParentLeft(60 * S)
        res.title:AlignParentRight(60 * S)
        res.close = CloseButton(res)
        res.close:ClearAllPoints()
        res.close:SetPoint("TOPRIGHT", tr, "TOPRIGHT", 1 * S, -4 * S)

        res.scroll = ScrollFrame(res)
        res.scroll:SetPoint("TOPLEFT", tl2, "TOPLEFT", 8 * S, -8 * S)
        res.scroll:SetPoint("BOTTOMRIGHT", br, "BOTTOMRIGHT", -24 * S, 8 * S)
        res.content = Frame("Frame", res.scroll)
        res.content:SetSize(1, 1)
        res.scroll:SetScrollChild(res.content)
        res.bar = self.owner:MakeScrollBar(res, res.scroll, -15, 33, 15)
        res.rows = {}
    end;

    -- A result (AchievementFullSearchResultsButtonTemplate): the icon on
    -- its frame, the name, the category, Completed / Incomplete.
    _ResultRow = function(self, i)
        local res, atlas = self.results, MUI_AtlasRegistry.Search
        local b = Frame("Frame", res.content)
        b:SetHeight(RESULT_ROW_H)
        b:EnableMouse(true)
        b:AlignParentLeft()
        b:AlignParentRight()
        if i == 1 then b:AlignParentTop() else b:Below(res.rows[i - 1]) end
        local bg = Texture(b, nil, "BACKGROUND")
        if bg:SetBlizzardAtlas("_SearchBarLg") then bg:SetHorizTile(true) end
        bg:FillParent()
        local hl = Texture(b, nil, "HIGHLIGHT")
        hl:SetAtlas(atlas, "HighlightLarge", true)
        hl:FillParent()
        local iconFrame = Texture(b, nil, "OVERLAY")
        iconFrame:SetDrawLayer("OVERLAY", 2)
        iconFrame:SetAtlas(atlas, "IconFrameLarge")
        iconFrame:AlignParentLeft(10 * S)
        b.icon = Texture(b, nil, "OVERLAY")
        b.icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1 * S, -2 * S)
        b.icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1 * S, 1 * S)
        b.name = Label(b, 16, SEARCH_TEXT[1], SEARCH_TEXT[2], SEARCH_TEXT[3])
        b.name:SetJustifyH("LEFT")
        b.name:SetWordWrap(false)
        b.name:SetSize(400 * S, 12 * S)
        b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 10 * S, 0)
        b.path = Label(b, 12, SEARCH_DIM[1], SEARCH_DIM[2], SEARCH_DIM[3])
        b.path:SetJustifyH("LEFT")
        b.path:SetWidth(400 * S)
        b.path:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -7 * S)
        b.kind = Label(b, 12, SEARCH_DIM[1], SEARCH_DIM[2], SEARCH_DIM[3])
        b.kind:SetJustifyH("RIGHT")
        b.kind:SetWidth(140 * S)
        b.kind:AlignParentRight(14 * S)
        b:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and b.achId and b:IsMouseOver() then self:_Pick(b.achId) end
        end)
        return b
    end;

    _UpdatePreview = function(self)
        local pc = self.preview
        local text = self.box:GetText() or ""
        if not self.box:HasFocus() or #text < SEARCH_MIN then
            pc:Hide()
            return
        end
        self.found = self.owner.engine:Search(text)
        local n = #self.found
        if n == 0 then
            pc:Hide()
            return
        end
        local last
        for i = 1, PREVIEWS do
            local row, def = pc.rows[i], self.found[i]
            if def then
                row.achId = def.id
                row.name:SetText(def.name)
                row.icon:SetTexture(self.owner.engine:IconPath(def))
                row:Show()
                last = row
            else
                row.achId = nil
                row:Hide()
            end
        end
        if n > PREVIEWS then
            pc.showAll.text:SetText(string.format("Show all %d results", n))
            pc.showAll:Show()
            last = pc.showAll
        else
            pc.showAll:Hide()
        end
        -- the border's bottom corner rides 5 under the last entry
        pc.anchor:ClearAllPoints()
        pc.anchor:AlignParentLeft(-7 * S)
        pc.anchor:SetPoint("BOTTOM", last, "BOTTOM", 0, -5 * S)
        self:_Select(1)
        pc:Show()
    end;

    -- Highlight entry `idx` (the rows, then Show all), wrapping around.
    _Select = function(self, idx)
        local pc = self.preview
        local shown = 0
        for i = 1, PREVIEWS do
            pc.rows[i].selected:Hide()
            if pc.rows[i]:IsShown() then shown = shown + 1 end
        end
        pc.showAll.selected:Hide()
        local count = shown + (pc.showAll:IsShown() and 1 or 0)
        if count == 0 then
            self.selected = 1
            return
        end
        self.selected = (idx - 1) % count + 1
        if self.selected > shown then
            pc.showAll.selected:Show()
        else
            pc.rows[self.selected].selected:Show()
        end
    end;

    -- Enter: the highlighted entry.
    _Choose = function(self)
        local pc = self.preview
        if not pc:IsShown() then return end
        local shown = 0
        for i = 1, PREVIEWS do
            if pc.rows[i]:IsShown() then shown = shown + 1 end
        end
        if self.selected > shown then
            self:_ShowAll()
        elseif pc.rows[self.selected].achId then
            self:_Pick(pc.rows[self.selected].achId)
        end
    end;

    _Pick = function(self, id)
        self.preview:Hide()
        self.results:Hide()
        self.box:ClearFocus()
        self.owner:SelectAchievement(id)
    end;

    _ShowAll = function(self)
        local res, engine = self.results, self.owner.engine
        self.preview:Hide()
        self.box:ClearFocus()
        res.title:SetText(string.format("Search results: %s (%d)", self.box:GetText() or "", #self.found))
        for i, def in ipairs(self.found) do
            local row = res.rows[i]
            if not row then
                row = self:_ResultRow(i)
                res.rows[i] = row
            end
            row.achId = def.id
            row.name:SetText(def.name)
            row.icon:SetTexture(engine:IconPath(def))
            row.path:SetText(self.owner:CategoryName(def.sub or def.cat))
            row.kind:SetText(engine:IsEarned(def.id) and "Completed" or "Incomplete")
            row:Show()
        end
        for i = #self.found + 1, #res.rows do res.rows[i]:Hide() end
        self.owner:FitScroll(res.scroll, res.content, res.bar, #self.found * RESULT_ROW_H)
        res.bar:SetValue(0)
        res:Show()
    end;
}


-- ---------------------------------------------------------------------
-- AchievementWindow: the window. (Not "AchievementFrame": Blizzard's micro
-- menu code tests a global of that name, which our class table would be.)
-- ---------------------------------------------------------------------
local SUMMARY = 0    -- the Summary page's pseudo-category id
local FILTER_H = 22  -- our dropdown art against the search box's unscaled 20-high border
local FILTERS = { { 1, "All" }, { 2, "Completed" }, { 3, "Incomplete" } }

class "AchievementWindow" : extends "Frame" {
    __init = function(self, engine)
        Frame.__init(self, "Frame", nil, "MUI_AchievementFrame", "BackdropTemplate")
        self.engine = engine
        self:SetSize(694, 450)
        self:AlignParentTopLeft(104, 86)
        self:SetFrameStrata("MEDIUM")
        self:SetToplevel(true)
        self:EnableMouse(true)
        self:SetBackdrop({ edgeFile = Art("woodborder"), edgeSize = 64 * S, tileEdge = true })
        self:Hide()

        self.rows = {}
        self.selectedCategory = nil
        self.selectedAch = nil
        self.filterMode = 1

        self.history = {}

        self:_BuildChrome()
        self:_BuildHeader()
        self:_BuildCategories()
        self:_BuildDetails()
        self:_BuildList()
        self.objectives = AchievementObjectives(self, self)
        self.summary    = AchievementSummary(self, self, self.categories)
        self.statistics = AchievementStatistics(self, self, self.categories)
        self.search     = AchievementSearch(self.details, self)
        self:_BuildFilter()
        self:_BuildTabs()

        self.closeButton = CloseButton(self, "MUI_AchievementFrameClose")
        tinsert(UISpecialFrames, "MUI_AchievementFrame")

        -- the first opening lands on the Summary, like retail
        self:SetScript("OnShow", function()
            PlaySoundFile(SOUND_OPEN, "SFX")
            if not self.selectedCategory then
                self:SelectCategory(SUMMARY)
            else
                self:_RefreshCurrent()
            end
        end)
        self:SetScript("OnHide", function()
            PlaySoundFile(SOUND_CLOSE, "SFX")
        end)

        -- the engine changed something: repaint when visible, a little later
        engine:RegisterDirty(function()
            if not self:IsShown() or self._repaintQueued then return end
            self._repaintQueued = true
            C_Timer.After(0.2, function()
                self._repaintQueued = false
                if self:IsShown() then self:_RefreshCurrent() end
            end)
        end)
        engine:RegisterTrackListener(function()
            for _, row in ipairs(self.rows) do
                if row:IsShown() then row:SetTracked(engine:IsTracked(row.achId)) end
            end
        end)
    end;

    -- ---- building ------------------------------------------------------

    -- Parchment background under a dark wash, metal rails, the categories'
    -- parchment strip with its shield watermark, the metal joints and wood
    -- corners over everything.
    _BuildChrome = function(self)
        local bg = Tex(self, "BACKGROUND", Art("achievementbackground"), { 0, 1, 0, 0.5 })
        bg:AlignParentTopLeft(16 * S, 16 * S)
        bg:AlignParentBottomRight(16 * S, 16 * S)
        local cover = Texture(self, nil, "BACKGROUND")
        cover:SetDrawLayer("BACKGROUND", 1)
        cover:SetAllPoints(bg)
        cover:SetColorTexture(0, 0, 0, 0.75)

        local railLeft = Tex(self, "ARTWORK", Art("metalborder-left"), { 0, 1, 0, 0.87 })
        railLeft:SetSize(16 * S, 436 * S)
        railLeft:AlignParentLeft(14 * S, 0)
        local railRight = Tex(self, "ARTWORK", Art("metalborder-left"), { 1, 0, 0.87, 0 })
        railRight:SetSize(16 * S, 436 * S)
        railRight:AlignParentRight(13 * S, 0)
        local railBottom = Tex(self, "ARTWORK", Art("metalborder-top"), { 0, 0.87, 1, 0 })
        railBottom:SetHeight(16 * S)
        railBottom:AlignParentBottomLeft(13 * S, 28 * S)
        railBottom:AlignParentBottomRight(13 * S, 28 * S)
        local railTop = Tex(self, "ARTWORK", Art("metalborder-top"), { 0.87, 0, 0, 1 })
        railTop:SetHeight(16 * S)
        railTop:AlignParentTopLeft(12 * S, 28 * S)
        railTop:AlignParentTopRight(12 * S, 28 * S)

        local strip = Tex(self, "ARTWORK", Art("parchment"), { 0, 0.5, 0, 1 })
        strip:SetWidth(195 * S)
        strip:AlignParentTopLeft(23 * S, 25 * S)
        strip:AlignParentBottomLeft(23 * S, 25 * S)
        local watermark = Tex(self, "OVERLAY", Art("achievementwatermark"))
        watermark:SetSize(256 * S, 256 * S)
        watermark:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, 0)

        local joints = {
            { "AlignParentTopLeft",     7, 9, { 1, 0, 1, 0 } },
            { "AlignParentTopRight",    7, 8, { 0, 1, 1, 0 } },
            { "AlignParentBottomLeft",  8, 9, { 1, 0, 0, 1 } },
            { "AlignParentBottomRight", 8, 8, { 0, 1, 0, 1 } },
        }
        for _, j in ipairs(joints) do
            local t = Tex(self, "OVERLAY", Art("metalborder-joint"), j[4])
            t:SetSize(32 * S, 32 * S)
            t[j[1]](t, j[2], j[3])
        end
        local corners = {
            { "AlignParentTopLeft",     2, 4, { 0, 1, 0, 1 } },
            { "AlignParentTopRight",    2, 4, { 1, 0, 0, 1 } },
            { "AlignParentBottomLeft",  3, 4, { 0, 1, 1, 0 } },
            { "AlignParentBottomRight", 3, 4, { 1, 0, 1, 0 } },
        }
        for _, c in ipairs(corners) do
            local t = Tex(self, "OVERLAY", Art("woodborder-corner"), c[4], 1)
            t:SetSize(64 * S, 64 * S)
            t[c[1]](t, c[2], c[3])
        end
    end;

    -- The plate floating over the top edge: title, points in their border,
    -- the small shield.
    _BuildHeader = function(self)
        local h = Frame("Frame", self)
        h:SetSize(726 * S, 106 * S)
        h:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 26 * S, -38 * S)
        self.header = h

        local left = Tex(h, "BACKGROUND", Art("header"), { 0, 1, 0, 0.4140625 })
        left:SetSize(512 * S, 106 * S)
        left:AlignParentBottomLeft()
        local right = Tex(h, "BACKGROUND", Art("header"), { 0, 0.419921875, 0.4140625, 0.8046875 })
        right:SetSize(215 * S, 100 * S)
        right:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 0, -6 * S)

        local pointsBorder = Tex(h, "BORDER", Art("header"), { 0.419921875, 0.6796875, 0.4140625, 0.56640625 })
        pointsBorder:SetSize(133 * S, 39 * S)
        pointsBorder:AlignParentBottom(16 * S, 20 * S)

        local title = Label(h, 12, 1, 0.82, 0, "BORDER")
        title:SetSize(150 * S, 20 * S)
        title:AlignTop(pointsBorder, -12 * S)
        title:SetText("Achievement Points")

        self.points = Label(h, 12, 1, 1, 1, "ARTWORK")
        self.points:SetHeight(12 * S)
        self.points:AlignTop(pointsBorder, 13 * S, -12 * S)
        self.points:SetText("0")

        local shield = Tex(h, "ARTWORK", Art("tinyshield"), { 0, 0.625, 0, 0.625 })
        shield:SetSize(20 * S, 20 * S)
        shield:RightOf(self.points, 3 * S, -1 * S)
    end;

    -- The category rail (AchievementFrameCategories): gold-bordered, a
    -- scrolling list of rows headed by the Summary; the Statistics tab
    -- swaps in its own categories.
    _BuildCategories = function(self)
        local c = Frame("Frame", self)
        c:SetWidth(CATS_W)
        c:AlignParentTopLeft(19 * S, 21 * S)
        c:AlignParentBottomLeft(20 * S, 21 * S)
        GoldBorder(c)
        self.categories = c

        c.scroll = ScrollFrame(c)
        c.scroll:AlignParentTopLeft(5 * S, 0)
        c.scroll:AlignParentBottomRight(5 * S, 0)
        c.scroll:SetFrameLevel(c:GetFrameLevel() + 3)
        c.content = Frame("Frame", c.scroll)
        c.content:SetSize(1, 1)
        c.scroll:SetScrollChild(c.content)
        c.bar = self:MakeScrollBar(c, c.scroll)

        self.categoryRows = { AchievementCategoryRow(c.content, self, { id = SUMMARY, name = "Summary" }) }
        for _, cat in ipairs(self.engine.categories) do
            table.insert(self.categoryRows, AchievementCategoryRow(c.content, self, cat))
        end
        self.statRows = {}
        for _, cat in ipairs(MUI_StatisticsDB:GetCategories()) do
            table.insert(self.statRows, AchievementCategoryRow(c.content, self,
                { id = cat.id, name = cat.name, parent = cat.parent, stats = true }))
        end
        self.selectedStat = MUI_StatisticsDB:GetCategories()[1].id
    end;

    -- The strip under the top border (HeaderDetails): the streaks, the
    -- Back button at its left, the search box at its right with the filter
    -- dropdown beside it while the list shows.
    _BuildDetails = function(self)
        local d = Frame("Frame", self)
        d:SetPoint("TOPLEFT", self.categories, "TOPRIGHT", 23 * S, 0)
        d:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -23 * S, -57 * S)
        self.details = d
        local streaks = Texture(d, nil, "BACKGROUND")
        streaks:SetDrawLayer("BACKGROUND", -1)
        streaks:SetBlizzardAtlas("_UI-Frame-TopTileStreaks")
        streaks:SetHorizTile(true)
        streaks:FillParent()

        self.back = ButtonGold(d, nil, "Back")
        self.back:SetSize(100 * S, 22 * S)
        self.back:AlignParentTopLeft(10 * S, 6 * S)
        self.back.label:SetFontSize(12 * S)
        self.back:SetEnabled(false)
        self.back.OnClick = function() self:GoBack() end
    end;

    -- The search box keeps the strip's right edge; the filter, when shown,
    -- takes it and the box sits beside it. The box's border art is 20 high
    -- whatever its frame, so the filter centres on that, not on the frame.
    _LayoutDetails = function(self, filter)
        local box = self.search.box
        local boxTop, boxH = 6 * S, 30 * S
        local drop = (boxH - FILTER_H) / 2
        box:ClearAllPoints()
        if filter then
            self.filter:ClearAllPoints()
            self.filter:AlignParentTopRight(boxTop + drop + 1, 8 * S)
            box:SetPoint("TOPRIGHT", self.filter, "TOPLEFT", -7 * S, drop)
        else
            box:AlignParentTopRight(boxTop, 8 * S)
        end
    end;

    -- The achievement list (AchievementFrameAchievements): dark-washed
    -- parchment in the gold border, a scrolling column of rows.
    _BuildList = function(self)
        local a = Frame("Frame", self)
        a:SetWidth(504 * S)
        a:SetPoint("TOPLEFT", self.categories, "TOPRIGHT", 22 * S, -36 * S)
        a:AlignBottom(self.categories)
        self.list = a

        local bg = Tex(a, "BACKGROUND", Art("achievementbackground"), { 0, 1, 0, 0.5 })
        bg:FillParent(3 * S)
        local cover = Texture(a, nil, "ARTWORK")
        cover:SetPoint("TOPLEFT", bg, "TOPLEFT", 0, 0)
        cover:AlignParentBottomRight()
        cover:SetColorTexture(0, 0, 0, 0.75)
        GoldBorder(a)

        a.scroll = ScrollFrame(a)
        a.scroll:AlignParentTopLeft(3 * S, 4 * S)
        a.scroll:AlignParentBottomRight(5 * S, 0)
        a.scroll:SetFrameLevel(a:GetFrameLevel() + 3)
        a.content = Frame("Frame", a.scroll)
        a.content:SetSize(1, 1)
        a.scroll:SetScrollChild(a.content)
        a.bar = self:MakeScrollBar(a, a.scroll)
    end;

    -- The filter dropdown in the details strip: All / Completed /
    -- Incomplete, shown with the list only.
    _BuildFilter = function(self)
        self.filter = DropdownSimple(self.details, "MUI_AchievementFilter")
        self.filter:SetSize(116 * S, FILTER_H)
        self.filter:SetText(FILTERS[1][2])
        self.filterMenu = DropdownMenu(self.filter, "MUI_AchievementFilterMenu", self.filter)
        self.filterMenu:SetMenuWidth(120 * S)
        local items = {}
        for _, f in ipairs(FILTERS) do
            items[#items + 1] = {
                label = f[2],
                OnClick = function()
                    self.filterMode = f[1]
                    self.filter:SetText(f[2])
                    self:_RefreshList()
                end,
            }
        end
        self.filterMenu:SetItems(items)
        self.filter.OnClick = function() self.filterMenu:Toggle() end
    end;

    _BuildTabs = function(self)
        self.tabAchievements = AchievementTab(self, "Achievements", function() self:_SelectTab(1) end)
        self.tabAchievements:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 17 * S, 3 * S)
        self.tabStatistics = AchievementTab(self, "Statistics", function() self:_SelectTab(2) end)
        self.tabStatistics:SetPoint("LEFT", self.tabAchievements, "RIGHT", -5 * S, 0)
        self:_SelectTab(1)
    end;

    -- A scroll bar beside `scroll` — `x` from the parent's right edge, `top`
    -- / `bottom` in from its corners — wired to it and to the mouse wheel.
    MakeScrollBar = function(self, parent, scroll, x, top, bottom)
        local bar = MinimalScrollBar(parent, nil, 8 * S, 8 * S)
        bar:SetPoint("TOPLEFT", parent, "TOPRIGHT", (x or 6) * S, -(top or 8) * S)
        bar:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", (x or 6) * S, (bottom or 6) * S)
        bar:SetMinMax(0, 0)
        bar.OnScroll = function(_, value) scroll:SetVerticalScroll(value) end
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(_, delta)
            bar:SetValue(bar:GetValue() - delta * 40 * S)
        end)
        return bar
    end;

    -- Size `content` to `contentH` (the viewport at least) and set the bar's range.
    FitScroll = function(self, scroll, content, bar, contentH)
        local viewH = scroll:GetHeight() or 0
        local viewW = scroll:GetWidth() or 0
        local childH = math.max(contentH, viewH, 1)
        content:SetWidth(math.max(viewW, 1))
        content:SetHeight(childH)
        scroll:UpdateScrollChildRect()
        local maxScroll = math.max(0, childH - viewH)
        bar:SetMinMax(0, maxScroll)
        bar:SetContentSize(viewH, childH)
        if bar:GetValue() > maxScroll then bar:SetValue(maxScroll) end
    end;

    -- ---- state ---------------------------------------------------------

    -- total, earned for a category; the Summary counts everything.
    CategoryProgress = function(self, catId)
        if catId == SUMMARY then
            return #self.engine.list, self.engine:GetNumEarned()
        end
        return self.engine:GetCategoryNum(catId)
    end;

    CategoryName = function(self, catId)
        for _, cat in ipairs(MUI_AchievementDB:GetCategories()) do
            if cat.id == catId then return cat.name end
        end
        return ""
    end;

    Toggle = function(self)
        if self:IsShown() then self:Hide() else self:Show() end
    end;

    -- Show the panel on an achievement (toast click, meta member).
    Open = function(self, id)
        self:Show()
        if id then self:SelectAchievement(id) end
    end;

    SelectCategory = function(self, catId)
        self.selectedCategory = catId
        self.selectedAch = nil
        self.list.scroll:SetVerticalScroll(0)
        self:_SelectTab(1)
    end;

    SelectStatCategory = function(self, catId)
        self.selectedStat = catId
        self.statistics.bar:SetValue(0)
        self:_SelectTab(2)
    end;

    -- Expand `id` (nil collapses), switching category when it lives
    -- elsewhere; such a jump is remembered for Back.
    SelectAchievement = function(self, id)
        local fromCategory, fromAch = self.selectedCategory, self.selectedAch
        self.selectedAch = id
        if id then
            local def = self.engine:GetDef(id)
            local cat = def and (def.sub or def.cat)
            if cat and cat ~= self.selectedCategory then
                table.insert(self.history, { category = fromCategory, achievement = fromAch })
                self.selectedCategory = cat
                self.list.scroll:SetVerticalScroll(0)
            end
            self:_SelectTab(1)
        else
            self:_RefreshList()
        end
        if not id then return end
        -- scroll the row into view
        for _, row in ipairs(self.rows) do
            if row:IsShown() and row.achId == id then
                local top = self.list.content:GetTop()
                local y = (top and row:GetTop()) and (top - row:GetTop()) or 0
                local viewH = self.list.scroll:GetHeight() or 0
                local cur = self.list.scroll:GetVerticalScroll()
                if y < cur or y + (row:GetHeight() or 0) > cur + viewH then
                    local maxScroll = math.max(0, (self.list.content:GetHeight() or 0) - viewH)
                    self.list.bar:SetValue(math.max(0, math.min(y, maxScroll)))
                end
                break
            end
        end
    end;

    -- Back: the selection before the last jump.
    GoBack = function(self)
        local entry = table.remove(self.history)
        if not entry then return end
        self.selectedCategory = entry.category
        self.selectedAch = entry.achievement
        self.list.scroll:SetVerticalScroll(0)
        self:_SelectTab(1)
    end;

    -- Tab 1 shows the Summary or the list (with the filter in the strip),
    -- tab 2 the statistics.
    _SelectTab = function(self, index)
        self.tab = index
        self.tabAchievements:SetSelected(index == 1)
        self.tabStatistics:SetSelected(index == 2)
        local summary = index == 1 and self.selectedCategory == SUMMARY
        local filter = index == 1 and not summary
        self.summary:SetVisible(summary)
        self.list:SetVisible(filter)
        self.filter:SetVisible(filter)
        self:_LayoutDetails(filter)
        self.statistics:SetVisible(index == 2)
        self:_RefreshCurrent()
    end;

    _RefreshCurrent = function(self)
        if self.tab == 2 then
            self.statistics:Refresh(self.selectedStat)
        elseif self.selectedCategory == SUMMARY then
            self.summary:Refresh()
        else
            self:_RefreshList()
        end
        self:_RefreshCategories()
        self.points:SetText(self.engine:GetTotalPoints())
        self.back:SetEnabled(#self.history > 0)
    end;

    -- Rail rows of the tab's list: the selected branch's sub-categories
    -- shown under their parent, the selected label white.
    _RefreshCategories = function(self)
        local stats = self.tab == 2
        local rows = stats and self.statRows or self.categoryRows
        local selected = stats and self.selectedStat or self.selectedCategory
        for _, row in ipairs(stats and self.categoryRows or self.statRows) do row:Hide() end
        local selectedParent
        for _, row in ipairs(rows) do
            if row.cat.id == selected then
                selectedParent = row.cat.parent or row.cat.id
            end
        end
        local prev, n = nil, 0
        for _, row in ipairs(rows) do
            local visible = not row.cat.parent or row.cat.parent == selectedParent
            row:SetVisible(visible)
            if visible then
                n = n + 1
                row:ClearAllPoints()
                if prev then row:Below(prev) else row:AlignParentTop() end
                prev = row
            end
            row:SetSelected(row.cat.id == selected)
        end
        local c = self.categories
        self:FitScroll(c.scroll, c.content, c.bar, math.max(n, 1) * CAT_ROW_H)
    end;

    -- The selected category's rows through the filter, pooled; the
    -- selected one expanded.
    _RefreshList = function(self)
        if not self.selectedCategory or self.selectedCategory == SUMMARY then return end
        if self.objectives.id ~= self.selectedAch then
            self.objectives:Clear()
            self.objectives:Hide()
        end
        local defs = {}
        for _, def in ipairs(self.engine.byCat[self.selectedCategory] or {}) do
            local earned = self.engine:IsEarned(def.id)
            if self.filterMode == 1 or (self.filterMode == 2) == earned then
                defs[#defs + 1] = def
            end
        end
        local content = self.list.content
        local total, prev = 2 * S, nil
        for i, def in ipairs(defs) do
            local row = self.rows[i]
            if not row then
                row = AchievementRow(content, self)
                self.rows[i] = row
            end
            row:ClearAllPoints()
            row:AlignParentLeft()
            row:AlignParentRight(4 * S)
            if prev then row:Below(prev) else row:AlignParentTop(2 * S) end
            row:SetAchievement(def, self.objectives)
            row:Show()
            total = total + (row:GetHeight() or ROW_COLLAPSED_H)
            prev = row
        end
        for i = #defs + 1, #self.rows do self.rows[i]:Hide() end
        self:FitScroll(self.list.scroll, content, self.list.bar, total)
    end;
}
