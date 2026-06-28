-- RecipeListRow: single row widget used by the tradeskill list pane for all
-- three row types — category headers, recipe rows, and the non-interactive
-- "Unlearned" divider. SetData / SetDivider / Clear swap the visible visuals.
--
-- Layout constants live on the class (RecipeListRow.ROW_HEIGHT etc.) so the
-- list pane's painter can read them without duplicating values here.

local TEX_BASE  = MUI.TEX_SKIN .. "professions\\tradeskill\\"
local TEX_ATLAS = TEX_BASE .. "tradeskill"

-- Vanilla difficulty colors (Blizzard_TradeSkillUI.lua:6-10).
local SKILL_COLOR = {
    optimal = { 1.00, 0.50, 0.25 },
    medium  = { 1.00, 1.00, 0.00 },
    easy    = { 0.25, 0.75, 0.25 },
    trivial = { 0.50, 0.50, 0.50 },
    header  = { 1.00, 0.82, 0.00 },
}

-- Per-skill-type texcoord for the skill-up arrow icon on the left of each
-- recipe row. Lifted from DFUI's ProfessionFrame.mixin.lua:3218-3238.
local SKILL_UP_ICON_COORD = {
    optimal = { 0.263184, 0.269531, 0.0537109, 0.0683594 },  -- orange ↑
    medium  = { 0.294922, 0.301270, 0.0537109, 0.0683594 },  -- yellow ↑
    easy    = { 0.255859, 0.262207, 0.0537109, 0.0683594 },  -- green  ↑
}

-- Single row widget used for both recipes and category headers. SetData
-- swaps visuals between modes — categories get the 3-slice DFUI background
-- + chevron, recipes get the skill-up icon column + highlight/selected
-- overlays + count text.
class "RecipeListRow" : extends "Button" {

    -- Layout constants exposed for the list painter (see _PaintRecipeRows).
    ROW_HEIGHT  = 20,
    CAT_HEIGHT  = 26,
    DIV_HEIGHT  = 26,  -- "Unlearned" divider (line + label)
    ROW_GAP     = 2,
    CAT_GAP     = 4,
    DIV_GAP     = 4,
    DIV_TOP_PAD = 14,  -- extra space above the unlearned divider

    __init = function(self, parent)
        Button.__init(self, parent)
        self:SetHeight(self.ROW_HEIGHT)
        self:EnableMouse(true)

        -- ===== Category 3-slice background (header mode only) =====
        -- Texcoords from DFProfessionFrameRecipeCategoryTemplate XML.
        self._catL = Texture(self, nil, "BACKGROUND")
        self._catL:SetTexture(TEX_ATLAS)
        self._catL:SetTexCoord(0.432129, 0.438965, 0.0273438, 0.0527344)
        self._catL:SetWidth(14)
        self._catL:FillHeight()
        self._catL:AlignParentLeft()

        self._catR = Texture(self, nil, "BACKGROUND")
        self._catR:SetTexture(TEX_ATLAS)
        self._catR:SetTexCoord(0.455078, 0.461914, 0.0449219, 0.0703125)
        self._catR:SetWidth(14)
        self._catR:FillHeight()
        self._catR:AlignParentRight()

        self._catC = Texture(self, nil, "BACKGROUND")
        self._catC:SetTexture(TEX_ATLAS)
        self._catC:SetTexCoord(0.346191, 0.34668, 0.0419922, 0.0673828)
        self._catC:FillHeight()
        self._catC:RightOf(self._catL, 0)
        self._catC:LeftOf(self._catR, 0)

        -- Chevron for collapse state (category only).
        self._chev = Texture(self, nil, "ARTWORK")
        self._chev:SetTextureRegion(TEX_ATLAS, 2048, 1024, 621, 54, 20, 19)
        self._chev:SetSize(11, 11)
        self._chev:AlignParentRight(10)

        -- ===== Recipe-row content =====
        -- SkillUps icon: anchored on the left of the row (DFUI uses LEFT -9
        -- relative to a 26-wide button — net effect is the icon's left edge
        -- at row.LEFT + 4 since the icon is 13 wide anchored to the button's
        -- RIGHT). Size 13×15. We just inline the math: the icon sits at
        -- row.LEFT + 4 vertically centered.
        self._skillUp = Texture(self, nil, "OVERLAY")
        self._skillUp:SetTexture(TEX_ATLAS)
        self._skillUp:SetSize(13, 15)
        self._skillUp:AlignParentLeft(14)

