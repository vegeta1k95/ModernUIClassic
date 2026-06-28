-- StepSlider: Slider with left/right stepper buttons

class "StepSlider" : extends "Frame" {
    __init = function(self, parent, name)
        Frame.__init(self, "Frame", parent, name)

        local atlas = MUI_AtlasRegistry.SliderBarMinimal

        self._backBtn = Button(self)
        self._backBtn:SetSize(11, 19)
        self._backBtn:SetStateAtlas(atlas, "ButtonLeft", "ButtonLeft", "ButtonLeft")
        self._backBtn:SetHighlightAtlas(atlas, "ButtonLeft")
        self._backBtn:AlignParentLeft()

        self._forwardBtn = Button(self)
        self._forwardBtn:SetSize(9, 18)
        self._forwardBtn:SetStateAtlas(atlas, "ButtonRight", "ButtonRight", "ButtonRight")
        self._forwardBtn:SetHighlightAtlas(atlas, "ButtonRight")
        self._forwardBtn:AlignParentRight()

        self._slider = Slider(self)
        self._slider:RightOf(self._backBtn, 4)
        self._slider:LeftOf(self._forwardBtn, 4)
        self._slider:SetHeight(19)

        self:SetSize(250, 19)

        self._backBtn.OnClick = function()
            local val = self._slider:GetValue()
            local min, max = self._slider:GetMinMaxValues()
            local step = self._slider:GetValueStep()
            self._slider:SetValue(math.max(val - step, min))
        end

        self._forwardBtn.OnClick = function()
            local val = self._slider:GetValue()
            local min, max = self._slider:GetMinMaxValues()
            local step = self._slider:GetValueStep()
            self._slider:SetValue(math.min(val + step, max))
        end

        self._slider.OnValueChanged = function(_, value)
            if self.OnValueChanged then
                self:OnValueChanged(value)
            end
        end
    end;

    SetMinMax = function(self, min, max)
        self._slider:SetMinMax(min, max)
    end;

    SetValue = function(self, value)
        self._slider:SetValue(value)
    end;

    GetValue = function(self)
        return self._slider:GetValue()
    end;

    SetValueStep = function(self, step)
        self._slider:SetValueStep(step)
    end;
}
