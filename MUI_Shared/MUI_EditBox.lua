-- EditBox: native EditBox wrapper with three-part border + hint text.
--
-- Owns all the EditBox-specific native methods (SetText/GetText, focus
-- control, max-letters, numeric mode, text insets) — these don't belong
-- on Frame, which stays generic-Frame-only.

class "EditBox" : extends "Frame" {
    __init = function(self, parentOrNative, name)
        local objType = type(parentOrNative) == "table" and parentOrNative.GetObjectType and parentOrNative:GetObjectType()
        if objType == "EditBox" then
            -- WRAP existing edit box: just adopt the native, no styling overlays.
            Frame.__init(self, parentOrNative)
            self._focused = false
            return
        end

        -- CREATE a new styled edit box.
        Frame.__init(self, "EditBox", parentOrNative, name)
        self:EnableMouse(true)
        self:SetAutoFocus(false)
        self:SetFont(MUI.FONT, 10, "")
        self:SetTextInsets(12, 12, 0, 0)

        self._focused = false

        self._border = NineSlice(self)
        self._border:SetFromTextureRegion("editbox-search", 256, 64, 0, 0, 256, 40, 18, 14, 40, 14, 0.5)
        self._border:SetFrameLevel(self:GetFrameLevel() - 1)
        self._border:FillParent()
        self._border:SetDrawLayer("BACKGROUND", 5)

        self:SetSize(195, 22)

        self._hint = FontString(self, nil, "ARTWORK")
        self._hint:SetFont(MUI.FONT, 10)
        self._hint:SetTextColor(0.35, 0.35, 0.35, 1)
        self._hint:SetJustifyH("LEFT")
        self._hint:SetShadowOffset(1, -1)
        self._hint:AlignParentLeft(24)
        self._hint:AlignParentRight(24)
        self._hint:FillHeight()

        self:SetScript("OnEditFocusGained", function()
            self._focused = true
            self._hint:Hide()
            if self.OnFocusGained then self:OnFocusGained() end
        end)

        self:SetScript("OnEditFocusLost", function()
            self._focused = false
            self:_UpdateHint()
            if self.OnFocusLost then self:OnFocusLost() end
        end)

        self:SetScript("OnTextChanged", function()
            self:_UpdateHint()
            if self.OnTextChanged then
                self:OnTextChanged(self:GetText())
            end
        end)

        self:SetScript("OnEscapePressed", function()
            self:ClearFocus()
        end)

        self:SetScript("OnEnterPressed", function()
            if self.OnEnterPressed then
                self:OnEnterPressed(self:GetText())
            end
            self:ClearFocus()
        end)

        -- Click-outside-to-defocus. GLOBAL_MOUSE_DOWN fires on every
        -- mouse press anywhere; if we're focused and the press wasn't
        -- inside our own bounds, drop focus. Cheaper than polling
        -- IsMouseButtonDown via OnUpdate.
        self:RegisterEventHandler("GLOBAL_MOUSE_DOWN", function()
            if self._focused and not self:IsMouseOver() then
                self:ClearFocus()
            end
        end)
    end;

    -- ===== EditBox-specific native pass-throughs =====

    SetText = function(self, text)
        self._native:SetText(text)
        self:_UpdateHint()
    end;

    GetText = function(self)
        return self._native:GetText()
    end;

    SetAutoFocus = function(self, auto)
        self._native:SetAutoFocus(auto)
    end;

    ClearFocus = function(self)
        self._native:ClearFocus()
    end;

    SetMaxLetters = function(self, n)
        self._native:SetMaxLetters(n)
    end;

    SetNumeric = function(self, numeric)
        self._native:SetNumeric(numeric)
    end;

    SetTextInsets = function(self, l, r, t, b)
        self._native:SetTextInsets(l, r, t, b)
    end;

    SetFont = function(self, font, size, flags)
        self._native:SetFont(font, size, flags)
    end;

    -- ===== Hint helpers =====

    _UpdateHint = function(self)
        local text = self:GetText()
        if (not text or text == "") and not self._focused then
            self._hint:Show()
        else
            self._hint:Hide()
        end
    end;

    SetHint = function(self, text)
        self._hint:SetText(text)
    end;

    SetNumber = function(self, n)
        self._native:SetNumber(n)
    end;

    GetNumber = function(self)
        return self._native:GetNumber()
    end;

    HighlightText = function(self, l, r)
        if l == nil and r == nil then
            self._native:HighlightText()
        else
            self._native:HighlightText(l or 0, r or 0)
        end
    end;
}

-- EditBoxQuantity: small numeric input (used as quantity selector next to a
-- "Create" button). 3-slice border via Interface\Common\Common-Input-Border,
-- matching DFUI's `DragonflightUIProfessionInputBox` exactly. Numeric mode,
-- 3-letter max (so 0–999), clamps "0" → "1" on text-change.

class "EditBoxQuantity" : extends "Frame" {
    __init = function(self, parent, name)
        Frame.__init(self, "EditBox", parent, name)
        self:EnableMouse(true)
        self:SetAutoFocus(false)
        self:SetFont(MUI.FONT, 10.5, "")
        self:SetTextInsets(5, 2, 0, 0)
        self:SetMaxLetters(3)
        self:SetNumeric(true)
        self:SetJustifyH("LEFT")
        self:SetSize(32, 18)

        self._ns = NineSlice(self)
        self._ns:SetFrameLevel(self:GetFrameLevel() - 1)
        self._ns:FillParent()
        self._ns:SetFromTextureRegion("editbox-common", 128, 32, 0, 0, 128, 20, 4, 4, 4, 4, 0.9)
        self._ns:SetDrawLayer("BACKGROUND", 1)

        self:SetScript("OnEnterPressed",  function() self:ClearFocus() end)
        self:SetScript("OnEscapePressed", function() self:ClearFocus() end)
        self:SetScript("OnTextChanged",   function()
            if self.OnTextChanged then self:OnTextChanged(self:GetText()) end
        end)
        self:SetScript("OnEditFocusGained", function() self:HighlightText() end)
        self:SetScript("OnEditFocusLost",   function() self:HighlightText(0, 0) end)
    end;

    SetText        = function(self, t) self._native:SetText(t)       end;
    GetText        = function(self)    return self._native:GetText() end;
    SetNumber      = function(self, n) self._native:SetNumber(n)     end;
    GetNumber      = function(self)    return self._native:GetNumber() end;
    SetAutoFocus   = function(self, a) self._native:SetAutoFocus(a)  end;
    ClearFocus     = function(self)    self._native:ClearFocus()     end;
    SetMaxLetters  = function(self, n) self._native:SetMaxLetters(n) end;
    SetNumeric     = function(self, n) self._native:SetNumeric(n)    end;
    SetTextInsets  = function(self, l, r, t, b) self._native:SetTextInsets(l, r, t, b) end;
    SetFont        = function(self, f, s, fl) self._native:SetFont(f, s, fl) end;
    SetJustifyH    = function(self, j) self._native:SetJustifyH(j)   end;
    SetEnabled     = function(self, e)
        self._native:SetEnabled(e and true or false)
        if not e then self._native:ClearFocus() end
    end;
    HighlightText  = function(self, l, r)
        if l == nil and r == nil then self._native:HighlightText()
        else self._native:HighlightText(l or 0, r or 0) end
    end;
}
