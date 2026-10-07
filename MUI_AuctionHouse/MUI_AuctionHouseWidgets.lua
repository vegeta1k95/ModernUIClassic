-- MUI_AuctionHouseWidgets: the small controls the auction house panels share.
--
--   AuctionHouseTab          a window tab (hanging under the window, or
--                            standing on a panel's top edge)
--   AuctionHouseInput        retail's large input field
--   AuctionHouseMoneyInput   gold / silver / copper in three of those
--   AuctionHouseScrollArea   a scrolling column for a short list of rows

local Style = MUI_AuctionHouseStyle
local S     = Style.S

local TAB_ATLAS = MUI_AtlasRegistry.TabBottom

-- ---------------------------------------------------------------------
-- AuctionHouseScrollArea: a scroll frame of `width` x `height` pixels with
-- its content child and a scroll bar `gap` to its right, the mouse wheel
-- wired. The owner parents its rows to `content` and reports their total
-- height through SetContentHeight.
-- ---------------------------------------------------------------------
class "AuctionHouseScrollArea" : extends "ScrollFrame" {
    __init = function(self, parent, width, height, gap, step)
        ScrollFrame.__init(self, parent)
        self:SetSize(width, height)

        self.content = Frame("Frame", self)
        self.content:SetSize(width, height)
        self:SetScrollChild(self.content)

        self.bar = MinimalScrollBar(parent, nil, 8 * S, 8 * S)
        self.bar:SetHeight(height - 8 * S)
        self.bar:RightOf(self, gap)
        self.bar:SetScrollSpeed(step)
        self.bar.OnScroll = function(_, value) self:SetVerticalScroll(value) end

        self:EnableMouseWheel(true)
        self:SetScript("OnMouseWheel", function(_, delta)
            self.bar:SetValue(self.bar:GetValue() - delta * step)
        end)
    end;

    SetContentHeight = function(self, contentHeight)
        local viewHeight = self:GetHeight()
        self.content:SetHeight(math.max(contentHeight, viewHeight))
        self:UpdateScrollChildRect()
        self.bar:SetMinMax(0, math.max(0, contentHeight - viewHeight))
        self.bar:SetContentSize(viewHeight, math.max(contentHeight, 1))
        self:SetVerticalScroll(self.bar:GetValue())
    end;
}

-- ---------------------------------------------------------------------
-- AuctionHouseTab: the frame tab the other windows use (TabFrame's art and
-- metrics), as a plain button. TabFrame is a secure frame, and a secure
-- frame under the window would make showing and hiding it protected in
-- combat; nothing here needs to be secure.
-- ---------------------------------------------------------------------
class "AuctionHouseTab" : extends "Button" {

    HEIGHT          = 31,
    HEIGHT_SELECTED = 36,

    __init = function(self, parent, text, top)
        Button.__init(self, parent)
        self:SetClickSound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        self._top = top and true or false

        self._pieces = self:_Slices("BACKGROUND")
        self._hover  = self:_Slices("HIGHLIGHT")
        for _, t in ipairs(self._hover) do
            t:SetBlendMode("ADD")
            t:SetAlpha(0.4)
        end

        self._label = Style:Label(self, 9, 1, 0.82, 0)
        self._label:SetText(text)
        self:SetWidth(math.max(80, self._label:GetStringWidth() + 40))

        self.OnEnter = function() self._label:SetTextColor(1, 1, 1, 1) end
        self.OnLeave = function() self:_ColorLabel() end
        self:SetSelected(false)
    end;

    -- Left cap, right cap and the run between, each the tab's full height.
    _Slices = function(self, layer)
        local left = Texture(self, nil, layer)
        left:SetWidth(35)
        left:AlignParentTopLeft()
        left:AlignParentBottomLeft()
        local right = Texture(self, nil, layer)
        right:SetWidth(37)
        right:AlignParentTopRight()
        right:AlignParentBottomRight()
        local middle = Texture(self, nil, layer)
        middle:FillBetweenH(left, right)
        return { left, middle, right }
    end;

    -- A top tab shows the same art upside down.
    _Apply = function(self, texture, region)
        local info = TAB_ATLAS:GetRegion(region)
        texture:SetTexture(info.file)
        if self._top then
            texture:SetTexCoord(info.left, info.right, info.bottom, info.top)
        else
            texture:SetTexCoord(info.left, info.right, info.top, info.bottom)
        end
    end;

    _ColorLabel = function(self)
        if self._selected then
            self._label:SetTextColor(1, 1, 1, 1)
        else
            self._label:SetTextColor(1, 0.82, 0, 1)
        end
    end;

    IsSelected = function(self)
        return self._selected
    end;

    -- The selected tab is the taller, brighter set; the caller anchors a tab
    -- by the edge it shares with the window, so it grows away from it.
    SetSelected = function(self, selected)
        self._selected = selected and true or false
        local suffix = self._selected and "Active" or ""
        for _, set in ipairs({ self._pieces, self._hover }) do
            self:_Apply(set[1], "TabLeft" .. suffix)
            self:_Apply(set[2], "TabMiddle" .. suffix)
            self:_Apply(set[3], "TabRight" .. suffix)
        end
        self:SetHeight(self._selected and self.HEIGHT_SELECTED or self.HEIGHT)
        self._label:ClearAllPoints()
        if self._top then
            self._label:CenterInParent(-2, self._selected and -2 or -4)
        else
            self._label:CenterInParent(-2, self._selected and 2 or 4)
        end
        self:_ColorLabel()
    end;
}


-- ---------------------------------------------------------------------
-- AuctionHouseInput: retail's LargeInputBoxTemplate — an edit box on the
-- three-piece auctionhouse-ui-inputfield plate. `width` and `rightInset`
-- (room kept clear at the right, for a coin) are in retail's units.
-- ---------------------------------------------------------------------
local INPUT_H = 33
local CAP_W   = 8

class "AuctionHouseInput" : extends "EditBox" {

    HEIGHT = INPUT_H,

    __init = function(self, parent, width, rightInset)
        EditBox.__init(self, parent, nil, "InputBoxScriptTemplate")
        self:SetAutoFocus(false)
        self:SetSize(width * S, INPUT_H * S)
        self:SetFont(MUI.FONT, 11, "")
        self:SetTextInsets((CAP_W + 3) * S, ((rightInset or CAP_W) + 3) * S, 0, 0)

        local left = Style:Piece(self, "BACKGROUND", "InputFieldLeft", CAP_W, INPUT_H)
        left:AlignParentLeft()
        local right = Style:Piece(self, "BACKGROUND", "InputFieldRight", CAP_W, INPUT_H)
        right:AlignParentRight()
        local middle = Style:Piece(self, "BACKGROUND", "InputFieldMiddle", CAP_W, INPUT_H)
        middle:FillBetweenH(left, right)

        self.OnEnterPressed = function() self:ClearFocus() end
        -- a click anywhere else drops the focus
        self:RegisterEventHandler("GLOBAL_MOUSE_DOWN", function()
            if self._focused and not self:IsMouseOver() then self:ClearFocus() end
        end)
    end;
}


-- ---------------------------------------------------------------------
-- AuctionHouseMoneyInput: retail's LargeMoneyInputFrame — gold taking the
-- room left, then silver and copper, each with its coin inside the field.
-- OnChanged(self) fires on every edit.
-- ---------------------------------------------------------------------
local MONEY_W   = 230
local SMALL_W   = 64
local MONEY_GAP = 6
local COIN      = 12

class "AuctionHouseMoneyInput" : extends "Frame" {

    WIDTH = MONEY_W,

    __init = function(self, parent)
        Frame.__init(self, "Frame", parent)
        self:SetSize(MONEY_W * S, INPUT_H * S)
        self._quiet = false

        self._copper = self:_Field(SMALL_W, 2, "CoinCopper")
        self._copper:AlignParentRight()
        self._silver = self:_Field(SMALL_W, 2, "CoinSilver")
        self._silver:LeftOf(self._copper, MONEY_GAP * S)
        self._gold = self:_Field(MONEY_W - 2 * (SMALL_W + MONEY_GAP), 6, "CoinGold")
        self._gold:AlignParentLeft()

        self._gold:SetScript("OnTabPressed", function() self._silver:SetFocus() end)
        self._silver:SetScript("OnTabPressed", function() self._copper:SetFocus() end)
        self._copper:SetScript("OnTabPressed", function() self._gold:SetFocus() end)
    end;

    _Field = function(self, width, letters, coin)
        local box = AuctionHouseInput(self, width, COIN + 9)
        box:SetNumeric(true)
        box:SetMaxLetters(letters)
        box:SetJustifyH("RIGHT")
        local icon = Style:Piece(box, "OVERLAY", coin, COIN, COIN)
        icon:AlignParentRight(10 * S)
        box.OnTextChanged = function()
            if not self._quiet and self.OnChanged then self:OnChanged() end
        end
        return box
    end;

    GetCopper = function(self)
        return self._gold:GetNumber() * 10000 + self._silver:GetNumber() * 100 + self._copper:GetNumber()
    end;

    SetCopper = function(self, copper)
        copper = math.max(0, math.floor((copper or 0) + 0.5))
        self._quiet = true
        self._gold:SetNumber(math.floor(copper / 10000))
        self._silver:SetNumber(math.floor(copper / 100) % 100)
        self._copper:SetNumber(copper % 100)
        self._quiet = false
        if self.OnChanged then self:OnChanged() end
    end;

    ClearFocus = function(self)
        self._gold:ClearFocus()
        self._silver:ClearFocus()
        self._copper:ClearFocus()
    end;
}
