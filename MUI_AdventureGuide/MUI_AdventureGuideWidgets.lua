-- MUI_AdventureGuideWidgets: the controls the Adventure Guide's pages share.
--
--   AdventureGuideScroll     a scrolling column and its scroll bar
--   AdventureGuideSideTab    a tab on the journal's right edge
--   AdventureGuideNavBar     the breadcrumb bar under the title

local Style = MUI_AdventureGuideStyle

-- ---------------------------------------------------------------------
-- AdventureGuideScroll: a scroll frame of `width` x `height` with its
-- content child, the mouse wheel wired, and a scroll bar (public: the owner
-- places it) that shows only while there is something to scroll. The owner
-- parents its rows to `content` and reports their total height; its
-- OnScroll(value), if set, hears of every move.
-- ---------------------------------------------------------------------
class "AdventureGuideScroll" : extends "ScrollFrame" {
    __init = function(self, parent, width, height, step)
        ScrollFrame.__init(self, parent)
        self:SetSize(width, height)

        self.content = Frame("Frame", self)
        self.content:SetSize(width, height)
        self:SetScrollChild(self.content)

        self.bar = MinimalScrollBar(parent)
        self.bar:SetScrollSpeed(step)
        self.bar.OnScroll = function(_, value)
            self:SetVerticalScroll(value)
            if self.OnScroll then self:OnScroll(value) end
        end
        self.bar:Hide()

        self:EnableMouseWheel(true)
        self:SetScript("OnMouseWheel", function(_, delta)
            self.bar:SetValue(self.bar:GetValue() - delta * step)
        end)
    end;

    -- Seat the bar `gap` right of the view, its ends `top` under the view's
    -- top edge and `bottom` over its bottom edge.
    PlaceBar = function(self, gap, top, bottom)
        self.bar:SetHeight(self:GetHeight() - top - bottom)
        self.bar:ClearAllPoints()
        self.bar:RightOf(self, gap, (bottom - top) / 2)
    end;

    SetContentHeight = function(self, contentHeight)
        local viewHeight = self:GetHeight()
        self.content:SetHeight(math.max(contentHeight, viewHeight))
        self:UpdateScrollChildRect()
        self.bar:SetVisible(contentHeight > viewHeight)
        self.bar:SetMinMax(0, math.max(0, contentHeight - viewHeight))
        self.bar:SetContentSize(viewHeight, math.max(contentHeight, 1))
        self:SetVerticalScroll(self.bar:GetValue())
    end;

    -- Scroll so that `offset` from the content's top is at the view's top
    -- (as far as the content goes).
    ScrollTo = function(self, offset)
        self.bar:SetValue(offset)
    end;

    GetScroll = function(self)
        return self.bar:GetValue()
    end;
}


-- ---------------------------------------------------------------------
-- AdventureGuideSideTab: one of the tabs on the journal's right edge
-- (EncounterTabTemplate) — the paper tab with an icon that lights up when
-- its page shows. `icon` names the sheet's Tab-<icon>-Selected / UnSelected
-- pieces.
-- ---------------------------------------------------------------------
class "AdventureGuideSideTab" : extends "Button" {
    __init = function(self, parent, icon, tooltip)
        Button.__init(self, parent)
        self:SetSize(63, 57)
        self:SetClickSound(SOUNDKIT.IG_ABILITY_PAGE_TURN)

        Style:SetPiece(self:SetNormalTexture(Style.ART .. "journal"), "Tab-UnSelected", true)
        Style:SetPiece(self:SetPushedTexture(Style.ART .. "journal"), "Tab-Selected", true)
        self._disabled = self:SetDisabledTexture(Style.ART .. "journal")
        Style:SetPiece(self._disabled, "Tab-UnSelected", true)
        self._disabled:SetDesaturated(true)
        local highlight = self:SetHighlightTexture(Style.ART .. "journal")
        Style:SetPiece(highlight, "Tab-Highlight", true)
        highlight:SetBlendMode("ADD")

        self._iconOff = Style:Piece(self, "OVERLAY", "Tab-" .. icon .. "-UnSelected")
        self._iconOff:AlignParentRight(6)
        self._iconOn = Style:Piece(self, "OVERLAY", "Tab-" .. icon .. "-Selected")
        self._iconOn:CenterAt(self._iconOff)

