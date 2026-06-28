-- ScrollList: Smooth pixel-scrolling faux list with MinimalScrollBar

class "ScrollList" : extends "Frame" {
    __init = function(self, parent, name, rowHeight, visibleRows)
        Frame.__init(self, "Frame", parent, name)
        self:EnableMouseWheel(true)

        self._rowHeight = rowHeight or 20
        self._visibleRows = visibleRows or 10
        self._renderRows = self._visibleRows + 1
        self._data = {}
        self._scrollOffset = 0
        self._rows = {}
        self._fadePadding = math.floor(self._rowHeight / 2)

        self._content = Frame("Frame", self)
        self._content:AlignParentTopLeft()
        self._content:SetWidth(1)

        self._scrollBar = MinimalScrollBar(self)
        self._scrollBar:SetWidth(8)
        self._scrollBar:AlignParentTopRight(0, 6)
        self._scrollBar:AlignParentBottomRight(0, 6)
        self._scrollBar.OnScroll = function(_, value)
            self._scrollOffset = value
            self:Refresh()
        end

        self:SetScript("OnMouseWheel", function(frame, delta)
            local val = self._scrollBar:GetValue()
            local step = self._rowHeight
            if delta > 0 then
                self._scrollBar:SetValue(val - step)
            else
                self._scrollBar:SetValue(val + step)
            end
        end)
    end;

    _GetItemHeight = function(self, dataIndex)
        if self.rowHeightFn and self._data[dataIndex] then
            return self.rowHeightFn(self._data[dataIndex])
        end
        return self._rowHeight
    end;

    BuildRows = function(self)
        for i = 1, self._renderRows do
            local row
            if self.CreateRow then
                row = self:CreateRow(i, self._content)
            else
                row = Frame("Frame", self._content)
            end
            row:SetHeight(self._rowHeight)
            row:FillWidth()
            if i == 1 then
                row:AlignParentTopLeft()
            else
                row:Below(self._rows[i - 1], 0)
            end

            self._rows[i] = row
        end
    end;

    SetData = function(self, data)
        self._data = data
        self._scrollOffset = 0

        local dataCount = table.getn(data)
        local totalPixelHeight
        if self.rowHeightFn then
            totalPixelHeight = 0
            for i = 1, dataCount do
                totalPixelHeight = totalPixelHeight + self:_GetItemHeight(i)
            end
        else
            totalPixelHeight = dataCount * self._rowHeight
        end
        local frameHeight = self:GetHeight()
        local contentHeight = frameHeight - 2 * self._fadePadding
        local maxScroll = math.max(totalPixelHeight - contentHeight, 0)

        self._scrollBar:SetMinMax(0, maxScroll)
        self._scrollBar:SetValue(0)
        self._scrollBar:SetContentSize(self._visibleRows, dataCount)
        self._scrollBar:SetScrollSpeed(self._rowHeight)

        if maxScroll == 0 then
            self._scrollBar:Hide()
            self._content:ClearAllPoints()
            self._content:FillParent()
        else
            self._scrollBar:Show()
            self._content:ClearAllPoints()
            self._content:AlignParentTopLeft()
            self._content:LeftOf(self._scrollBar, 4)
        end

        self:Refresh()
    end;

    Refresh = function(self)
        local dataCount = table.getn(self._data)
        local fadePad = self._fadePadding
        local frameHeight = self:GetHeight()

        local firstVisible, pixelShift
        if self.rowHeightFn then
            local cumHeight = 0
            firstVisible = 0
            for i = 1, dataCount do
                local h = self:_GetItemHeight(i)
                if cumHeight + h > self._scrollOffset then break end
                cumHeight = cumHeight + h
                firstVisible = i
            end
            pixelShift = self._scrollOffset - cumHeight
        else
            firstVisible = math.floor(self._scrollOffset / self._rowHeight)
            pixelShift = self._scrollOffset - (firstVisible * self._rowHeight)
        end

        self._content:ClearAllPoints()
        self._content:AlignParentTopLeft(fadePad - pixelShift, 0)
        self._content:FillWidth()

        local rowTop = -pixelShift + fadePad
        for i = 1, self._renderRows do
            local row = self._rows[i]
            if not row then break end
            local dataIndex = firstVisible + i
            if dataIndex >= 1 and dataIndex <= dataCount then
                local itemHeight = self:_GetItemHeight(dataIndex)
                row:SetHeight(itemHeight)
                row:Show()
                if self.UpdateRow then
                    self:UpdateRow(row, dataIndex, self._data[dataIndex])
                end

                local rowBottom = rowTop + itemHeight
                local alpha = 1.0

                if rowTop < 0 then
                    alpha = 0
                elseif rowTop < fadePad then
                    alpha = rowTop / fadePad
                end

                if rowBottom > frameHeight then
                    alpha = 0
                elseif rowBottom > frameHeight - fadePad then
                    alpha = math.min(alpha, (frameHeight - rowBottom) / fadePad)
                end

                row:SetAlpha(alpha)
                if alpha <= 0 then row:Hide() end

                rowTop = rowTop + itemHeight
            else
                row:Hide()
            end
        end
    end;

    SetFadePadding = function(self, pixels)
        self._fadePadding = pixels
    end;
}
