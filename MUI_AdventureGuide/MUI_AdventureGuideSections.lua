-- MUI_AdventureGuideSections: a boss's page of the journal — its lore, then
-- its abilities as paper headers that fold (retail's detailsScroll and its
-- EncounterInfoTemplate headers). A header with a creature's portrait groups
-- the abilities of one of the boss's creatures or forms.
--
-- Retail opens a boss with every header folded but those its data marks to
-- start open; this data has no such mark, and (as in NewEra) everything
-- starts unfolded. What the player folds stays folded while the session
-- lasts.
--
--   AdventureGuideAbilities(parent, page)
--     :SetEncounter(encounter)
--     :Reveal(chain)        unfold down to a section and scroll to it

local Style = MUI_AdventureGuideStyle

local VIEW_W, VIEW_H = 320, 383
local HEADER_H   = 24
local INDENT     = 15            -- a nested header, from its parent's left
local BUTTON_GAP = 6             -- under a folded header
local TEXT_GAP   = 27            -- under an unfolded header's text
local TEXT_MARGIN = 10           -- the text, in from the header's sides
local MAX_FLAGS  = 4
local FLAG_SIZE, FLAG_PITCH = 20, 22

local UNFOLDED = { 0.929, 0.788, 0.620 }
local FOLDED   = { 0.827, 0.659, 0.463 }

-- ---------------------------------------------------------------------
-- AdventureGuideSection: one header and the text under it.
-- ---------------------------------------------------------------------
class "AdventureGuideSection" : extends "Frame" {
    __init = function(self, parent, owner)
        Frame.__init(self, "Frame", parent)
        self:SetHeight(HEADER_H)
        self.owner = owner
        self.node = nil
        self._open = false

        local button = Button(self)
        button:SetHeight(HEADER_H)
        button:AlignParentTopLeft()
        button:AlignParentTopRight()
        button:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self._button = button

        -- The plate: two caps and the band between, under their inner halves.
        self._left = Texture(button, nil, "BACKGROUND")
        self._left:AlignParentLeft(-1, -1)
        self._right = Texture(button, nil, "BACKGROUND")
        self._right:AlignParentRight(-3, -1)
        self._middle = Texture(button, nil, "BACKGROUND")
        self._middle:SetDrawLayer("BACKGROUND", -2)
        self._middle:RightOf(self._left, -32)
        self._middle:LeftOf(self._right, -32)

        local glowLeft = Style:Piece(button, "HIGHLIGHT", "PaperHeader-Highlight-Left")
        glowLeft:AlignParentLeft(-1, -1)
        local glowRight = Style:Piece(button, "HIGHLIGHT", "PaperHeader-Highlight-Right")
        glowRight:AlignParentRight(-3, -1)
        local glowMiddle = Style:Band(button, "HIGHLIGHT", "PaperHeader-Highlight-Mid")
        glowMiddle:RightOf(glowLeft, -32)
        glowMiddle:LeftOf(glowRight, -32)

        self._sign = Style:Label(button, 16, 1, 0.82, 0)
        self._sign:SetSize(12, 12)
        self._sign:AlignParentLeft(5)

        self._icon = Texture(button, nil, "OVERLAY")
        self._icon:SetSize(18, 18)
        self._icon:RightOf(self._sign, 5)

        self._title = Style:Label(button, 12, 1, 0.82, 0)
        self._title:SetJustifyH("LEFT")
        self._title:SetWordWrap(false)
        self._title:SetHeight(10)

        self:_BuildPortrait()
        self:_BuildFlags()

        self._text = Style:Ink(self, "ARTWORK")
        self._text:Below(button, 9)
        self._textPlate = Texture(self, nil, "BACKGROUND")
        Style:SetPiece(self._textPlate, "AbilityTextBG", true)
        self._textPlate:Fill(self._text, -9, -12, -9, -11)
        self._textEdge = Style:Piece(self, "BACKGROUND", "AbilityTextBottomBorder")
        self._textEdge:Below(self._text, 6.5)

        button.OnClick = function() owner:Toggle(self.node) end
        button.OnEnter = function()
            if self._title:IsTruncated() then
                MUI_Tooltip:ShowFor(button, "ANCHOR_RIGHT", function(tip)
                    tip:AddLine(self.node.title, 1, 0.82, 0, true, 13)
                end)
            end
        end
        button.OnLeave = function() MUI_Tooltip:Hide() end
        button:SetScript("OnMouseDown", function() self:_SetPlate(true) end)
        button:SetScript("OnMouseUp", function() self:_SetPlate(false) end)
        button:SetScript("OnHide", function() self:_SetPlate(false) end)
    end;

    -- A creature's header wears its portrait in a ring where an ability's
    -- has its icon; a click shows the creature in the model viewer.
    _BuildPortrait = function(self)
        local portrait = Button(self._button)
        portrait:SetSize(26, 26)
        portrait:CenterAt(self._icon)
        portrait:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self._portrait = portrait

        self._face = Texture(portrait, nil, "OVERLAY")
        self._face:FillParent()
        local ring = Style:Piece(portrait, "OVERLAY", "CreatureHeaderFrameSm", 2)
        ring:CenterInParent()
        local glow = Style:Piece(portrait, "HIGHLIGHT", "CreatureHeaderFrameSm")
        glow:SetBlendMode("ADD")
        glow:CenterInParent()

        portrait.OnClick = function()
            self.owner:ShowCreature(self.node.display, self.node.title)
        end
    end;

