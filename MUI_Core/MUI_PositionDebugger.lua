-- PositionDebugger
-- Live in-game tuning of a widget's width, height, and per-anchor offsets.
-- Call `widget:AttachPositionDebugger()` and a floating panel appears with
-- sliders driving the widget directly. Read the final numbers off the panel
-- and paste back into source. Singleton at MUI_PositionDebugger.
--
-- Notes:
--  - Supports up to 4 anchors; unused anchor sections hide.
--  - Mouse-wheel over a slider steps by 1 — use that for fine adjustments.
--  - SetPoint on protected frames is blocked in combat; pcall swallows that
--    quietly so the rest of the panel keeps responding.

local MAX_ANCHORS    = 4
local SIZE_MAX       = 1500
local OFFSET_MIN     = -800
local OFFSET_MAX     = 800
local PADDING_X      = 12
local ROW_GAP        = 8
local SECTION_GAP    = 14
local SLIDER_HEIGHT  = 19

local function FormatRel(relTo)
    if type(relTo) == "table" and relTo.GetName then
        return relTo:GetName() or "<anon>"
    elseif type(relTo) == "string" then
        return relTo
    end
    return "UIParent"  -- nil relativeTo means UIParent in WoW
end

-- Snap to 0.5 step (matches slider step) and format compactly: "100" for whole
-- numbers, "100.5" for halves. Avoids the noisy ".0" suffix that "%.1f" gives.
local function FmtVal(v)
    v = math.floor(v * 2 + 0.5) / 2
    if v == math.floor(v) then return tostring(math.floor(v)) end
    return string.format("%.1f", v)
end

