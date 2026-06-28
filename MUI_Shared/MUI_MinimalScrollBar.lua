-- MinimalScrollBar: Retail-style minimal vertical scrollbar

class "MinimalScrollBar" : extends "Frame" {
    __init = function(self, parent, name, btnUpPadding, btnDownPadding)
        Frame.__init(self, "Frame", parent, name)
        self:EnableMouse(true)
        self:EnableMouseWheel(true)

        local prop = MUI_AtlasRegistry.ScrollbarMinimalProportional
        local vert = MUI_AtlasRegistry.ScrollbarMinimalVertical
        local thumbProp = MUI_AtlasRegistry.ScrollbarMinimalSmallProportional
        local thumbVert = MUI_AtlasRegistry.ScrollbarMinimalSmallVertical

        self._minVal = 0
        self._maxVal = 0
        self._value = 0
        self._thumbMinHeight = 23
        self._dragging = false
        self._visibleCount = 1
        self._totalCount = 1
        self._scrollSpeed = 20

        self:SetWidth(8)

        -- Arrow buttons
        self.upBtn = Button(self)
        self.upBtn:SetSize(17, 11)
        self.upBtn:SetStateAtlas(prop, "ArrowTop", "ArrowTopDown", "ArrowTop")
        self.upBtn:SetHighlightAtlas(prop, "ArrowTopOver")
        self.upBtn:AlignParentTop(0)

        self.downBtn = Button(self)
        self.downBtn:SetSize(17, 11)
        self.downBtn:SetStateAtlas(prop, "ArrowBottom", "ArrowBottomDown", "ArrowBottom")
        self.downBtn:SetHighlightAtlas(prop, "ArrowBottomOver")
        self.downBtn:AlignParentBottom(0)

        -- Track
        self._trackTop = Texture(self, nil, "BACKGROUND")
        self._trackTop:SetAtlas(prop, "TrackTop")
        self._trackTop:SetSize(8, 8)
        self._trackTop:Below(self.upBtn, btnUpPadding or 4)

        self._trackBottom = Texture(self, nil, "BACKGROUND")
        self._trackBottom:SetAtlas(prop, "TrackBottom")
        self._trackBottom:SetSize(8, 8)
        self._trackBottom:Above(self.downBtn, btnDownPadding or 4)

        self._trackMiddle = Texture(self, nil, "BACKGROUND")
        self._trackMiddle:SetAtlas(vert, "TrackMiddle")
        self._trackMiddle:FillBetweenV(self._trackTop, self._trackBottom)

        -- Thumb
        self._thumb = Frame("Frame", self)
        self._thumb:SetWidth(9)
        self._thumb:EnableMouse(true)

        self._thumbTop = Texture(self._thumb, nil, "ARTWORK")
        self._thumbTop:SetAtlas(thumbProp, "ThumbTop")
        self._thumbTop:SetSize(8, 8)
        self._thumbTop:AlignParentTopLeft()

        self._thumbMiddle = Texture(self._thumb, nil, "BACKGROUND")
        self._thumbMiddle:SetAtlas(thumbVert, "ThumbMiddle", true)
        self._thumbMiddle:SetWidth(8)
        self._thumbMiddle:Below(self._thumbTop, 0)

        self._thumbBottom = Texture(self._thumb, nil, "ARTWORK")
        self._thumbBottom:SetAtlas(thumbProp, "ThumbBottom")
        self._thumbBottom:SetSize(8, 8)
        self._thumbBottom:AlignParentBottomLeft()

        self._thumbVert = thumbVert
        self._thumbProp = thumbProp

        self._thumb:SetScript("OnEnter", function()
            self._thumbTop:SetAtlas(thumbProp, "ThumbTopOver")
            self._thumbMiddle:SetAtlas(thumbVert, "ThumbMiddleOver", true)
            self._thumbBottom:SetAtlas(thumbProp, "ThumbBottomOver")
        end)
        self._thumb:SetScript("OnLeave", function()
            if not self._dragging then
                self._thumbTop:SetAtlas(thumbProp, "ThumbTop")
                self._thumbMiddle:SetAtlas(thumbVert, "ThumbMiddle", true)
                self._thumbBottom:SetAtlas(thumbProp, "ThumbBottom")
            end
        end)

