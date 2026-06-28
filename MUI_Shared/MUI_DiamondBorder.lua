-- DiamondBorder: Retail-style diamond metal frame border (used on Dialog/ESC menu)
-- Dialog layout: no corner offsets (flush with frame edges)

class "DiamondBorder" : extends "NineSlice" {
    __init = function(self, parent, name)
        NineSlice.__init(self, parent, name)

        self:SetFromTextureRegion("frame-diamond-metal", 512, 512, 0, 0, 512, 512, 238, 231, 238, 231, 0.12)

        self._textures.Center:SetColorTexture(0, 0, 0, 0.7)
        self._textures.Center:ClearAllPoints()
        self._textures.Center:AlignTop(self._textures.Top, 6)
        self._textures.Center:AlignBottom(self._textures.Bottom, 6)
        self._textures.Center:AlignLeft(self._textures.Left, 6)
        self._textures.Center:AlignRight(self._textures.Right, 6)

    end;
}


class "DiamondHeader" : extends "Frame" {
    __init = function(self, parent, name, text)
        Frame.__init(self, "Frame", parent, name)

        self._nineslice = NineSlice(self, name)
        self._nineslice:SetFromTextureRegion("frame-diamond-metal-header", 512, 256, 0, 0, 512, 256, 128, 128, 128, 128, 0.25)
        self._nineslice:FillParent()

        self._label = FontString(self._nineslice, nil, "OVERLAY")
        self._label:SetFontSize(12)
        self._label:SetTextColor(1, 0.82, 0, 1)
        self._label:CenterInParent(0,-1)
		self._label:SetShadowOffset(1,-1)

        local textWidth = 0

        if text then
            self._label:SetText(text)
            textWidth = self._label:GetStringWidth()
        end

        self:SetSize(math.max(140, textWidth + 64), 64)


    end;

    SetText = function(self, text)
        self._label:SetText(text)
        local textWidth = self._label:GetStringWidth()
        self:SetWidth((textWidth + 512) * scale)
    end;
}
