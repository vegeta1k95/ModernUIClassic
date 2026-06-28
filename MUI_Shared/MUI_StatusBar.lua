-- StatusBar: native StatusBar wrapper with background fill.
--
-- Owns the StatusBar-specific native methods (SetValue/MinMax/orientation
-- + StatusBar texture/colour). These don't belong on Frame — generic
-- frames don't have status-bar value semantics.

class "StatusBar" : extends "Frame" {
    __init = function(self, parent, name)
        Frame.__init(self, "StatusBar", parent, name)

        -- Background behind the bar
        self._background = Texture(self, nil, "BACKGROUND")
        self._background:FillParent()
        self._background:SetColorTexture(0, 0, 0, 0.5)

        -- Default fill texture (built into vanilla client)
        self:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        self:SetMinMaxValues(0, 100)
        self:SetValue(100)
        self:SetStatusBarColor(0, 1, 0)
    end;

    -- ===== StatusBar-specific native pass-throughs =====

    SetValue = function(self, value)
        self._native:SetValue(value)
    end;

    GetValue = function(self)
        return self._native:GetValue()
    end;

    SetMinMaxValues = function(self, min, max)
        self._native:SetMinMaxValues(min, max)
    end;

    GetMinMaxValues = function(self)
        return self._native:GetMinMaxValues()
    end;

    SetStatusBarColor = function(self, r, g, b, a)
        self._native:SetStatusBarColor(r, g, b, a)
    end;

    SetStatusBarTexture = function(self, path)
        self._native:SetStatusBarTexture(path)
    end;

    GetStatusBarTexture = function(self)
        local t = self._native:GetStatusBarTexture()
        return t and Texture(t) or nil
    end;

    SetMinMax = function(self, min, max)
        self:SetMinMaxValues(min, max)
    end;

    SetBarColor = function(self, r, g, b, a)
        self:SetStatusBarColor(r, g, b, a or 1)
    end;

    SetBackgroundColor = function(self, r, g, b, a)
        self._background:SetColorTexture(r, g, b, a or 0.5)
    end;

    -- Set fill texture from a TextureAtlas region
    SetBarAtlas = function(self, atlas, regionName)
        local info = atlas:GetRegion(regionName)
        if info then
            self:SetStatusBarTexture(info.file)
            local barTex = self:GetStatusBarTexture()
            if barTex then
                barTex:SetTexCoord(info.left, info.right, info.top, info.bottom)
            end
        end
    end;

    -- Set fill texture from a file path
    SetBarTexture = function(self, path)
        self:SetStatusBarTexture(path)
    end;
}