    -- What the ability calls for (a tank, a dispel ...), from the right.
    _BuildFlags = function(self)
        self._flags = {}
        for i = 1, MAX_FLAGS do
            local flag = Frame("Frame", self._button)
            flag:SetSize(FLAG_SIZE, FLAG_SIZE)
            flag:AlignParentRight(1 + (i - 1) * FLAG_PITCH)
            flag.icon = Texture(flag, nil, "OVERLAY")
            flag.icon:FillParent()
            flag:SetTooltip("ANCHOR_RIGHT", function(tip)
                tip:AddLine(flag.name, 1, 1, 1, false, 13)
            end)
            self._flags[i] = flag
        end
    end;

    _SetPlate = function(self, pressed)
        local name = "PaperHeader-" .. (self._open and "Select" or "UnSelect") .. (pressed and "Down" or "Up")
        Style:SetPiece(self._left, name .. "-Left")
        Style:SetPiece(self._right, name .. "-Right")
        Style:SetBand(self._middle, name .. "-Mid")
    end;

    -- Show `node` on a header `width` wide; `open` unfolds its text.
    Set = function(self, node, width, topLevel, open)
        self.node = node
        self._open = open
        self:SetWidth(width)
        self:_SetPlate(false)

        local color = open and UNFOLDED or FOLDED
        self._sign:SetText(open and "-" or "+")
        self._sign:SetTextColor(color[1], color[2], color[3], 1)

        local after = self._sign
        if node.display then
            self._face:SetPortraitFromCreatureDisplayID(node.display)
            after = self._portrait
        elseif node.icon then
            self._icon:SetTexture(node.icon)
            after = self._icon
        end
        self._portrait:SetVisible(node.display ~= nil)
        self._icon:SetVisible(node.display == nil and node.icon ~= nil)

        local bits = Style:FlagBits(node.flags or 0)
        local last
        for i, flag in ipairs(self._flags) do
            if bits[i] then
                flag.name = Style:SetFlag(flag.icon, bits[i])
                last = flag
            end
            flag:SetVisible(bits[i] ~= nil)
        end

        self._title:SetFontObject(MUI.FontBySize(topLevel and 14 or 12))
        self._title:SetTextColor(color[1], color[2], color[3], 1)
        self._title:ClearAllPoints()
        self._title:RightOf(after, 5, -1)
        if last then
            self._title:LeftOf(last, 11)
        else
            self._title:AlignParentRight(5)
        end
        self._title:SetText(node.title)

        local shown = open and node.text ~= nil
        if shown then
            self._text:SetWidth(width - 2 * TEXT_MARGIN)
            self._text:SetText(node.text)
            self._textEdge:SetWidth(width - 2 * TEXT_MARGIN + 18)
        end
        self._text:SetVisible(shown)
        self._textPlate:SetVisible(shown)
        self._textEdge:SetVisible(shown)
    end;

    -- Height of the text under the header; nil while there is none showing.
    GetTextHeight = function(self)
        if self._text:IsShown() then return self._text:GetStringHeight() end
    end;
}


class "AdventureGuideAbilities" : extends "Frame" {
    __init = function(self, parent, page)
        Frame.__init(self, "Frame", parent)
        self:SetSize(VIEW_W + 30, VIEW_H)      -- the column, and room for its scroll bar
        self.page = page
        self._folded = {}             -- [section id] = true once the player folds it
        self._sections = {}           -- the headers, reused
        self._used = 0
        self._tops = {}               -- by section on show: its header's offset

        self._scroll = AdventureGuideScroll(self, VIEW_W, VIEW_H, 30)
        self._scroll:AlignParentBottomLeft()
        self._scroll:PlaceBar(15, 6, 6)

        self._lore = Style:Ink(self._scroll.content, "ARTWORK")
        self._lore:SetWidth(VIEW_W - 5)
        self._lore:AlignParentTopLeft(8, 2)
    end;

    SetEncounter = function(self, encounter)
        self._encounter = encounter
        self._lore:SetText(encounter.desc or "")
        self:_Layout()
        self._scroll:ScrollTo(0)
    end;

    Toggle = function(self, node)
        self._folded[node.id] = not self._folded[node.id]
        self:_Layout()
    end;

    ShowCreature = function(self, display, name)
        self.page:ShowCreature(display, name)
    end;

    -- `chain`: the section's headers, outermost first, itself last.
    Reveal = function(self, chain)
        for _, node in ipairs(chain) do
            self._folded[node.id] = nil
        end
        self:_Layout()
        self._scroll:ScrollTo(self._tops[chain[#chain]] - 30)
    end;

    -- Lay `nodes` out from `y` down, a level `depth` in; returns where the
    -- next header goes.
    _Place = function(self, nodes, depth, y)
        for _, node in ipairs(nodes) do
            self._used = self._used + 1
            local section = self._sections[self._used]
            if not section then
                section = AdventureGuideSection(self._scroll.content, self)
                self._sections[self._used] = section
            end
            local open = not self._folded[node.id]
            section:Set(node, VIEW_W - depth * INDENT, depth == 0, open)
            section:ClearAllPoints()
            section:AlignParentTopRight(y, 0)
            section:Show()
            self._tops[node] = y

            local textHeight = section:GetTextHeight()
            if textHeight then
                y = y + HEADER_H + textHeight + TEXT_GAP
            else
                y = y + HEADER_H + BUTTON_GAP
            end
            if open and node.sub then
                y = self:_Place(node.sub, depth + 1, y)
            end
        end
        return y
    end;

    _Layout = function(self)
        self._used = 0
        self._tops = {}
        local y = 8 + self._lore:GetStringHeight() + BUTTON_GAP
        y = self:_Place(self._encounter.sections or {}, 0, y)
        for i = self._used + 1, #self._sections do
            self._sections[i]:Hide()
        end
        self._scroll:SetContentHeight(y + 4)
    end;
}
