-- Panel: Complete panel with border, title, and close button
-- Title text sits in the top border area (like retail)
-- Subclass with different border types for different panel styles

class "Panel" : extends "MetalBorder" {
    __init = function(self, parent, name, title, scale)
        MetalBorder.__init(self, parent, name, scale or 1)

        self:EnableMouse(true)

        self._closeButton = CloseButton(self)

        self:SetTitle(title)
    end;

    SetCloseVisible = function(self, visible)
        if visible then self._closeButton:Show() else self._closeButton:Hide() end
    end;

    SetCloseTarget = function(self, target)
        self._closeButton:SetSecureToggleTarget(target)
    end;

    SetTitle = function(self, text)
        if not self._title then
            self._title = FontString(self, nil, "OVERLAY")
            self._title:SetFontSize(12)
            self._title:SetTextColor(1, 0.82, 0, 1)
            self._title:AlignParentTop(4, 0)
            self._title:AlignParentLeft(20)
            self._title:AlignParentRight(20)
            self._title:SetJustifyH("CENTER")
            self._title:SetHeight(10)
        end
        self._title:SetText(text)
    end;
}


class "PanelPortrait" : extends "Frame" {

    __init = function(self, parent, name, title, scale, small)

        Frame.__init(self, "Frame", parent, name)

        -- Eat mouse input so clicks on the panel don't fall through to
        -- the 3D world (NPCs, doodads). EnableMouse alone is enough;
        -- no script handlers needed.
        self:EnableMouse(true)

        self._small = small and true or false

        self._content = Frame("Frame", self)
        self._content:FillParentPadding(5, 19, 1, 2)

        self._bg = Texture(self, nil, "BACKGROUND")
        self._bg:SetTexture(MUI.TEX_BASE .. "frame-background-rock")
        self._bg:Fill(self._content)

        self._border = MetalBorderPortrait(self, nil, scale or 0.9, small)
        self._border:FillParent()
        self._border:SetDrawLayer("OVERLAY")
        self._border:PutInfront(self._content, 20)

        self:PopulateContent(self._content)

        self:SetTitle(title)
    end;

    ---@abstract
    PopulateContent = function(self, content)
        -- Children override this
    end;

    GetBackgroundTexture = function(self)
        return self._bg
    end;

    SetCloseVisible = function(self, visible)
        if visible then self._closeButton:Show() else self._closeButton:Hide() end
    end;

    SetCloseTarget = function(self, target)
        self._closeButton:SetSecureToggleTarget(target)
    end;

    SetTitle = function (self, title)
        if not self._title then
            self._title = FontString(self._border, nil, "OVERLAY")
		    self._title:SetFontSize(10.5)
		    self._title:SetShadowOffset(1, -1)
		    self._title:SetTextColor(1, 0.82, 0, 1)
		    self._title:AlignParentTop(4, 0)
            self._title:AlignParentLeft(self._small and 42 or 65)
            self._title:AlignParentRight(26)
            self._title:SetJustifyH("CENTER")
            self._title:SetHeight(10)
        end

         self._title:SetText(title)
    end;

    SetPortrait = function(self, texture, size)

        if not self._portrait then
            self._portrait = Texture(self._border, nil, "ARTWORK")
            self._portrait:SetDrawLayer("ARTWORK", 2)
            self._portrait:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        end
        if self._small then
            self._portrait:SetPoint("CENTER", self, "TOPLEFT", 16.5, -13)
            self._portrait:SetSize(size or 32, size or 32)
        else
            self._portrait:SetPoint("CENTER", self, "TOPLEFT", 26.5, -18)
            self._portrait:SetSize(size or 55, size or 55)
        end
        self._portrait:SetTexture(texture)
    end;
}
