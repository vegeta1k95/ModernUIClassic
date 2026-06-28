-- Slider: native Slider wrapper with three-part track and thumb texture.
--
-- Owns all the Slider-specific native methods (value/minMax/orientation/
-- thumb-texture). They live here, not on Frame — generic frames don't
-- have these.

class "Slider" : extends "Frame" {
    __init = function(self, parent, name)
        Frame.__init(self, "Slider", parent, name)
        self:SetOrientation("HORIZONTAL")
        self:EnableMouse(true)
        self:SetMinMaxValues(0, 100)
        self:SetValue(50)
        self:SetValueStep(1)

        local atlas = MUI_AtlasRegistry.SliderBarMinimal

        -- Track (three-part)
        self._trackLeft = Texture(self, nil, "BACKGROUND")
        self._trackRight = Texture(self, nil, "BACKGROUND")
        self._trackMiddle = Texture(self, nil, "BACKGROUND")

        self._trackLeft:SetAtlas(atlas, "Left")
        self._trackRight:SetAtlas(atlas, "Right")
        self._trackMiddle:SetAtlas(atlas, "Middle")

        self._trackLeft:AlignParentLeft()
        self._trackLeft:SetSize(11, 17)

        self._trackRight:AlignParentRight()
        self._trackRight:SetSize(11, 17)

        self._trackMiddle:RightOf(self._trackLeft, 0)
        self._trackMiddle:LeftOf(self._trackRight, 0)
        self._trackMiddle:SetHeight(17)

        -- Thumb
        local thumb = atlas:GetRegion("Button")
        self:SetThumbTexture(thumb.file)
        local thumbTex = self:GetThumbTexture()
        thumbTex:SetTexCoord(thumb.left, thumb.right, thumb.top, thumb.bottom)
        thumbTex:SetWidth(20)
        thumbTex:SetHeight(19)

        self:SetSize(200, 19)

        self:EnableMouseWheel(true)
        self:SetScript("OnMouseWheel", function(frame, delta)
            local val = self:GetValue()
            local min, max = self:GetMinMaxValues()
            local step = self:GetValueStep()
            if delta > 0 then
                self:SetValue(math.min(val + step, max))
            else
                self:SetValue(math.max(val - step, min))
            end
        end)

        self:SetScript("OnValueChanged", function(frame, value)
            if self.OnValueChanged then
                self:OnValueChanged(value)
            end
        end)
    end;

    -- ===== Slider-specific native pass-throughs =====

    SetValue = function(self, value)
        self._native:SetValue(value)
    end;

    GetValue = function(self)
        return self._native:GetValue()
    end;

    SetValueStep = function(self, step)
        self._native:SetValueStep(step)
    end;

    GetValueStep = function(self)
        return self._native:GetValueStep()
    end;

    SetMinMaxValues = function(self, min, max)
        self._native:SetMinMaxValues(min, max)
    end;

    GetMinMaxValues = function(self)
        return self._native:GetMinMaxValues()
    end;

    SetOrientation = function(self, orientation)
        self._native:SetOrientation(orientation)
    end;

    SetThumbTexture = function(self, tex)
        self._native:SetThumbTexture(tex)
    end;

    GetThumbTexture = function(self)
        local t = self._native:GetThumbTexture()
        return t and Texture(t) or nil
    end;

    SetMinMax = function(self, min, max)
        self:SetMinMaxValues(min, max)
    end;
}
