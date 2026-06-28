-- Button: Base button class — creates new or wraps existing Button frame
-- Create: Button(parent, name, text)
-- Wrap:   Button(existingNativeButton)

class "Button" : extends "Frame" {

    __init = function(self, parentOrNative, name, text)

        if IsNativeObject(parentOrNative, "Button") or 
           IsNativeObject(parentOrNative, "CheckButton") then
            Frame.__init(self, parentOrNative)
            self._enabled = true
            return
        end

        -- CREATE new button
        Frame.__init(self, "Button", parentOrNative, name)
        self._native:EnableMouse(true)
        self._enabled = true
        self._sound = SOUNDKIT.GS_TITLE_OPTION_OK

        self._native:SetScript("OnEnter", function() if self.OnEnter then self:OnEnter() end end)
        self._native:SetScript("OnLeave", function() if self.OnLeave then self:OnLeave() end end)
        self._native:SetScript("OnClick", function(_, button)
            if self._enabled and self.OnClick then
                if self._sound then
                    PlaySound(self._sound)
                end
                self:OnClick(button)
            end
        end)

        if text then
            self.label = FontString(self, nil, "OVERLAY")
            self.label:FillParent()
            self.label:SetJustifyH("CENTER")
            self.label:SetJustifyV("MIDDLE")
            self.label:SetText(text)
        end

    end;

    SetText = function(self, text)
        if not self.label then
            self.label = FontString(self, nil, "OVERLAY")
            self.label:FillParent()
            self.label:SetJustifyH("CENTER")
            self.label:SetJustifyV("MIDDLE")
        end
        self.label:SetText(text)
    end;

    SetNormalTexture = function(self, path, hWrap, vWrap)
        self._native:SetNormalTexture(path, hWrap, vWrap)
        return self:GetNormalTexture()
    end;

    SetHighlightTexture = function(self, path, hWrap, vWrap)
        self._native:SetHighlightTexture(path, hWrap, vWrap)
        return self:GetHighlightTexture()
    end;

    SetPushedTexture = function(self, path, hWrap, vWrap)
        self._native:SetPushedTexture(path, hWrap, vWrap)
        return self:GetPushedTexture()
    end;

    SetDisabledTexture = function(self, path, hWrap, vWrap)
        self._native:SetDisabledTexture(path, hWrap, vWrap)
        return self:GetDisabledTexture()
    end;

    GetNormalTexture = function(self)
        local tex = self._native:GetNormalTexture()
        return tex and Texture(tex) or nil
    end;

    GetPushedTexture = function(self)
        local tex = self._native:GetPushedTexture()
        return tex and Texture(tex) or nil
    end;

    GetHighlightTexture = function(self)
        local tex = self._native:GetHighlightTexture()
        return tex and Texture(tex) or nil
    end;

    GetDisabledTexture = function(self)
        local tex = self._native:GetDisabledTexture()
        return tex and Texture(tex) or nil
    end;

    SetCheckedTexture = function(self, path)
        if self._native.SetCheckedTexture then
            self._native:SetCheckedTexture(path)
        end
    end;

    GetCheckedTexture = function(self)
        if self._native.GetCheckedTexture then
            local tex = self._native:GetCheckedTexture()
            return tex and Texture(tex) or nil
        end
        return nil
    end;

    SetStateAtlas = function(self, atlas, normal, pressed, disabled)
        local normalRegion = atlas:GetRegion(normal)
        if normalRegion then
            self._native:SetNormalTexture(normalRegion.file)
            local tex = self._native:GetNormalTexture()
            if tex then tex:SetTexCoord(normalRegion.left, normalRegion.right, normalRegion.top, normalRegion.bottom) end
        end

        if pressed then
            local pressedRegion = atlas:GetRegion(pressed)
            if pressedRegion then
                self._native:SetPushedTexture(pressedRegion.file)
                local tex = self._native:GetPushedTexture()
                if tex then tex:SetTexCoord(pressedRegion.left, pressedRegion.right, pressedRegion.top, pressedRegion.bottom) end
            end
        end

        if disabled then
            local disabledRegion = atlas:GetRegion(disabled)
            if disabledRegion then
                self._native:SetDisabledTexture(disabledRegion.file)
                local tex = self._native:GetDisabledTexture()
                if tex then tex:SetTexCoord(disabledRegion.left, disabledRegion.right, disabledRegion.top, disabledRegion.bottom) end
            end
        end
    end;

    SetHighlightAtlas = function(self, atlas, regionName, additive)
        local region = atlas:GetRegion(regionName)
        if region then
            self._native:SetHighlightTexture(region.file)
            local hl = self._native:GetHighlightTexture()
            if hl then
                hl:SetTexCoord(region.left, region.right, region.top, region.bottom)
                if additive then
                    hl:SetBlendMode("ADD")
                end
            end
        end
    end;

    SetEnabled = function(self, enabled)
        self._enabled = enabled
        if enabled then
            self._native:Enable()
        else
            self._native:Disable()
        end
    end;

    Enable = function(self)
        self:SetEnabled(true)
    end;

    Disable = function(self)
        self:SetEnabled(false)
    end;

    SetButtonState = function(self, state, locked)
        self._native:SetButtonState(state, locked)
    end;

    GetButtonState = function(self)
        return self._native:GetButtonState()
    end;

    Click = function(self)
        self._native:Click()
    end;

    RegisterForClicks = function(self, ...)
        self._native:RegisterForClicks(...)
    end;

    -- Set the icon texture of an ItemButton-style native (bag slot, action
    -- slot, etc.) via Blizzard's SetItemButtonTexture helper.
    SetItemButtonTexture = function(self, path)
        SetItemButtonTexture(self._native, path)
    end;

    -- Resolve the action-page-aware action ID for an ActionButton-style
    -- native. Returns nil for buttons that aren't action buttons.
    GetActionID = function(self)
        if ActionButton_GetPagedID then
            return ActionButton_GetPagedID(self._native)
        end
    end;

    SetClickSound = function(self, sound)
        self._sound = sound
    end
}
