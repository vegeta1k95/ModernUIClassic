-- MinimapFrame: wrapper for the native Minimap-type frame.
-- Owns the Minimap-specific native methods (blip texture, POI arrows,
-- player-arrow texture, zoom). Wrap the singleton: MinimapFrame(_G.Minimap).

class "MinimapFrame" : extends {"Frame", "Editable"} {
    __init = function(self, native)
        Frame.__init(self, native)
        Editable.__init(self)

        self:EditModeSetLabel("Minimap")
        self:EditModeSetupSettings(function(content)
            self:_AddRotateSetting(content)
        end)

    end;

    -- 1.15.9 moved "Rotate Minimap" out of Options into Blizzard's Edit Mode, which
    -- writes its own value back on every layout apply. Ours rides with our layout
    -- and is re-asserted after Blizzard's.
    _AddRotateSetting = function(self, content)
        self.rotateMinimap = GetCVarBool("rotateMinimap")

        self._chkRotate = CheckBox(content, nil, HUD_EDIT_MODE_SETTING_MINIMAP_ROTATE_MINIMAP)
        self._chkRotate.label:SetFontSize(12)
        self._chkRotate:SetSize(200, 29)
        self._chkRotate:SetBoxSize(24, 24)
        self._chkRotate:AlignParentTopLeft(0, 0)
        self._chkRotate:SetChecked(self.rotateMinimap)
        self._chkRotate.OnChanged = function(_, checked)
            self:SetRotateMinimap(checked)
            self:EditModeNotifyChanged()
        end

        self:EditModeTrackSetting(
            function() return self.rotateMinimap end,
            function(v) self:SetRotateMinimap(v) end,
            false)

        hooksecurefunc(MinimapCluster, "SetRotateMinimap", function()
            SetCVar("rotateMinimap", self.rotateMinimap and "1" or "0")
        end)
    end;

    SetRotateMinimap = function(self, rotate)
        self.rotateMinimap = rotate
        SetCVar("rotateMinimap", rotate and "1" or "0")
        self._chkRotate:SetChecked(rotate)
    end;

    -- Only the non-default (on) is stored, like scale.
    EditModeGetLayout = function(self)
        local data = Editable.EditModeGetLayout(self)
        if self.rotateMinimap then
            data = data or {}
            data.rotateMinimap = true
        end
        return data
    end;

    EditModeApplyLayout = function(self, data)
        Editable.EditModeApplyLayout(self, data)
        if data and data.rotateMinimap then
            self:SetRotateMinimap(true)
        end
    end;

    EditModeCleanLayout = function(self, data)
        local clean = Editable.EditModeCleanLayout(self, data)
        if data.rotateMinimap == true then clean.rotateMinimap = true end
        return clean
    end;

    SetBlipTexture = function(self, path)
        self._native:SetBlipTexture(path)
    end;

    SetPOIArrowTexture = function(self, path)
        self._native:SetPOIArrowTexture(path)
    end;

    SetCorpsePOIArrowTexture = function(self, path)
        self._native:SetCorpsePOIArrowTexture(path)
    end;

    SetStaticPOIArrowTexture = function(self, path)
        self._native:SetStaticPOIArrowTexture(path)
    end;

    SetPlayerTexture = function(self, path)
        self._native:SetPlayerTexture(path)
    end;

    GetZoom = function(self)
        return self._native:GetZoom()
    end;

    SetZoom = function(self, level)
        self._native:SetZoom(level)
    end;
}
