-- Widget: Base class for all UI elements
-- Holds native WoW region/frame reference, parent/child relationships, positioning

class "Widget" {
    __init = function(self)
        self._native = nil
    end;

    SetVisible = function(self, visible)
        if visible then self:Show() else self:Hide() end
    end;

    Show = function(self)
        self._native:Show()
    end;

    Hide = function(self)
        self._native:Hide()
    end;

    IsShown = function(self)
        return self._native:IsShown()
    end;

    IsVisible = function(self)
        return self._native:IsVisible()
    end;

    IsObjectType = function(self, t)
        return self._native:IsObjectType(t)
    end;

    GetObjectType = function(self)
        return self._native:GetObjectType()
    end;

    SetSize = function(self, w, h)
        self:SetWidth(w)
        self:SetHeight(h or w)
    end;

    SetWidth = function(self, w)
        self._native:SetWidth(w)
    end;

    SetHeight = function(self, h)
        self._native:SetHeight(h)
    end;

    GetWidth = function(self)
        return self._native:GetWidth()
    end;

    GetHeight = function(self)
        return self._native:GetHeight()
    end;

    GetCenter = function(self)
        return self._native:GetCenter()
    end;

    GetTop = function(self)
        return self._native:GetTop()
    end;

    GetBottom = function(self)
        return self._native:GetBottom()
    end;

    GetLeft = function(self)
        return self._native:GetLeft()
    end;

    GetRight = function(self)
        return self._native:GetRight()
    end;

    GetParent = function(self)
        return self._native:GetParent()
    end;

    GetEffectiveScale = function(self)
        return self._native:GetEffectiveScale()
    end;

    IsMouseOver = function(self)
        return MouseIsOver(self._native)
    end;

    SetPoint = function(self, point, relativeTo, relativePoint, x, y)
        -- If relativeTo is a Widget, unwrap to native
        if relativeTo and type(relativeTo) == "table" and relativeTo._native then
            relativeTo = relativeTo._native
        end
        self._native:SetPoint(point, relativeTo, relativePoint, x or 0, y or 0)
    end;

    ClearAllPoints = function(self)
        self._native:ClearAllPoints()
    end;

    GetNumPoints = function(self)
        return self._native:GetNumPoints()
    end;

    -- Returns (point, relativeTo, relativePoint, offsetX, offsetY). relativeTo
    -- is the raw native frame, not a wrapper.
    GetPoint = function(self, index)
        return self._native:GetPoint(index)
    end;

    -- Live debug: attach the singleton PositionDebugger to this widget so its
    -- size + anchor offsets can be tuned in-game without /reload. See
    -- MUI_Core/MUI_PositionDebugger.lua.
    AttachPositionDebugger = function(self)
        if MUI_PositionDebugger then
            MUI_PositionDebugger:Attach(self)
        end
    end;

    SetAllPoints = function(self, target)
        if target and type(target) == "table" and target._native then
            target = target._native
        end
        if target then
            self._native:SetAllPoints(target)
        else
            self._native:SetAllPoints()
        end
    end;

    SetAlpha = function(self, alpha)
        self._native:SetAlpha(alpha)
    end;

    GetAlpha = function(self)
        return self._native:GetAlpha()
    end;

    SetScale = function(self, scale)
        self._native:SetScale(scale)
    end;

    GetScale = function(self)
        return self._native:GetScale()
    end;

    -- ===================================================================
    -- Android-style layout helpers
    -- All offsets are positive = inward (toward center), no Y-flip needed
    -- "parent" below means self._parent, or UIParent if no parent
    -- ===================================================================

    _GetParentRef = function(self)
        if self._parent then return self._parent end
        -- For wrapped frames, use the native parent
        if self._native and self._native.GetParent then
            local nativeParent = self._native:GetParent()
            if nativeParent then
                return { _native = nativeParent }
            end
        end
        return MUI_Root or { _native = UIParent }
    end;
	
	SetParent = function(self, parentWidget)
		if not self._native then return end	
        if type(parentWidget) == "table" and parentWidget._native then
            self._native:SetParent(parentWidget._native)
        else
            self._native:SetParent(parentWidget)
        end
    end;

    -- === Align to parent edges (like alignParentTop, alignParentLeft, etc.) ===

    AlignParentTop = function(self, offset, offsetX)
        local p = self:_GetParentRef()
        self:SetPoint("TOP", p, "TOP", (offsetX or 0), -(offset or 0))
    end;

    AlignParentBottom = function(self, offset, offsetX)
        local p = self:_GetParentRef()
        self:SetPoint("BOTTOM", p, "BOTTOM", (offsetX or 0), (offset or 0))
    end;

    AlignParentLeft = function(self, offset, offsetY)
        local p = self:_GetParentRef()
        self:SetPoint("LEFT", p, "LEFT", (offset or 0), (offsetY or 0))
    end;

    AlignParentRight = function(self, offset, offsetY)
        local p = self:_GetParentRef()
        self:SetPoint("RIGHT", p, "RIGHT", -(offset or 0), (offsetY or 0))
    end;

    -- Corner helpers: first param matches first word, second matches second
    -- AlignParentTopLeft(top, left) — top=inward from top, left=inward from left
    AlignParentTopLeft = function(self, top, left)
        local p = self:_GetParentRef()
        self:SetPoint("TOPLEFT", p, "TOPLEFT", (left or 0), -(top or 0))
    end;

    AlignParentTopRight = function(self, top, right)
        local p = self:_GetParentRef()
        self:SetPoint("TOPRIGHT", p, "TOPRIGHT", -(right or 0), -(top or 0))
    end;

