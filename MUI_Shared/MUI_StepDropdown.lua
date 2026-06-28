-- StepDropdown: Dropdown with left/right stepper buttons

class "StepDropdown" : extends "Frame" {
    __init = function(self, parent, name)
        Frame.__init(self, "Frame", parent, name)

        local atlas = MUI_AtlasRegistry.Dropdown

        self._backBtn = Button(self)
        self._backBtn:SetSize(39, 39)
        self._backBtn:SetStateAtlas(atlas, "BtnFull", "BtnPressedFull", "BtnDisabledFull")
        self._backBtn:SetHighlightAtlas(atlas, "BtnHoverFull")

        self._backIcon = Texture(self._backBtn, nil, "OVERLAY")
        self._backIcon:SetAtlas(atlas, "IconBack")
        self._backIcon:CenterInParent()

        self._backBtn:AlignParentLeft(-7)

        self._forwardBtn = Button(self)
        self._forwardBtn:SetSize(39, 39)
        self._forwardBtn:SetStateAtlas(atlas, "BtnFull", "BtnPressedFull", "BtnDisabledFull")
        self._forwardBtn:SetHighlightAtlas(atlas, "BtnHoverFull")

        self._forwardIcon = Texture(self._forwardBtn, nil, "OVERLAY")
        self._forwardIcon:SetAtlas(atlas, "IconNext")
        self._forwardIcon:CenterInParent()

        self._forwardBtn:AlignParentRight(-7)

        self._dropdown = Dropdown(self, name and (name .. "DD") or nil)
        self._dropdown:RightOf(self._backBtn, -2)
        self._dropdown:LeftOf(self._forwardBtn, -2)
        self._dropdown:SetHeight(39)
        self:SetSize(223, 39)

        self._backBtn.OnClick = function()
            local idx = self._dropdown.selectedIndex
            if idx and idx > 1 then
                self._dropdown:SetSelected(idx - 1)
                self:_UpdateSteppers()
                if self.OnSelectionChanged then
                    self:OnSelectionChanged(idx - 1, self._dropdown.items[idx - 1])
                end
            end
        end

        self._forwardBtn.OnClick = function()
            local idx = self._dropdown.selectedIndex
            local count = table.getn(self._dropdown.items)
            if idx and idx < count then
                self._dropdown:SetSelected(idx + 1)
                self:_UpdateSteppers()
                if self.OnSelectionChanged then
                    self:OnSelectionChanged(idx + 1, self._dropdown.items[idx + 1])
                end
            end
        end

        self._dropdown.OnSelectionChanged = function(_, index, item)
            self:_UpdateSteppers()
            if self.OnSelectionChanged then
                self:OnSelectionChanged(index, item)
            end
        end
    end;

    _UpdateSteppers = function(self)
        local atlas = MUI_AtlasRegistry.Dropdown
        local idx = self._dropdown.selectedIndex or 0
        local count = table.getn(self._dropdown.items)

        if idx <= 1 then
            self._backBtn:SetEnabled(false)
            self._backIcon:SetAtlas(atlas, "IconBackDisabled")
        else
            self._backBtn:SetEnabled(true)
            self._backIcon:SetAtlas(atlas, "IconBack")
        end

        if idx >= count then
            self._forwardBtn:SetEnabled(false)
            self._forwardIcon:SetAtlas(atlas, "IconNextDisabled")
        else
            self._forwardBtn:SetEnabled(true)
            self._forwardIcon:SetAtlas(atlas, "IconNext")
        end
    end;

    SetItems = function(self, items)
        self._dropdown.minPopupWidth = nil
        self._dropdown:SetItems(items)
        self:_UpdateSteppers()
    end;

    SetSelected = function(self, index)
        self._dropdown:SetSelected(index)
        self:_UpdateSteppers()
    end;

    GetSelected = function(self)
        return self._dropdown:GetSelected()
    end;

    SetEnabled = function(self, enabled)
        local atlas = MUI_AtlasRegistry.Dropdown
        self._dropdown:EnableMouse(enabled)
        self._backBtn:SetEnabled(enabled)
        self._forwardBtn:SetEnabled(enabled)
        if enabled then
            self._backIcon:SetAtlas(atlas, "IconBack")
            self._forwardIcon:SetAtlas(atlas, "IconNext")
            self._dropdown.label:SetAlpha(1)
            self:_UpdateSteppers()
        else
            self._backIcon:SetAtlas(atlas, "IconBackDisabled")
            self._forwardIcon:SetAtlas(atlas, "IconNextDisabled")
            self._dropdown.label:SetAlpha(0.5)
        end
    end;
}
