-- Dropdown: Modern dropdown with three-part button and nine-slice popup

class "Dropdown" : extends "Frame" {
    __init = function(self, parent, name)
        Frame.__init(self, "Button", parent, name)
        self:EnableMouse(true)

        local atlas = MUI_AtlasRegistry.Dropdown
        self._atlas = atlas

        -- Public state read by StepDropdown:
        self.items = {}
        self.selectedIndex = nil

        self._open = false

        -- Three-part button
        self._btnLeft = Texture(self, nil, "BACKGROUND")
        self._btnLeft:SetAtlas(atlas, "BtnL")
        self._btnLeft:AlignParentTopLeft(0, -7)

        self._btnRight = Texture(self, nil, "BACKGROUND")
        self._btnRight:SetAtlas(atlas, "BtnR")
        self._btnRight:AlignParentTopRight(0, -7)

        self._btnMiddle = Texture(self, nil, "BACKGROUND")
        self._btnMiddle:SetAtlas(atlas, "BtnM", true)
        self._btnMiddle:FillBetweenH(self._btnLeft, self._btnRight)

        -- Hover arrow
        self._arrow = Texture(self, nil, "OVERLAY")
        self._arrow:SetAtlas(atlas, "HoverArrow")
        self._arrow:AlignParentBottom(2)
        self._arrow:Hide()

        -- Selected text — public so StepDropdown can dim it on disable.
        self.label = FontString(self, nil, "OVERLAY")
        self.label:SetFontSize(11)
        self.label:SetTextColor(1, 0.82, 0, 1)
        self.label:SetJustifyH("CENTER")
        self.label:CenterInParent()
        self.label:SetText("")

        self:SetSize(150, 39)

        self.OnEnter = function()
            if self._open then
                self:_SetButtonState("Hover")
            else
                self:_SetButtonState("Hover")
                self._arrow:Show()
            end
        end
        self.OnLeave = function()
            if self._open then
                self:_SetButtonState("Open")
            else
                self:_SetButtonState("")
                self._arrow:Hide()
            end
        end

        self:SetScript("OnEnter", function()
            if self.OnEnter then self:OnEnter() end
        end)
        self:SetScript("OnLeave", function()
            if self.OnLeave then self:OnLeave() end
        end)

        -- Popup
        self._popup = Frame("Frame", nil, name and (name .. "Popup") or nil)
        self._popup:SetFrameStrata("DIALOG")
        self._popup:SetFrameLevel(100)
        self._popup:Hide()

        self._popupNS = NineSlice(self._popup)
        self._popupNS:FillParent()
        self._popupNS:SetLayout({
            TopLeft     = { atlas = atlas, region = "BgTopLeft",     width = 24, height = 19, x = -17, y = 12 },
            Top         = { atlas = atlas, region = "BgTop",         height = 19 },
            TopRight    = { atlas = atlas, region = "BgTopRight",    width = 23, height = 19, x = 16, y = 12 },
            Left        = { atlas = atlas, region = "BgLeft",        width = 24 },
            Center      = { atlas = atlas, region = "BgCenter" },
            Right       = { atlas = atlas, region = "BgRight",       width = 23 },
            BottomLeft  = { atlas = atlas, region = "BgBottomLeft",  width = 24, height = 28, x = -17, y = -21 },
            Bottom      = { atlas = atlas, region = "BgBottom",      height = 28 },
            BottomRight = { atlas = atlas, region = "BgBottomRight", width = 23, height = 28, x = 16, y = -21 },
        })

        -- Click-outside backdrop
        self._backdrop = Frame("Frame", nil, name and (name .. "Backdrop") or nil)
        self._backdrop:SetFrameStrata("DIALOG")
        self._backdrop:SetFrameLevel(99)
        self._backdrop:SetAllPoints(UIParent)
        self._backdrop:EnableMouse(true)
        self._backdrop:Hide()
        self._backdrop:SetScript("OnMouseDown", function()
            self:Close()
        end)