    AlignParentBottomLeft = function(self, bottom, left)
        local p = self:_GetParentRef()
        self:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", (left or 0), (bottom or 0))
    end;

    AlignParentBottomRight = function(self, bottom, right)
        local p = self:_GetParentRef()
        self:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -(right or 0), (bottom or 0))
    end;

    -- === Centering helpers ===
	
	CenterAt = function(self, widget, offsetX, offsetY)
        self:SetPoint("CENTER", widget, "CENTER", (offsetX or 0), (offsetY or 0))
    end;

    CenterInParent = function(self, offsetX, offsetY)
        local p = self:_GetParentRef()
        self:SetPoint("CENTER", p, "CENTER", (offsetX or 0), (offsetY or 0))
    end;

    -- === Relative to sibling (like layout_below, layout_toRightOf, etc.) ===

    Below = function(self, other, offsetY, offsetX)
        self:SetPoint("TOP", other, "BOTTOM", (offsetX or 0), -(offsetY or 0))
    end;

    Above = function(self, other, offsetY, offsetX)
        self:SetPoint("BOTTOM", other, "TOP", (offsetX or 0), (offsetY or 0))
    end;

    RightOf = function(self, other, offsetX, offsetY)
        self:SetPoint("LEFT", other, "RIGHT", (offsetX or 0), (offsetY or 0 ))
    end;

    LeftOf = function(self, other, offsetX, offsetY)
        self:SetPoint("RIGHT", other, "LEFT", -(offsetX or 0), (offsetY or 0))
    end;

    -- === Fill parent (like match_parent) ===
    -- padding = uniform inset from all edges

    Fill = function(self,  other, l, t, r, b)
        self:SetPoint("TOPLEFT", other, "TOPLEFT", l or 0, -(t or 0))
        self:SetPoint("BOTTOMRIGHT", other, "BOTTOMRIGHT", -(r or 0), b or 0)
    end;

    FillParent = function(self, padding)
        local p = self:_GetParentRef()
        local pad = padding or 0
        self:SetPoint("TOPLEFT", p, "TOPLEFT", pad, -pad)
        self:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -pad, pad)
    end;
	
	FillParentPadding = function(self, padL, padT, padR, padB)
        local p = self:_GetParentRef()
        self:SetPoint("TOPLEFT", p, "TOPLEFT", padL or 0, -(padT or 0))
        self:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -(padR or 0), padB or 0)
    end;

    -- Stretch width to match parent, keep own height
    FillWidth = function(self, padding, offsetY)
        local p = self:_GetParentRef()
        local pad = padding or 0
        self:SetPoint("LEFT", p, "LEFT", pad, offsetY or 0)
        self:SetPoint("RIGHT", p, "RIGHT", -pad, offsetY or 0)
    end;

    -- Stretch height to match parent, keep own width
    FillHeight = function(self, padding)
        local p = self:_GetParentRef()
        local pad = padding or 0
        self:SetPoint("TOP", p, "TOP", 0, -pad)
        self:SetPoint("BOTTOM", p, "BOTTOM", 0, pad)
    end;

    -- === Align edges with a sibling ===

    AlignTop = function(self, other, offset)
        self:SetPoint("TOP", other, "TOP", 0, -(offset or 0))
    end;

    AlignBottom = function(self, other, offset)
        self:SetPoint("BOTTOM", other, "BOTTOM", 0, (offset or 0))
    end;

    AlignLeft = function(self, other, offset)
        self:SetPoint("LEFT", other, "LEFT", (offset or 0), 0)
    end;

    AlignRight = function(self, other, offset)
        self:SetPoint("RIGHT", other, "RIGHT", -(offset or 0), 0)
    end;
    

    -- === Align to sibling edge, centered on the other axis ===

    AlignLeftCenter = function(self, other, offset)
        self:SetPoint("RIGHT", other, "LEFT", -(offset or 0), 0)
    end;

    AlignRightCenter = function(self, other, offset)
        self:SetPoint("LEFT", other, "RIGHT", (offset or 0), 0)
    end;

    AlignTopCenter = function(self, other, offset)
        self:SetPoint("BOTTOM", other, "TOP", 0, (offset or 0))
    end;

    AlignBottomCenter = function(self, other, offset)
        self:SetPoint("TOP", other, "BOTTOM", 0, -(offset or 0))
    end;

    -- === Stretch between two siblings ===

    -- Stretch vertically between bottom of 'top' and top of 'bottom' widget
    FillBetweenV = function(self, topWidget, bottomWidget, overlap)
        local o = overlap or 0
        self:SetPoint("TOPLEFT", topWidget, "BOTTOMLEFT", 0, o)
        self:SetPoint("BOTTOMRIGHT", bottomWidget, "TOPRIGHT", 0, -o)
    end;

    -- Stretch horizontally between right of 'left' and left of 'right' widget
    -- overlap = optional px to extend into each side (fixes sub-pixel gaps)
    FillBetweenH = function(self, leftWidget, rightWidget, overlap)
        local o = overlap or 0
        self:SetPoint("TOPLEFT", leftWidget, "TOPRIGHT", -o, 0)
        self:SetPoint("BOTTOMRIGHT", rightWidget, "BOTTOMLEFT", o, 0)
    end;

    -- Position at another widget's top-left with a downward offset
    AnchorToTopOf = function(self, other, offsetDown)
        self:SetPoint("TOPLEFT", other, "TOPLEFT", 0, -(offsetDown or 0))
    end;

	-- ========================= Technical ================================

    GetName = function(self)
        return self._native and self._native.GetName and self._native:GetName()
    end;

    Reparent = function(self, nativeFrame)
        nativeFrame:SetParent(self._native)
    end;
    
}
