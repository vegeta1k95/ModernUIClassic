-- MUI_CastBar: Spawns the player cast bar (center bottom) and suppresses the vanilla
-- CastingBarFrame / PlayerCastingBarFrame. Target cast bar is owned by MUI_UnitFrames.

-- Player cast bar plus the edit-mode overlay. Only the player bar is movable; the
-- target bar stays anchored to the target frame. The bar is hidden except during a
-- cast, so edit mode paints a static preview to make it visible and grabbable.
class "CastBarEditable" : extends {"CastBar", "Editable"} {
    __init = function(self, parent, name, unit, width, height, label)
        CastBar.__init(self, parent, name, unit, width, height)
        Editable.__init(self)
        self:EditModeSetLabel(label)
        self:EditModeSetLabelSize(12)
        self:EditModeSetupSettings(function(content) end)
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
        Frame(CastingBarFrame):Kill()
        if PlayerCastingBarFrame then
            Frame(PlayerCastingBarFrame):Kill()
        end

        self.playerBar = CastBarEditable(nil, "MUI_CastBar_Player", "player", 186, 9.5, "Cast Bar")
        self.playerBar:SetFrameStrata("HIGH")
        self.playerBar:AlignParentBottom(231)
        self.playerBar:EditModeSetDefaultPosition(function(f)
            f:ClearAllPoints()
            f:AlignParentBottom(231)
        end)
    end;
}
