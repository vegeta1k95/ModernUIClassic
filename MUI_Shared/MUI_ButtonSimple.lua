-- ButtonSimple: a button whose normal/pushed/highlight/disabled states
-- are all derived from a single texture path. Call SetTexture(path) once.
--   normal     — the texture, as-is
--   pushed     — the texture shifted +1 px right, -1 px down (pressed-in)
--   highlight  — the texture at alpha 0.4 with ADD blend
--   disabled   — the texture desaturated

class "ButtonSimple" : extends "Button" {

    __init = function(self, parent, name)
        Button.__init(self, parent, name)
    end;

    -- Matches Texture:SetTextureRegion's signature.
    SetTexture = function(self, path, fileW, fileH, x, y, w, h, invertH, invertV)
        local function apply(tex)
            if tex then
                tex:SetTextureRegion(path, fileW, fileH, x, y, w, h, invertH, invertV)
            end
            return tex
        end

        local normal = apply(self:SetNormalTexture(path))

        local pushed = apply(self:SetPushedTexture(path))
        if pushed then
            pushed:ClearAllPoints()
            pushed:SetPoint("TOPLEFT",     self, "TOPLEFT",      1, -1)
            pushed:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT",  1, -1)
        end

        local highlight = apply(self:SetHighlightTexture(path))
        if highlight then
            highlight:SetAlpha(0.4)
            highlight:SetBlendMode("ADD")
        end

        local disabled = apply(self:SetDisabledTexture(path))
        if disabled then
            disabled:SetDesaturated(true)
            disabled:SetVertexColor(0.6, 0.6, 0.6, 1)
        end

        return normal
    end;
}
