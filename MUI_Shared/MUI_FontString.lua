-- FontString: Wraps a font string — either creates new or wraps existing
-- Create: FontString(parentCFrame, name, layer)
-- Wrap:   FontString(existingNativeFontString)

local DEFAULT_FONT_SIZE = 12

class "FontString" : extends {"Widget", "ScriptObject"} {
    __init = function(self, parentOrNative, name, layer)
        Widget.__init(self)

        if IsNativeObject(parentOrNative, "FontString") then
            -- WRAP existing native fontstring
            self._native = parentOrNative
        else
            -- CREATE new fontstring on parent
            self._native = parentOrNative._native:CreateFontString(name, layer or "OVERLAY")
            self._native:SetFont(MUI.FONT, DEFAULT_FONT_SIZE, "")
        end
    end;

    SetText = function(self, text)
        self._native:SetText(text)
    end;

    GetText = function(self)
        return self._native:GetText()
    end;

    SetFont = function(self, font, size, flags)
        self._native:SetFont(font or MUI.FONT, size or DEFAULT_FONT_SIZE, flags)
    end;
	
	GetFont = function(self)
		return self._native:GetFont()
	end;

    SetFontSize = function(self, size, flags)
        -- Route through SetFont so the nil-font guard applies: very early in a
        -- cold load GetFont() can return nil (fonts not resolved yet), and
        -- SetFont(nil, ...) throws. That throw, when it happens inside a
        -- main-chunk constructor (e.g. MUI_Minimap = MinimapFrame(Minimap)),
        -- aborts the whole assignment and cascades elsewhere.
        local ogFont, ogSize, ogFlags = self:GetFont()
        self:SetFont(ogFont, size, flags or ogFlags)
    end;

    SetTextColor = function(self, r, g, b, a)
        self._native:SetTextColor(r, g, b, a or 1)
    end;

    GetTextColor = function(self)
        return self._native:GetTextColor()
    end;

    SetJustifyH = function(self, align)
        self._native:SetJustifyH(align)
    end;

    SetJustifyV = function(self, align)
        self._native:SetJustifyV(align)
    end;

    SetShadowOffset = function(self, x, y)
        self._native:SetShadowOffset(x, y)
    end;

    SetShadowColor = function(self, r, g, b, a)
        self._native:SetShadowColor(r, g, b, a or 1)
    end;

    GetStringWidth = function(self)
        return self._native:GetStringWidth()
    end;

    SetTextHeight = function(self, height)
        self._native:SetTextHeight(height)
    end;

    GetStringHeight = function(self)
        return self._native:GetStringHeight()
    end;

    SetDrawLayer = function(self, layer, subLevel)
        self._native:SetDrawLayer(layer, subLevel)
    end;

    GetDrawLayer = function(self)
        return self._native:GetDrawLayer()
    end;

    SetWordWrap = function(self, wrap)
        self._native:SetWordWrap(wrap)
    end;

    SetSpacing = function(self, spacing)
        self._native:SetSpacing(spacing)
    end;

    SetRotation = function(self, radians)
        self._native:SetRotation(radians)
    end

}
