-- SearchBox: EditBox with search icon, clear button, and focus dimming

class "SearchBox" : extends "EditBox" {
    __init = function(self, parent, name)
        EditBox.__init(self, parent, name)
        self:SetTextInsets(24, 24, 0, 0)

        local atlas = MUI_AtlasRegistry.EditBoxSearch

        self._hint:ClearAllPoints()
        self._hint:AlignParentLeft(22)
        self._hint:AlignParentRight(22)
        self:SetHint("Search")

        self._searchIcon = Texture(self, nil, "OVERLAY")
        self._searchIcon:SetAtlas(atlas, "SearchIcon")
        self._searchIcon:SetSize(10, 10)
        self._searchIcon:AlignParentLeft(6)
        self._searchIcon:SetAlpha(0.5)

        self._clearBtn = Button(self)
        self._clearBtn:SetSize(10, 10)
        self._clearBtn:AlignParentRight(7, 0)
        self._clearBtn:Hide()

        self._clearBtnIcon = Texture(self._clearBtn, nil, "ARTWORK")
        self._clearBtnIcon:SetAtlas(atlas, "ClearButton")
        self._clearBtnIcon:FillParent()
        self._clearBtnIcon:SetAlpha(0.5)

        self._clearBtn.OnEnter = function()
            self._clearBtnIcon:SetAlpha(1.0)
        end
        self._clearBtn.OnLeave = function()
            self._clearBtnIcon:SetAlpha(0.5)
        end
        self._clearBtn.OnClick = function()
            self:SetText("")
            self:ClearFocus()
        end

        self.OnFocusGained = function()
            self._searchIcon:SetAlpha(1.0)
            self:_UpdateClearButton()
        end

        self.OnFocusLost = function()
            self._searchIcon:SetAlpha(0.5)
            self._clearBtn:Hide()
        end

        self.OnTextChanged = function(_, text)
            self:_UpdateClearButton()
        end
    end;

    _UpdateClearButton = function(self)
        local text = self:GetText()
        if self._focused and text and text ~= "" then
            self._clearBtn:Show()
        else
            self._clearBtn:Hide()
        end
    end;
}