        -- Multi-skill-up count (only shown for optimal recipes with >1).
        -- Anchored to the LEFT of the skill-up icon.
        self._skillUpText = FontString(self, nil, "OVERLAY")
        self._skillUpText:SetFontSize(10)
        self._skillUpText:SetJustifyH("RIGHT")
        self._skillUpText:SetPoint("RIGHT", self._skillUp, "LEFT", -1, 0)

        -- Recipe name. LEFT anchored just right of the icon column; RIGHT
        -- floats — Count appears to its right via Count's LEFT anchor.
        self._label = FontString(self, nil, "OVERLAY")
        self._label:SetFontSize(12)
        self._label:SetJustifyH("LEFT")
        self._label:SetWordWrap(false)
        self._label:RightOf(self._skillUp, 6)

        -- Numeric-available count, immediately after the label.
        self._count = FontString(self, nil, "OVERLAY")
        self._count:SetFontSize(12)
        self._count:SetJustifyH("LEFT")
        self._count:RightOf(self._label)

        -- ===== Hover + Selected overlays =====
        -- Texcoords from DFProfessionFrameRecipeTemplate XML.
        self._hl = Texture(self, nil, "HIGHLIGHT")
        self._hl:SetTexture(TEX_ATLAS)
        self._hl:SetTexCoord(0.622559, 0.773438, 0.0380859, 0.0585938)
        self._hl:SetPoint("LEFT",  self, "LEFT",  0, 0)
        self._hl:SetPoint("RIGHT", self, "RIGHT", 0, 0)
        self._hl:FillHeight()
        self._hl:SetAlpha(0.5)

        self._sel = Texture(self, nil, "ARTWORK")
        self._sel:SetTexture(TEX_ATLAS)
        self._sel:SetTexCoord(0.788086, 0.918457, 0.0380859, 0.0566406)
        self._sel:SetPoint("LEFT",  self, "LEFT",  0, 0)
        self._sel:SetPoint("RIGHT", self, "RIGHT", 0, 0)
        self._sel:FillHeight()
        self._sel:Hide()

