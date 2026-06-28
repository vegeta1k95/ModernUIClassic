-- ButtonSilver: 9-slice stretched silver button (retail UIMenuButtonStretchTemplate)
-- Supports normal, pressed, highlight, and selected states.
-- Create: ButtonSilver(parent, name, text)

local TEX_PATH      = "Interface\\AddOns\\ModernUI\\assets\\textures\\"
local TEX_UP        = TEX_PATH .. "ui-silver-button-up"
local TEX_DOWN      = TEX_PATH .. "ui-silver-button-down"
local TEX_HIGHLIGHT = TEX_PATH .. "ui-silver-button-highlight"
local TEX_SELECT    = TEX_PATH .. "ui-silver-button-select"

local CORNER_W = 12
local CORNER_H = 6

local SLICES = {
    TopLeft      = { 0,       0.09375, 0,      0.1875 },
    TopRight     = { 0.53125, 0.625,   0,      0.1875 },
    BottomLeft   = { 0,       0.09375, 0.625,  0.8125 },
    BottomRight  = { 0.53125, 0.625,   0.625,  0.8125 },
    TopMiddle    = { 0.09375, 0.53125, 0,      0.1875 },
    BottomMiddle = { 0.09375, 0.53125, 0.625,  0.8125 },
    MiddleLeft   = { 0,       0.09375, 0.1875, 0.625  },
    MiddleRight  = { 0.53125, 0.625,   0.1875, 0.625  },
    Center       = { 0.09375, 0.53125, 0.1875, 0.625  },
}

class "ButtonSilver" : extends "Button" {
    __init = function(self, parent, name, text)
        Button.__init(self, parent, name, text)

        -- 9-slice background
        self._slices = {}
        for piece, tc in pairs(SLICES) do
            local tex = Texture(self, nil, "BACKGROUND")
            tex:SetTexture(TEX_UP)
            tex:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
            self._slices[piece] = tex
        end

        local s = self._slices

        -- Corners (fixed size, anchored to parent corners)
        s.TopLeft:SetSize(CORNER_W, CORNER_H)
        s.TopLeft:AlignParentTopLeft()

        s.TopRight:SetSize(CORNER_W, CORNER_H)
        s.TopRight:AlignParentTopRight()

        s.BottomLeft:SetSize(CORNER_W, CORNER_H)
        s.BottomLeft:AlignParentBottomLeft()

        s.BottomRight:SetSize(CORNER_W, CORNER_H)
        s.BottomRight:AlignParentBottomRight()

        -- Horizontal edges (stretch between corners)
        s.TopMiddle:SetPoint("TOPLEFT", s.TopLeft, "TOPRIGHT", 0, 0)
        s.TopMiddle:SetPoint("BOTTOMRIGHT", s.TopRight, "BOTTOMLEFT", 0, 0)

        s.BottomMiddle:SetPoint("TOPLEFT", s.BottomLeft, "TOPRIGHT", 0, 0)
        s.BottomMiddle:SetPoint("BOTTOMRIGHT", s.BottomRight, "BOTTOMLEFT", 0, 0)

        -- Vertical edges (stretch between corners)
        s.MiddleLeft:SetPoint("TOPRIGHT", s.TopLeft, "BOTTOMRIGHT", 0, 0)
        s.MiddleLeft:SetPoint("BOTTOMLEFT", s.BottomLeft, "TOPLEFT", 0, 0)

        s.MiddleRight:SetPoint("TOPRIGHT", s.TopRight, "BOTTOMRIGHT", 0, 0)
        s.MiddleRight:SetPoint("BOTTOMLEFT", s.BottomRight, "TOPLEFT", 0, 0)

        -- Center (fills remaining space)
        s.Center:SetPoint("TOPLEFT", s.TopLeft, "BOTTOMRIGHT", 0, 0)
        s.Center:SetPoint("BOTTOMRIGHT", s.BottomRight, "TOPLEFT", 0, 0)

        -- Highlight (additive blend, auto show/hide by engine on hover)
        self:SetHighlightTexture(TEX_HIGHLIGHT)
        local hl = self:GetHighlightTexture()
        hl:SetTexCoord(0, 1.0, 0.03, 0.7175)
        hl:SetBlendMode("ADD")

        -- Selected overlay (for "listening" mode)
        self._selectHighlight = Texture(self, nil, "OVERLAY")
        self._selectHighlight:SetTexture(TEX_SELECT)
        self._selectHighlight:SetBlendMode("ADD")
        self._selectHighlight:SetHeight(20)
        self._selectHighlight:SetPoint("LEFT", self, "LEFT", 0, -3)
        self._selectHighlight:SetPoint("RIGHT", self, "RIGHT", 0, -3)
        self._selectHighlight:Hide()

        -- Label: centered with retail offset, small font
        self.label:ClearAllPoints()
        self.label:CenterInParent(0, -1)
        self.label:SetFontSize(10)

        -- Pressed/released texture swap
        self:SetScript("OnMouseDown", function()
            if self._enabled then
                self:_SetSliceTexture(TEX_DOWN)
            end
        end)
        self:SetScript("OnMouseUp", function()
            if self._enabled then
                self:_SetSliceTexture(TEX_UP)
            end
        end)
        self:SetScript("OnShow", function()
            self:_SetSliceTexture(TEX_UP)
        end)

        self:SetSize(160, 22)
    end;

    _SetSliceTexture = function(self, file)
        for _, tex in pairs(self._slices) do
            tex:SetTexture(file)
        end
    end;

    SetBindingText = function(self, key)
        if key then
            self.label:SetText(key)
            self.label:SetTextColor(1, 1, 1, 1)
        else
            self.label:SetText("Not Bound")
            self.label:SetTextColor(0.6, 0.6, 0.6, 0.5)
        end
    end;

    SetSelected = function(self, selected)
        self._selected = selected
        if selected then
            self._selectHighlight:Show()
            local hl = self:GetHighlightTexture()
            if hl then hl:SetAlpha(0) end
        else
            self._selectHighlight:Hide()
            local hl = self:GetHighlightTexture()
            if hl then hl:SetAlpha(1) end
        end
    end;

    SetEnabled = function(self, enabled)
        self._enabled = enabled
        self:_SetSliceTexture(TEX_UP)
        if enabled then
            self:Enable()
            self.label:SetAlpha(1)
        else
            self:Disable()
            self.label:SetAlpha(0.5)
        end
    end;
}
