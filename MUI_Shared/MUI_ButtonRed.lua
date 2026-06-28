-- ButtonRed: Three-slice red button

local RED_BTN_SCALE = 36 / 128
local RED_BTN_LEFT_W = math.floor(114 * RED_BTN_SCALE + 0.5)
local RED_BTN_RIGHT_W = math.floor(292 * RED_BTN_SCALE + 0.5)

class "ButtonRed" : extends "Button" {
    __init = function(self, parent, name, text)
        Button.__init(self, parent, name, text)

        local atlas = MUI_AtlasRegistry.ButtonRed
        self._redAtlas = atlas

        self._texLeft = Texture(self, nil, "ARTWORK")
        self._texLeft:SetAtlas(atlas, "LeftNormal", true)
        self._texLeft:SetSize(RED_BTN_LEFT_W, 36)
        self._texLeft:AlignParentTopLeft()

        self._texRight = Texture(self, nil, "ARTWORK")
        self._texRight:SetAtlas(atlas, "RightNormal", true)
        self._texRight:SetSize(RED_BTN_RIGHT_W, 36)
        self._texRight:AlignParentTopRight()

        self._texCenter = Texture(self, nil, "BACKGROUND")
        self._texCenter:SetAtlas(atlas, "CenterNormal", true)
        self._texCenter:FillBetweenH(self._texLeft, self._texRight, 3)

        self:SetHighlightAtlas(atlas, "Highlight", true)
        self.label:SetFontSize(15)
        self:SetSize(200, 36)

        self:SetScript("OnMouseDown", function()
            if self._enabled then
                self:_SetRedState("Pressed")
                self.label:ClearAllPoints()
                self.label:CenterInParent(-2, 1)
            end
        end)
        self:SetScript("OnMouseUp", function()
            if self._enabled then
                self:_SetRedState("Normal")
                self.label:ClearAllPoints()
                self.label:CenterInParent()
            end
        end)
    end;

    _SetRedState = function(self, state)
        local atlas = self._redAtlas
        self._texLeft:SetAtlas(atlas, "Left" .. state, true)
        self._texLeft:SetSize(RED_BTN_LEFT_W, 36)
        self._texRight:SetAtlas(atlas, "Right" .. state, true)
        self._texRight:SetSize(RED_BTN_RIGHT_W, 36)
        self._texCenter:SetAtlas(atlas, "Center" .. state, true)
    end;

    SetEnabled = function(self, enabled)
        self._enabled = enabled
        if enabled then
            self:_SetRedState("Normal")
            self:Enable()
            self.label:SetAlpha(1)
        else
            self:_SetRedState("Disabled")
            self:Disable()
            self.label:SetAlpha(0.5)
        end
    end;
}
