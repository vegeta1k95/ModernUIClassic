-- MinimapFrame: wrapper for the native Minimap-type frame.
-- Owns the Minimap-specific native methods (blip texture, POI arrows,
-- player-arrow texture, zoom). Wrap the singleton: MinimapFrame(_G.Minimap).

class "MinimapFrame" : extends {"Frame", "Editable"} {
    __init = function(self, native)
        Frame.__init(self, native)
        Editable.__init(self)

        self:EditModeSetLabel("Minimap")
        self:EditModeSetupSettings(function(content)

        end)

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