local function ResolveName(widget)
    -- Some MUI classes repurpose `_name` to hold a child FontString (e.g.,
    -- ProfessionSlot's `self._name = FontString(self)`), so don't trust it to
    -- be a string — only accept it if it actually is one.
    local name = widget._name
    if type(name) == "string" then return name end
    if widget._native and widget._native.GetName then
        local nativeName = widget._native:GetName()
        if type(nativeName) == "string" then return nativeName end
    end
    return "<unnamed>"
end

object "PositionDebugger" : extends "Frame" {

    __init = function(self)
        Frame.__init(self, "Frame", nil, "MUI_PositionDebugger")
        self:SetSize(290, 540)
        self:SetFrameStrata("DIALOG")
        self:SetFrameLevel(200)
        self:CenterInParent()
        self:MakeDraggable()
        self:SetClampedToScreen(true)

        -- 1px border via two stacked color textures (outer light, inner dark).
        local border = Texture(self, nil, "BACKGROUND")
        border:SetColorTexture(0.45, 0.45, 0.45, 1)
        border:FillParent()
        local bg = Texture(self, nil, "BACKGROUND")
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
        bg:Fill(self, 1, 1, 1, 1)
        bg:SetDrawLayer("BACKGROUND", 1)

        -- Title bar
        local title = FontString(self)
        title:AlignParentTop(4)
        title:SetText("Position Debugger")
        title:SetFontSize(13)
        title:SetTextColor(1, 0.82, 0)
        title:SetShadowOffset(1, -1)

        self._targetLabel = FontString(self)
        self._targetLabel:Below(title, 4)
        self._targetLabel:SetFontSize(10)
        self._targetLabel:SetTextColor(0.7, 0.7, 0.7)
        self._targetLabel:SetText("Target: (none)")

        -- Width & Height rows
        local prev = self._targetLabel
        self._widthSlider,  self._widthLabel,  prev = self:_BuildSizeRow(prev, "Width",  SECTION_GAP)
        self._heightSlider, self._heightLabel, prev = self:_BuildSizeRow(prev, "Height", ROW_GAP)

        self._widthSlider.OnValueChanged = function(_, v)
            v = math.floor(v * 2 + 0.5) / 2
            self._widthLabel:SetText(FmtVal(v))
            self:_ApplySize(v, nil)
        end
        self._heightSlider.OnValueChanged = function(_, v)
            v = math.floor(v * 2 + 0.5) / 2
            self._heightLabel:SetText(FmtVal(v))
            self:_ApplySize(nil, v)
        end

        -- Anchor rows (one block per anchor up to MAX_ANCHORS)
        self._anchorRows = {}
        for i = 1, MAX_ANCHORS do
            local row = self:_BuildAnchorRow(prev, i)
            self._anchorRows[i] = row
            prev = row.ySlider
        end

        -- Detach button at the bottom
        self._detachBtn = Button(self, nil, "Detach")
        self._detachBtn:AlignParentTopRight(0, 0)
        self._detachBtn:SetSize(60, 22)
        self._detachBtn.OnClick = function() self:Detach() end

        self:Hide()
    end;

    -- One row for size: [label]  [value]  /  [slider]
    _BuildSizeRow = function(self, prev, labelText, topGap)
        local label = FontString(self)
        label:Below(prev, topGap)
        label:AlignParentLeft(PADDING_X)
        label:SetText(labelText)
        label:SetFontSize(10)
        label:SetTextColor(0.85, 0.85, 0.85)

        local valueLabel = FontString(self)
        valueLabel:AlignTop(label)
        valueLabel:AlignParentRight(PADDING_X)
        valueLabel:SetJustifyH("RIGHT")
        valueLabel:SetFontSize(10)
        valueLabel:SetTextColor(0.85, 0.85, 0.85)
        valueLabel:SetText("0")

        local slider = Slider(self)
        slider:Below(label, 2)
        slider:AlignParentLeft(PADDING_X)
        slider:AlignParentRight(PADDING_X)
        slider:SetHeight(SLIDER_HEIGHT)
        slider:SetMinMaxValues(0, SIZE_MAX)
        slider:SetValueStep(0.5)
        slider:SetValue(0)
        return slider, valueLabel, slider
    end;

    -- One block per anchor: header line + X row + Y row.
    _BuildAnchorRow = function(self, prev, index)
        local header = FontString(self)
        header:Below(prev, SECTION_GAP)
        header:AlignParentLeft(PADDING_X)
        header:AlignParentRight(PADDING_X)
        header:SetJustifyH("LEFT")
        header:SetFontSize(10)
        header:SetTextColor(1, 0.82, 0)
        header:SetText(string.format("Anchor %d", index))

        local xLabel = FontString(self)
        xLabel:Below(header, 4)
        xLabel:AlignParentLeft(PADDING_X)
        xLabel:SetText("X")
        xLabel:SetFontSize(10)
        xLabel:SetTextColor(0.85, 0.85, 0.85)

        local xValue = FontString(self)
        xValue:AlignTop(xLabel)
        xValue:AlignParentRight(PADDING_X)
        xValue:SetJustifyH("RIGHT")
        xValue:SetFontSize(10)
        xValue:SetTextColor(0.85, 0.85, 0.85)
        xValue:SetText("0")

        local xSlider = Slider(self)
        xSlider:Below(xLabel, 2)
        xSlider:AlignParentLeft(PADDING_X)
        xSlider:AlignParentRight(PADDING_X)
        xSlider:SetHeight(SLIDER_HEIGHT)
        xSlider:SetMinMaxValues(OFFSET_MIN, OFFSET_MAX)
        xSlider:SetValueStep(0.5)
        xSlider:SetValue(0)

        local yLabel = FontString(self)
        yLabel:Below(xSlider, ROW_GAP)
        yLabel:AlignParentLeft(PADDING_X)
        yLabel:SetText("Y")
        yLabel:SetFontSize(10)
        yLabel:SetTextColor(0.85, 0.85, 0.85)

        local yValue = FontString(self)
        yValue:AlignTop(yLabel)
        yValue:AlignParentRight(PADDING_X)
        yValue:SetJustifyH("RIGHT")
        yValue:SetFontSize(10)
        yValue:SetTextColor(0.85, 0.85, 0.85)
        yValue:SetText("0")

        local ySlider = Slider(self)
        ySlider:Below(yLabel, 2)
        ySlider:AlignParentLeft(PADDING_X)
        ySlider:AlignParentRight(PADDING_X)
        ySlider:SetHeight(SLIDER_HEIGHT)
        ySlider:SetMinMaxValues(OFFSET_MIN, OFFSET_MAX)
        ySlider:SetValueStep(0.5)
        ySlider:SetValue(0)

        xSlider.OnValueChanged = function(_, v)
            v = math.floor(v * 2 + 0.5) / 2
            xValue:SetText(FmtVal(v))
            self:_ApplyAnchor(index, v, nil)
        end
        ySlider.OnValueChanged = function(_, v)
            v = math.floor(v * 2 + 0.5) / 2
            yValue:SetText(FmtVal(v))
            self:_ApplyAnchor(index, nil, v)
        end

        return {
            header  = header,
            xLabel  = xLabel,  xValue = xValue, xSlider = xSlider,
            yLabel  = yLabel,  yValue = yValue, ySlider = ySlider,
        }
    end;

    Attach = function(self, widget)
        if not widget or not widget._native then return end
        self._target = widget
        self:_Rebuild()
        self:Show()
    end;

    Detach = function(self)
        self._target = nil
        self:Hide()
    end;

    _Rebuild = function(self)
        local t = self._target
        if not t then return end

        -- Suppress applies while we sync slider positions to current values.
        self._suppress = true

        self._targetLabel:SetText("Target: " .. ResolveName(t))

        local w, h = t._native:GetWidth() or 0, t._native:GetHeight() or 0
        self._widthSlider:SetMinMaxValues(0, math.max(SIZE_MAX, w + 200))
        self._heightSlider:SetMinMaxValues(0, math.max(SIZE_MAX, h + 200))
        self._widthSlider:SetValue(w)
        self._heightSlider:SetValue(h)
        self._widthLabel:SetText(FmtVal(w))
        self._heightLabel:SetText(FmtVal(h))

        local numPoints = t:GetNumPoints() or 0
        for i = 1, MAX_ANCHORS do
            local row = self._anchorRows[i]
            if i <= numPoints then
                local point, relTo, relPoint, ox, oy = t:GetPoint(i)
                ox = ox or 0
                oy = oy or 0
                row.header:SetText(string.format(
                    "Anchor %d  %s @ %s.%s",
                    i, point or "?", FormatRel(relTo), relPoint or "?"))
                row.xSlider:SetMinMaxValues(
                    math.min(OFFSET_MIN, ox - 300),
                    math.max(OFFSET_MAX, ox + 300))
                row.ySlider:SetMinMaxValues(
                    math.min(OFFSET_MIN, oy - 300),
                    math.max(OFFSET_MAX, oy + 300))
                row.xSlider:SetValue(ox)
                row.ySlider:SetValue(oy)
                row.xValue:SetText(FmtVal(ox))
                row.yValue:SetText(FmtVal(oy))
                row.header:Show()
                row.xLabel:Show();  row.xValue:Show();  row.xSlider:Show()
                row.yLabel:Show();  row.yValue:Show();  row.ySlider:Show()
            else
                row.header:Hide()
                row.xLabel:Hide(); row.xValue:Hide(); row.xSlider:Hide()
                row.yLabel:Hide(); row.yValue:Hide(); row.ySlider:Hide()
            end
        end

        self._suppress = false
    end;

    _ApplySize = function(self, w, h)
        if self._suppress or not self._target then return end
        pcall(function()
            if w and h then
                self._target:SetSize(w, h)
            elseif w then
                self._target:SetSize(w, self._target._native:GetHeight())
            elseif h then
                self._target:SetSize(self._target._native:GetWidth(), h)
            end
        end)
    end;

    -- Re-apply ALL anchors with one modified offset. SetPoint replaces only one
    -- anchor at a time, so snapshot the rest before ClearAllPoints to keep the
    -- other anchors intact.
    _ApplyAnchor = function(self, index, newX, newY)
        if self._suppress or not self._target then return end
        local t = self._target
        local n = t:GetNumPoints()
        if n == 0 or index > n then return end

        local snap = {}
        for i = 1, n do
            local p, r, rp, ox, oy = t:GetPoint(i)
            snap[i] = { p, r, rp, ox or 0, oy or 0 }
        end
        if newX then snap[index][4] = newX end
        if newY then snap[index][5] = newY end

        pcall(function()
            t:ClearAllPoints()
            for i = 1, n do
                local a = snap[i]
                t._native:SetPoint(a[1], a[2], a[3], a[4], a[5])
            end
        end)
    end;
}