        self:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)
            if self._open then
                self:Close()
            else
                self:Open()
            end
        end)

        self._popupItems = {}
    end;

    _SetButtonState = function(self, state)
        local atlas = MUI_AtlasRegistry.Dropdown
        local prefix = "Btn"
        if state and state ~= "" then
            prefix = "Btn" .. state
        end
        self._btnLeft:SetAtlas(atlas, prefix .. "L")
        self._btnRight:SetAtlas(atlas, prefix .. "R")
        self._btnMiddle:SetAtlas(atlas, prefix .. "M", true)
    end;

    SetItems = function(self, items)
        self.items = items

        for _, item in ipairs(self._popupItems) do
            item:Hide()
        end
        self._popupItems = {}

        for i, itemData in ipairs(items) do
            local text = itemData
            if type(itemData) == "table" then
                text = itemData.text
            end

            local btn = Frame("Button", self._popup)
            btn:SetHeight(20)
            btn:FillWidth(10)
            btn:EnableMouse(true)

            if i == 1 then
                btn:AlignParentTopLeft(10, 10)
            else
                btn:Below(self._popupItems[i - 1], 0)
            end

            local hoverL = Texture(btn, nil, "ARTWORK")
            hoverL:SetAtlas(self._atlas, "ItemHoverL")
            hoverL:AlignParentTopLeft()
            hoverL:FillHeight()
            hoverL:SetAlpha(0.2)
            hoverL:Hide()

            local hoverR = Texture(btn, nil, "ARTWORK")
            hoverR:SetAtlas(self._atlas, "ItemHoverR")
            hoverR:AlignParentTopRight()
            hoverR:FillHeight()
            hoverR:SetAlpha(0.2)
            hoverR:Hide()

            local hoverM = Texture(btn, nil, "ARTWORK")
            hoverM:SetAtlas(self._atlas, "ItemHoverM", true)
            hoverM:FillBetweenH(hoverL, hoverR)
            hoverM:SetAlpha(0.2)
            hoverM:Hide()

            btn:SetScript("OnEnter", function()
                hoverL:Show(); hoverM:Show(); hoverR:Show()
            end)
            btn:SetScript("OnLeave", function()
                hoverL:Hide(); hoverM:Hide(); hoverR:Hide()
            end)

            btn.itemLabel = FontString(btn, nil, "OVERLAY")
            btn.itemLabel:SetText(text)
            btn.itemLabel:SetFontSize(11)
            btn.itemLabel:SetTextColor(1, 1, 1, 1)
            btn.itemLabel:SetJustifyH("LEFT")
            btn.itemLabel:AlignParentLeft(6)
            btn.itemLabel:FillHeight()

            local index = i
            btn:SetScript("OnClick", function()
                self:SetSelected(index)
                self:Close()
            end)

            self._popupItems[i] = btn
        end

        local maxTextWidth = 0
        for _, btn in ipairs(self._popupItems) do
            local tw = btn.itemLabel:GetStringWidth()
            if tw > maxTextWidth then maxTextWidth = tw end
        end
        local minW = self.minPopupWidth or self:GetWidth()
        local popupWidth = math.max(minW, maxTextWidth)
        local popupHeight = table.getn(items) * 20 + 20
        self._popup:SetWidth(popupWidth)
        self._popup:SetHeight(popupHeight)
    end;

    Open = function(self)
        self._open = true
        self:_SetButtonState("Open")
        self._arrow:Hide()
        self._savedStrata = self:GetFrameStrata()
        self._savedLevel = self:GetFrameLevel()
        self:SetFrameStrata("DIALOG")
        self:SetFrameLevel(101)

        local left = self:GetLeft() or 0
        local right = self:GetRight() or 0
        local btnW = right - left
        if btnW < 10 then btnW = 150 end
        local maxTextWidth = 0
        for _, btn in ipairs(self._popupItems) do
            local tw = btn.itemLabel:GetStringWidth()
            if tw > maxTextWidth then maxTextWidth = tw end
        end
        local popupWidth = math.max(btnW, maxTextWidth)
        self._popup:SetWidth(popupWidth)

        for i, btn in ipairs(self._popupItems) do
            if i == self.selectedIndex then
                btn.itemLabel:SetTextColor(1, 0.82, 0, 1)
            else
                btn.itemLabel:SetTextColor(1, 1, 1, 1)
            end
        end

        self._popup:ClearAllPoints()
        self._popup:AlignTop(self._arrow, 0.2)
        self._popup:AlignLeft(self, 0)
        self._popup:Show()
        self._backdrop:Show()
    end;

    Close = function(self)
        self._open = false
        self:_SetButtonState("")
        self._arrow:Hide()
        self:SetFrameStrata(self._savedStrata or "MEDIUM")
        self:SetFrameLevel(self._savedLevel or 1)

        self._popup:Hide()
        self._backdrop:Hide()
    end;

    SetSelected = function(self, index)
        self.selectedIndex = index
        local item = self.items[index]
        local text = item
        if type(item) == "table" then
            text = item.text
        end
        self.label:SetText(text or "")

        if self.OnSelectionChanged then
            self:OnSelectionChanged(index, item)
        end
    end;

    GetSelected = function(self)
        if self.selectedIndex then
            return self.selectedIndex, self.items[self.selectedIndex]
        end
        return nil, nil
    end;
}