        -- ===== "Unlearned" divider (line + label). Retail uses the
        -- Options_HorizontalDivider atlas with a second ADD-blended copy at
        -- 0.5 alpha for a soft glow; we mirror that exactly.
        self._divLine = Texture(self, nil, "ARTWORK")
        self._divLine:SetAtlas(MUI_AtlasRegistry.Options, "HorizontalDivider", true)
        self._divLine:SetHeight(2)
        self._divLine:SetPoint("BOTTOMLEFT",  self, "BOTTOMLEFT",   5, 5)
        self._divLine:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -5, 5)
        self._divLine:SetVertexColor(1, 0.82, 0, 1)
        self._divLine:Hide()

        self._divLineGlow = Texture(self, nil, "ARTWORK")
        self._divLineGlow:SetAtlas(MUI_AtlasRegistry.Options, "HorizontalDivider", true)
        self._divLineGlow:SetHeight(2)
        self._divLineGlow:SetPoint("BOTTOMLEFT",  self, "BOTTOMLEFT",   5, 5)
        self._divLineGlow:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -5, 5)
        self._divLineGlow:SetVertexColor(1, 0.82, 0, 0.5)
        self._divLineGlow:SetBlendMode("ADD")
        self._divLineGlow:Hide()

        self._divLabel = FontString(self, nil, "OVERLAY")
        self._divLabel:SetFontSize(12)
        self._divLabel:SetJustifyH("LEFT")
        self._divLabel:SetTextColor(1, 0.82, 0, 1)
        self._divLabel:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 10, 9)
        self._divLabel:Hide()
    end;

    -- Recipe row: (false, skillType, name, numAvailable, numSkillUps, selected, dimmed?)
    -- Category:    (true,  isExpanded, name)
    -- `dimmed` paints the recipe name + count in grey (used by the
    -- "Unlearned" section rows). Skillup arrow rendering is untouched.
    SetData = function(self, isCategory, arg1, name, numAvailable, numSkillUps, selected, dimmed)
        self._isCategory = isCategory
        self:EnableMouse(true)
        self._divLine:Hide(); self._divLineGlow:Hide(); self._divLabel:Hide()
        if isCategory then
            -- DFUI plays IG_MAINMENU_OPTION on category clicks (mixin:2594)
            -- and IG_MAINMENU_OPTION_CHECKBOX_ON on recipe clicks (mixin:2629).
            self:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION)
            self._catL:Show(); self._catC:Show(); self._catR:Show(); self._chev:Show()
            self._skillUp:Hide(); self._skillUpText:SetText("")
            self._count:SetText("")
            self._sel:Hide(); self._hl:SetAlpha(0)
            self:SetHeight(self.CAT_HEIGHT)

            self._chev:SetTextureRegion(TEX_ATLAS, 2048, 1024, arg1 and 555 or 621, 54, 20, 19)

            local c = SKILL_COLOR.header
            self._label:ClearAllPoints()
            self._label:AlignParentLeft(10)
            self._label:SetTextColor(c[1], c[2], c[3])
            self._label:SetText(name or "")
            self._label:SetWidth(self._label:GetStringWidth())
        else
            self:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            self._catL:Hide(); self._catC:Hide(); self._catR:Hide(); self._chev:Hide()
            self._hl:SetAlpha(0.5)
            self:SetHeight(self.ROW_HEIGHT)

            local c = dimmed and { 0.5, 0.5, 0.5 } or { 1, 1, 1 }
            self._label:ClearAllPoints()
            self._label:RightOf(self._skillUp, 6)
            self._label:SetTextColor(c[1], c[2], c[3])
            self._label:SetText(name or "")

            local wStr = self._label:GetStringWidth()
            local wSelf = self:GetWidth()

            self._label:SetWidth(math.min(wStr, wSelf - 50))
            self._count:SetTextColor(c[1], c[2], c[3])

            -- Available-count "[N]" to the right of the name.
            if numAvailable and numAvailable > 0 then
                self._count:SetText(" [" .. numAvailable .. "]")
            else
                self._count:SetText("")
            end

            -- Skill-up icon — only for easy / medium / optimal. Trivial and
            -- difficult get no arrow. Multi-skill-up count (only happens on
            -- optimal recipes with numSkillUps > 1) appears to the icon's left.
            local coord = SKILL_UP_ICON_COORD[arg1]
            if coord then
                self._skillUp:SetTexCoord(coord[1], coord[2], coord[3], coord[4])
                self._skillUp:Show()
                if arg1 == "optimal" and numSkillUps and numSkillUps > 1 then
                    self._skillUpText:SetText(numSkillUps)
                    self._skillUpText:SetTextColor(c[1], c[2], c[3])
                else
                    self._skillUpText:SetText("")
                end
            else
                self._skillUp:Hide()
                self._skillUpText:SetText("")
            end

            if selected then self._sel:Show() else self._sel:Hide() end
        end
    end;

    -- Non-interactive separator between the learned and unlearned sections.
    -- Two stacked Options_HorizontalDivider strips + a label above the line,
    -- matching retail's ProfessionsRecipeListDividerTemplate.
    SetDivider = function(self, text)
        self._isCategory = false
        self:EnableMouse(false)
        self._catL:Hide(); self._catC:Hide(); self._catR:Hide(); self._chev:Hide()
        self._skillUp:Hide(); self._skillUpText:SetText("")
        self._sel:Hide(); self._hl:SetAlpha(0)
        self._count:SetText("")
        self._label:SetText("")
        self._divLine:Show()
        self._divLineGlow:Show()
        self._divLabel:SetText(text or "")
        self._divLabel:Show()
        self:SetHeight(self.DIV_HEIGHT)
    end;

    Clear = function(self)
        self._catL:Hide(); self._catC:Hide(); self._catR:Hide()
        self._chev:Hide(); self._sel:Hide(); self._hl:SetAlpha(0)
        self._skillUp:Hide(); self._skillUpText:SetText("")
        self._divLine:Hide(); self._divLineGlow:Hide(); self._divLabel:Hide()
        self._label:SetText("")
        self._count:SetText("")
    end;
}