        self:SetTooltip("ANCHOR_RIGHT", function(tip)
            tip:AddLine(tooltip, 1, 1, 1, false, 13)
        end)
        self:SetSelected(false)
    end;

    SetSelected = function(self, selected)
        self._iconOn:SetVisible(selected)
        self._iconOff:SetVisible(not selected)
        if selected then self:LockHighlight() else self:UnlockHighlight() end
    end;

    ---@override
    SetEnabled = function(self, enabled)
        Button.SetEnabled(self, enabled)
        self._iconOff:SetDesaturated(not enabled)
    end;
}


-- ---------------------------------------------------------------------
-- AdventureGuideNavBar: Home > instance > boss. The world map's bar in
-- retail's size: its art and buttons are built for a bar 21.5 high, so the
-- bar is that, scaled up to the journal's 500x34.
--
--   :SeatAt(top, left)  its top left corner, from its parent's
--   :SetPath(crumbs)    crumbs = { { text, OnClick, items }, ... } left to
--                       right; the last is the page on show. `items` are the
--                       crumb's dropdown entries (DropdownMenu items); a
--                       menu is rebuilt only for another list, so pass the
--                       same table for the same entries.
--   .OnHome             called on a click on Home
-- ---------------------------------------------------------------------
local NAV_HEIGHT = 21.5
local NAV_SCALE  = 34 / NAV_HEIGHT
local NAV_MENU_WIDTH = 230        -- "Stratholme - Service Entrance" in a menu row

class "AdventureGuideNavBar" : extends "MapNavBar" {
    __init = function(self, parent)
        Frame.__init(self, "Frame", parent, "MUI_AdventureGuideNavBar")
        self:SetScale(NAV_SCALE)
        self:SetSize(500 / NAV_SCALE, NAV_HEIGHT)
        self:SetFrameLevel(parent:GetFrameLevel() + 5)

        self:_BuildBars()
        self:_BuildBorder()

        -- A long instance and boss name together can be wider than the bar.
        self._crumbs = Frame("Frame", self)
        self._crumbs:FillParent()
        self._crumbs:SetClipsChildren(true)
        self._navButtons = {}
        self._items = {}              -- by crumb: the list its menu was built from

        self.homeBtn = MapNavHomeButton(self._crumbs, "MUI_AdventureGuideNavBarHome")
        self.homeBtn:SetText(HOME)
        self.homeBtn:ClearAllPoints()
        self.homeBtn:AlignParentLeft()
        self.homeBtn.OnClick = function()
            if self.OnHome then self:OnHome() end
        end

        self:SetPath({})
    end;

    -- `top` and `left` are in the parent's units, which the bar's own
    -- scale would stretch.
    SeatAt = function(self, top, left)
        self:ClearAllPoints()
        self:AlignParentTopLeft(top / NAV_SCALE, left / NAV_SCALE)
    end;

    SetPath = function(self, crumbs)
        local prev = self.homeBtn
        for i, crumb in ipairs(crumbs) do
            local button = self._navButtons[i]
            if not button then
                button = MapNavButton(self._crumbs)
                button:SetDropdownWidth(NAV_MENU_WIDTH)
                self._navButtons[i] = button
            end
            button:SetText(crumb.text)
            button.OnClick = crumb.OnClick
            button:SetSelected(i == #crumbs)
            if self._items[i] ~= crumb.items then
                self._items[i] = crumb.items
                button:SetDropdownItems(crumb.items)
            end
            button:ClearAllPoints()
            button:RightOf(prev, (i == 1) and -10 or 0)
            button:Show()
            prev = button
        end
        for i = #crumbs + 1, #self._navButtons do
            self._navButtons[i]:Hide()
        end

        -- Each button stands over the one to its right: its chevron reaches
        -- into that button's body.
        local base = self._crumbs:GetFrameLevel() + 1
        self.homeBtn:SetFrameLevel(base + #crumbs)
        for i = 1, #crumbs do
            self._navButtons[i]:SetFrameLevel(base + #crumbs - i)
        end
    end;
}
