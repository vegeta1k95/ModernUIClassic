
class "ItemIcon" : extends "Texture" {

    __init = function(self, parentOrNative, name, layer)
        Texture.__init(self, parentOrNative, name, layer)

        self._qualityBorder = Texture(parentOrNative, nil, "OVERLAY")
        self._qualityBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
        self._qualityBorder:Fill(self, 0, 0, 0, 0)
        self._qualityBorder:Hide()
    end;

    SetQuality = function(self, quality)
        if not quality or quality < 1 then
            self._qualityBorder:Hide()
            return
        end
        local c = BAG_ITEM_QUALITY_COLORS and BAG_ITEM_QUALITY_COLORS[quality]
        if c then
            self._qualityBorder:SetVertexColor(c.r, c.g, c.b)
        else
            self._qualityBorder:Hide()
        end
        self._qualityBorder:Show()
    end;
}