        self._thumb:SetScript("OnMouseDown", function()
            self._dragging = true
            self._dragStartY = self:_GetCursorY()
            self._dragStartValue = self._value
            self._thumbTop:SetAtlas(thumbProp, "ThumbTopDown")
            self._thumbMiddle:SetAtlas(thumbVert, "ThumbMiddleDown", true)
            self._thumbBottom:SetAtlas(thumbProp, "ThumbBottomDown")
        end)
        self._thumb:SetScript("OnMouseUp", function()
            self._dragging = false
            self._thumbTop:SetAtlas(thumbProp, "ThumbTopOver")
            self._thumbMiddle:SetAtlas(thumbVert, "ThumbMiddleOver", true)
            self._thumbBottom:SetAtlas(thumbProp, "ThumbBottomOver")
        end)

        self.upBtn.OnClick = function()
            self:SetValue(self._value - self._scrollSpeed)
        end
        self.downBtn.OnClick = function()
            self:SetValue(self._value + self._scrollSpeed)
        end

        self:SetScript("OnMouseWheel", function(frame, delta)
            if delta > 0 then
                self:SetValue(self._value - self._scrollSpeed)
            else
                self:SetValue(self._value + self._scrollSpeed)
            end
        end)
    end;

    _GetCursorY = function(self)
        local _, y = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        return y / scale
    end;

    _GetTrackHeight = function(self)
        local top = self._trackTop:GetTop() or 0
        local bot = self._trackBottom:GetBottom() or 0
        return top - bot
    end;

    _UpdateThumbPosition = function(self)
        local range = self._maxVal - self._minVal

        -- No scroll range = no thumb. Check this FIRST, before the
        -- trackHeight defer — otherwise on early calls (parent chain
        -- not yet laid out, trackHeight=0) we defer via OnUpdate and
        -- leave the thumb visible from its default state.
        if range <= 0 then
            self._thumb:Hide()
            return
        end

        local trackHeight = self:_GetTrackHeight()

        if trackHeight <= 0 then
            self:SetScript("OnUpdate", function()
                self:SetScript("OnUpdate", nil)
                self:_UpdateThumbPosition()
            end)
            return
        end

        self:SetScript("OnUpdate", function()
            if self._dragging then
                local curY = self:_GetCursorY()
                local delta = self._dragStartY - curY
                local tHeight = self:_GetTrackHeight()
                local thumbH = self._thumb:GetHeight()
                local scrollable = tHeight - thumbH
                local r = self._maxVal - self._minVal

                if scrollable > 0 and r > 0 then
                    local valueDelta = (delta / scrollable) * r
                    local newVal = math.max(self._minVal, math.min(self._maxVal, self._dragStartValue + valueDelta))
                    self:SetValue(newVal)
                end
            end
        end)

        self._thumb:Show()

        local visibleRatio = math.min(self._visibleCount / self._totalCount, 0.8)
        local thumbHeight = math.max(self._thumbMinHeight, trackHeight * visibleRatio)
        self._thumb:SetHeight(thumbHeight)

        local middleHeight = thumbHeight - 16
        if middleHeight > 0 then
            self._thumbMiddle:SetHeight(middleHeight)
            self._thumbMiddle:Show()
        else
            self._thumbMiddle:Hide()
        end

        local scrollable = trackHeight - thumbHeight
        local pct = (self._value - self._minVal) / range
        local offset = pct * scrollable

        self._thumb:ClearAllPoints()
        self._thumb:AnchorToTopOf(self._trackTop, offset)
    end;

    SetMinMax = function(self, min, max)
        self._minVal = min
        self._maxVal = max
        if self._value > max then self._value = max end
        if self._value < min then self._value = min end
        self:_UpdateThumbPosition()
    end;

    GetMin = function(self)
        return self._minVal
    end;

    GetMax = function(self)
        return self._maxVal
    end;

    SetValue = function(self, value)
        value = math.max(self._minVal, math.min(self._maxVal, value))
        if value ~= self._value then
            self._value = value
            self:_UpdateThumbPosition()
            if self.OnScroll then
                self:OnScroll(self._value)
            end
        end
    end;

    GetValue = function(self)
        return self._value
    end;

    SetContentSize = function(self, visibleCount, totalCount)
        self._visibleCount = visibleCount
        self._totalCount = totalCount
        self:_UpdateThumbPosition()
    end;

    SetScrollSpeed = function(self, speed)
        self._scrollSpeed = speed
    end;
}
