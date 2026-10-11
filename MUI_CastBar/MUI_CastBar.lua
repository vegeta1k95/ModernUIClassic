-- MUI_CastBar: Spawns the player cast bar (center bottom) and suppresses the native
-- PlayerCastingBarFrame. Target cast bar is owned by MUI_UnitFrames.

-- Player cast bar plus the edit-mode overlay. Only the player bar is movable; the
-- target bar stays anchored to the target frame. The bar is hidden except during a
-- cast, so edit mode paints a static preview to make it visible and grabbable.
class "CastBarEditable" : extends {"CastBar", "Editable"} {
    __init = function(self, parent, name, unit, width, height, label)
        CastBar.__init(self, parent, name, unit, width, height)
        Editable.__init(self)
        self:EditModeSetLabel(label)
        self:EditModeSetLabelSize(12)
        self:EditModeSetupSettings(function(content)
            self:_AddCastTimeSetting(content)
        end)
    end;

    -- Retail's "Show Cast Time". On unless turned off, as the bar has always
    -- shown it; it rides with the bar's layout.
    _AddCastTimeSetting = function(self, content)
        self.showCastTime = true

        self._chkCastTime = CheckBox(content, nil, HUD_EDIT_MODE_SETTING_CAST_BAR_SHOW_CAST_TIME)
        self._chkCastTime.label:SetFontSize(12)
        self._chkCastTime:SetSize(200, 29)
        self._chkCastTime:SetBoxSize(24, 24)
        self._chkCastTime:AlignParentTopLeft(0, 0)
        self._chkCastTime:SetChecked(true)
        self._chkCastTime.OnChanged = function(_, checked)
            self:SetShowCastTime(checked)
            self:EditModeNotifyChanged()
        end

        self:EditModeTrackSetting(
            function() return self.showCastTime end,
            function(v) self:SetShowCastTime(v) end,
            true)
    end;

    SetShowCastTime = function(self, show)
        self.showCastTime = show
        self.timeText:SetVisible(show)
        self._chkCastTime:SetChecked(show)
    end;

    -- Only the non-default (off) is stored, like scale.
    EditModeGetLayout = function(self)
        local data = Editable.EditModeGetLayout(self)
        if not self.showCastTime then
            data = data or {}
            data.showCastTime = false
        end
        return data
    end;

    EditModeApplyLayout = function(self, data)
        Editable.EditModeApplyLayout(self, data)
        if data and data.showCastTime == false then
            self:SetShowCastTime(false)
        end
    end;

    EditModeCleanLayout = function(self, data)
        local clean = Editable.EditModeCleanLayout(self, data)
        if data.showCastTime == false then clean.showCastTime = false end
        return clean
    end;

    EditModeShow = function(self)
        if not self._editEnabled then return end
        Editable.EditModeShow(self)
        self:ShowPreview("")
    end;

    EditModeHide = function(self)
        self:HidePreview()
        Editable.EditModeHide(self)
    end;
}

object "ModuleCastBar" : extends "Module" {
    __init = function(self)
        Module.__init(self, "CastBar")
    end;

    OnEnable = function(self)
        Frame(PlayerCastingBarFrame):Kill()

        self.playerBar = CastBarEditable(nil, "MUI_CastBar_Player", "player", 186, 9.5, "Cast Bar")
        self.playerBar:SetFrameStrata("HIGH")
        self.playerBar:EditModeSetOption("castBar")
        self.playerBar:AlignParentBottom(231)
        self.playerBar:EditModeSetDefaultPosition(function(f)
            f:ClearAllPoints()
            f:AlignParentBottom(231)
        end)
    end;
}
