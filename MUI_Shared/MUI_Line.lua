-- Line: Wraps a WoW Line region — either creates new or wraps existing.
-- Line regions render a stroke between two endpoints at any angle natively,
-- so unlike Texture (which clips rotated rectangular content to its own
-- AABB), Line is the right primitive for angled glow strokes.
--
-- Inherits from Texture: SetColor, SetVertexColor, SetBlendMode, SetGradient,
-- SetDrawLayer, SetTexture, SetSubpixelRendering all work on Line natives
-- (shared LayeredRegion base). Texture-only methods (SetTexCoord, SetAtlas,
-- SetRotation, SetPortrait, SetMask, SetDesaturated) exist on the class but
-- will error at runtime — Line doesn't support them.
--
-- Create: Line(parentCFrame, name, layer)
-- Wrap:   Line(existingNativeLine)

class "Line" : extends "Texture" {
    __init = function(self, parentOrNative, name, layer)
        Widget.__init(self)

        if IsNativeObject(parentOrNative, "Line") then
            self._native = parentOrNative
        else
            layer = layer or "ARTWORK"
            self._native = parentOrNative._native:CreateLine(name, layer)
        end
    end;

    SetThickness = function(self, thickness)
        self._native:SetThickness(thickness)
    end;

    -- Endpoints are anchored like SetPoint: an anchor point name on a
    -- relative frame plus an (offsetX, offsetY). Unwrap Widget refs.
    SetStartPoint = function(self, point, relativeTo, offsetX, offsetY)
        if relativeTo and type(relativeTo) == "table" and relativeTo._native then
            relativeTo = relativeTo._native
        end
        self._native:SetStartPoint(point, relativeTo, offsetX or 0, offsetY or 0)
    end;

    SetEndPoint = function(self, point, relativeTo, offsetX, offsetY)
        if relativeTo and type(relativeTo) == "table" and relativeTo._native then
            relativeTo = relativeTo._native
        end
        self._native:SetEndPoint(point, relativeTo, offsetX or 0, offsetY or 0)
    end;
}
