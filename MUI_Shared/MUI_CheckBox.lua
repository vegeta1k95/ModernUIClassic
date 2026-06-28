-- CheckBox: Atlas-based checkbox with checked/unchecked/disabled states.
-- Wraps a plain Frame so that clicks land on the whole widget (checkbox + label),
-- not only on the checkbox square. SetSize sizes the clickable hit area; the
-- inner checkbox square stays atlas-sized (SetBoxSize to change), and the label
-- lives right of it. Caller is responsible for making the frame wide enough to
-- cover the label area if they want label clicks to toggle.

class "CheckBox" : extends "Frame" {
    __init = function(self, parent, name, text)
        Frame.__init(self, "Frame", parent, name)
        self:EnableMouse(true)
        -- Let mouse motion bubble to parent frames so a surrounding row's
        -- OnEnter/OnLeave hover still fires while hovering the checkbox.
        self:SetPropagateMouseMotion(true)
        self:SetSize(30, 29)
        self._checked = false
        self._enabled = true

        local atlas = MUI_AtlasRegistry.CheckboxMinimal
        local bg    = atlas:GetRegion("Background")

        -- Inner visual-only checkbox square. Mouse enabled so the inner-hover
        -- OnEnter/OnLeave fire, but both motion and clicks propagate up to the
        -- outer frame so its OnMouseUp toggle fires when clicking the box.
        self._box = Frame("Frame", self, name and name .. "_Box" or nil)
        self._box:EnableMouse()
        self._box:SetPropagateMouseMotion(true)
        self._box:SetPropagateMouseClicks(true)
        self._box:SetSize(30, 29)
        self._box:AlignParentLeft()

        self._bgTex = Texture(self._box, nil, "BACKGROUND")
        self._bgTex:SetTexture(bg.file)
        self._bgTex:SetTexCoord(bg.left, bg.right, bg.top, bg.bottom)
        self._bgTex:FillParent()

        -- Hover highlight, shown on OnEnter of the whole frame (not just the box).
        self._hoverTex = Texture(self._box, nil, "OVERLAY")
        self._hoverTex:SetTexture(bg.file)
        self._hoverTex:SetTexCoord(bg.left, bg.right, bg.top, bg.bottom)
        self._hoverTex:SetBlendMode("ADD")
        self._hoverTex:FillParent()
        self._hoverTex:Hide()

        -- Check overlays (one for enabled, one for disabled-checked).
        self._check = Texture(self._box, nil, "OVERLAY")
        self._check:SetAtlas(atlas, "CheckMark")
        self._check:ClearAllPoints()
        self._check:FillParentPadding(-0.5,-0.5,-2, 0.5)
        
        self._disabledCheck = Texture(self._box, nil, "OVERLAY")
        self._disabledCheck:SetAtlas(atlas, "CheckMarkDisabled")
        self._disabledCheck:ClearAllPoints()
        self._disabledCheck:FillParentPadding(0,0,0,0)
        self._disabledCheck:Hide()

        if text then
            -- Public so callers can restyle (e.g. font size).
            self.label = FontString(self, nil, "OVERLAY")
            self.label:SetText(text)
            self.label:SetFontSize(12)
            self.label:SetTextColor(1, 1, 1, 1)
            self.label:RightOf(self._box, 6, 1)
        end

        -- Click anywhere on the frame toggles. MouseIsOver mirrors standard
        -- button behavior: only fire if the mouse is still over when released.
        self._box:SetScript("OnEnter", function()
            if self._enabled then self._hoverTex:Show() end
        end)
        self._box:SetScript("OnLeave", function() self._hoverTex:Hide() end)
        self:SetScript("OnMouseUp", function()
            if not self._enabled then return end
            if not self:IsMouseOver() then return end
            self._checked = not self._checked
            PlaySound(self._checked
                and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
                or  SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            self:_UpdateVisual()
            if self.OnChanged then self:OnChanged(self._checked) end
        end)
    end;

    _UpdateVisual = function(self)
        if self._enabled then
            self._disabledCheck:Hide()
            if self._checked then self._check:Show() else self._check:Hide() end
            if self.label then self.label:SetAlpha(1) end
        else
            self._check:Hide()
            self._hoverTex:Hide()
            if self._checked then self._disabledCheck:Show() else self._disabledCheck:Hide() end
            if self.label then self.label:SetAlpha(0.5) end
        end
    end;

    SetBoxSize = function(self, w, h)
        self._box:SetSize(w, h)
    end;

    SetChecked = function(self, checked)
        self._checked = checked
        self:_UpdateVisual()
    end;

    IsChecked = function(self)
        return self._checked
    end;

    SetEnabled = function(self, enabled)
        self._enabled = enabled
        self:_UpdateVisual()
    end;
}

class "CheckBoxThin" : extends "CheckBox" {
    __init = function(self, parent, name, text)
        CheckBox.__init(self, parent, name, text)
        
        self._bgTex:SetTextureRegion(MUI.TEX_BASE .. "checkbox-thin",    64, 32, 1,  1, 27, 26)
        self._hoverTex:SetTextureRegion(MUI.TEX_BASE .. "checkbox-thin", 64, 32, 1,  1, 27, 26)
        self._check:SetTextureRegion(MUI.TEX_BASE .. "checkbox-thin",    64, 32, 32, 0, 32, 27)

        self._bgTex:SetSubpixelRendering(true)
        self._hoverTex:SetSubpixelRendering(true)

        self:SetSize(12.8, 13)
        self:SetBoxSize(12.8, 13)

    end;
}
