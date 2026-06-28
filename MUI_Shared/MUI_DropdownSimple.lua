
class "DropdownSimple" : extends {"Button", "NineSlice"} {

    __init = function(self, parent, name)
        Button.__init(self, parent, name)
        NineSlice.__init(self, parent, name)
        self:SetFromTextureRegion("dropdown", 512, 512, 333, 11, 84, 57, 15, 15, 15, 15, 0.45)
        self:EnableMouse(true)

        self._label = FontString(self)
        self._label:FillParentPadding(10, 0, 30, 0)
        self._label:SetJustifyH("LEFT")
        self._label:SetFont(MUI.FONT, 10.5, "")
        self._label:SetText("")

        self._btn = Texture(self, nil, "OVERLAY")
        self._btn:SetTextureRegion(MUI.TEX_BASE .. "dropdown", 512, 512, 241, 339, 54, 53)
        self._btn:SetSize(25, 25)
        self._btn:AlignParentRight(1)

        self:SetScript("OnEnter", function() 
            self._btn:SetTextureRegion(MUI.TEX_BASE .. "dropdown", 512, 512, 241, 451, 54, 53)
        end)
        self:SetScript("OnLeave", function()
            self._btn:SetTextureRegion(MUI.TEX_BASE .. "dropdown", 512, 512, 241, 339, 54, 53)
        end)
        self:SetScript("OnMouseDown", function ()
            self._btn:SetTextureRegion(MUI.TEX_BASE .. "dropdown", 512, 512, 297, 451, 54, 53)
        end)
        self:SetScript("OnMouseUp", function ()
            if self:IsMouseOver() then
                self._btn:SetTextureRegion(MUI.TEX_BASE .. "dropdown", 512, 512, 241, 451, 54, 53)
            else
                self._btn:SetTextureRegion(MUI.TEX_BASE .. "dropdown", 512, 512, 241, 339, 54, 53)
            end
        end)

        self:SetScript("OnClick", function()
            if self.OnClick then
                self.OnClick()
            end
        end)
    end;

    SetText = function(self, text)
        self._label:SetText(text)
    end;

}