class "ButtonGold" : extends "Button" {
    __init = function(self, parent, name, text)
        Button.__init(self, parent, name, text)

        self._ns = NineSlice(self)
        self._ns:SetFromTextureRegion("button-gold", 128, 128, 1, 1, 78, 21, 5, 5, 5, 5, 1)
        self._ns:FillParent()
        self._ns:SetDrawLayer("ARTWORK")

        self._highlight = Texture(self._ns, nil, "OVERLAY")
        self._highlight:FillParent()
        self._highlight:SetTextureRegion(MUI.TEX_BASE .. "button-gold", 128, 128, 1, 75, 78, 17)
        self._highlight:SetBlendMode("ADD")
        self._highlight:SetAlpha(0.6)
        self._highlight:Hide()

        -- Center the label and bound it with an EXPLICIT width (kept in sync
        -- with the button via OnSizeChanged below), instead of a 4-point fill.
        -- A FontString whose width is DERIVED from a fill anchor lays its text
        -- into a zero rect when the button is sized on a later frame — on a
        -- cold start these buttons are built hidden and resized by the caller
        -- afterwards — and never re-flows, so the text renders blank until
        -- something re-anchors it (a click does). An explicit width resolves
        -- immediately AND keeps the text clipped to the button border.
        self.label:SetParent(self._ns)
        self.label:ClearAllPoints()
        self.label:CenterInParent()
        self.label:SetFontSize(12)
		self.label:SetTextColor(1, 0.82, 0, 1)
		self.label:SetShadowOffset(1, -1)

        -- Pin the label width to the button (minus 10px side padding) on every
        -- size change. The caller sizes the button after construction, so this
        -- is where the real width arrives.
        self:SetScript("OnSizeChanged", function(_, w)
            if self.label then
                self.label:SetWidth(w - 20)
            end
        end)

        self:SetSize(94, 22)

        self.OnEnter = function()
            if self._enabled then
                self.label:SetTextColor(1,1,1,1)
                self._highlight:Show()
            end
        end

        self.OnLeave = function()
            if self._enabled then
                self.label:SetTextColor(1,0.82,0,1)
                self._highlight:Hide()
            end
        end
        
        self:SetScript("OnMouseDown", function()
            if self._enabled then
                self._ns:SetFromTextureRegion("button-gold", 128, 128, 1, 25, 78, 21, 5, 5, 5, 5, 1)
                self.label:ClearAllPoints()
                self.label:CenterInParent(1, -1)
            end
        end)
        self:SetScript("OnMouseUp", function()
            if self._enabled then
                self._ns:SetFromTextureRegion("button-gold", 128, 128, 1, 1, 78, 21, 5, 5, 5, 5, 1)
                self.label:ClearAllPoints()
                self.label:CenterInParent()
            end
        end)
    end;

    SetEnabled = function(self, enabled)
        self._enabled = enabled
        if enabled then
            self._ns:SetFromTextureRegion("button-gold", 128, 128, 1, 1, 78, 21, 5, 5, 5, 5, 1)
            if self:IsMouseOver() then
                self._highlight:Show()
                self.label:SetTextColor(1, 1, 1, 1)
            else
                self._highlight:Hide()
                self.label:SetTextColor(1, 0.82, 0, 1)
            end
        else
            self._ns:SetFromTextureRegion("button-gold", 128, 128, 1, 50, 78, 21, 5, 5, 5, 5, 1)
            self._highlight:Hide()
            self.label:SetTextColor(0.5, 0.5, 0.5, 1)
        end
    end;
    
}
