-- NineSlice: Base class for nine-slice bordered frames
-- Subclass this for each border style (MetalBorder, TooltipBorder, etc.)
-- SetLayout takes a direct layout TABLE, not a name


local MUI_TEX_PATH = "Interface\\AddOns\\ModernUI\\assets\\textures\\"

class "NineSlice" : extends "Frame" {
    __init = function(self, parent, name)
        Frame.__init(self, "Frame", parent, name)

        self._textures = {}
        local borderPieces = { "TopLeft", "Top", "TopRight", "Left", "Right", "BottomLeft", "Bottom", "BottomRight" }
        for _, piece in ipairs(borderPieces) do
            self._textures[piece] = Texture(self, nil, "OVERLAY")
        end
        self._textures.Center = Texture(self, nil, "BACKGROUND")
    end;

    -- Apply a layout table directly
    SetLayout = function(self, layout)
        local t = self._textures

        -- Apply textures/colors and sizes
        for pieceName, tex in pairs(t) do
            local info = layout[pieceName]
            if info then
                if info.color then
                    tex:SetColorTexture(info.color[1], info.color[2], info.color[3], info.color[4] or 1)
                elseif info.atlas and info.region then
                    -- TextureAtlas object + region name
                    tex:SetAtlas(info.atlas, info.region)
                elseif info.file then
                    tex:SetTexture(info.file)
                    if info.left then
                        tex:SetTexCoord(info.left, info.right, info.top, info.bottom)
                    end
                end

                local scale = info.scale or 1.0

                if info.width then tex:SetWidth(info.width * scale) end
                if info.height then tex:SetHeight(info.height * scale) end
            end
        end

        -- Corner offsets
        local tl = layout.TopLeft or {}
        local tr = layout.TopRight or {}
        local bl = layout.BottomLeft or {}
        local br = layout.BottomRight or {}

        for _, tex in pairs(t) do tex:ClearAllPoints() end

        t.TopLeft:SetPoint("TOPLEFT", self, "TOPLEFT", tl.x or 0, tl.y or 0)
        t.TopRight:SetPoint("TOPRIGHT", self, "TOPRIGHT", tr.x or 0, tr.y or 0)
        t.BottomLeft:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", bl.x or 0, bl.y or 0)
        t.BottomRight:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", br.x or 0, br.y or 0)

        t.Top:SetPoint("TOPLEFT", t.TopLeft, "TOPRIGHT", 0, 0)
        t.Top:SetPoint("TOPRIGHT", t.TopRight, "TOPLEFT", 0, 0)

        t.Bottom:SetPoint("BOTTOMLEFT", t.BottomLeft, "BOTTOMRIGHT", 0, 0)
        t.Bottom:SetPoint("BOTTOMRIGHT", t.BottomRight, "BOTTOMLEFT", 0, 0)

        t.Left:SetPoint("TOPLEFT", t.TopLeft, "BOTTOMLEFT", 0, 0)
        t.Left:SetPoint("BOTTOMLEFT", t.BottomLeft, "TOPLEFT", 0, 0)

        t.Right:SetPoint("TOPRIGHT", t.TopRight, "BOTTOMRIGHT", 0, 0)
        t.Right:SetPoint("BOTTOMRIGHT", t.BottomRight, "TOPRIGHT", 0, 0)

        -- Two Center anchor modes:
        --   * Explicit insets (any of insetLeft/Right/Top/Bottom set) →
        --     anchor to the frame edges with those inset offsets. Used
        --     when Center is a content fill that should extend past the
        --     corner pieces' inner edges (e.g. MetalBorder's dark bg
        --     where corners protrude outward and Center fills the actual
        --     interior, not the inner corner rect).
        --   * No insets → anchor between the corner pieces. This is the
        --     natural fit for a true 9-slice texture, where the center
        --     slice must occupy exactly the inner rect defined by the
        --     corner sizes / offsets.

        local ci = layout.Center or {}
        if ci.insetLeft or ci.insetRight or ci.insetTop or ci.insetBottom then
            local inL = ci.insetLeft or 4
            local inR = ci.insetRight or 4
            local inT = ci.insetTop or 4
            local inB = ci.insetBottom or 4
            t.Center:SetPoint("TOPLEFT", self, "TOPLEFT", inL, -inT)
            t.Center:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -inR, inB)
        else
            t.Center:SetPoint("TOPLEFT", t.TopLeft, "BOTTOMRIGHT", 0, 0)
            t.Center:SetPoint("BOTTOMRIGHT", t.BottomRight, "TOPLEFT", 0, 0)
        end
    end;

    SetDrawLayer = function(self, layer, sublevel)
        for _, tex in pairs(self._textures) do
            tex:SetDrawLayer(layer, sublevel)
        end
    end;

    SetBlendMode = function(self, mode)
        for _, tex in pairs(self._textures) do
            tex:SetBlendMode(mode)
        end
    end;

    SetVertexColor = function(self, r, g, b, a)
        for _, tex in pairs(self._textures) do
            tex:SetVertexColor(r, g, b, a)
        end
    end;

    -- Flip subpixel rendering for all 9 pieces at once. Nameplate bars and
    -- any other nine-slice frame that's repositioned at fractional-pixel
    -- precision (e.g. moves with the world) should enable this for smooth
    -- motion.
    SetSubpixelRendering = function(self, enable)
        for _, tex in pairs(self._textures) do
            tex:SetSubpixelRendering(enable)
        end
    end;

    _SetNineSlice = function(self, file, left, right, top, bottom, w, h, marginL, marginT, marginR, marginB, scale)

        local dx = (right - left) / w  -- texcoord units per source pixel
        local dy = (bottom - top) / h

        local midL = left   + marginL * dx
        local midR = right  - marginR * dx
        local midT = top    + marginT * dy
        local midB = bottom - marginB * dy

        local function piece(l, rt, t, b) return { file = file, left = l, right = rt, top = t, bottom = b, scale = scale or 1 } end

        local layout = {
            TopLeft     = piece(left,   midL,    top,    midT),
            Top         = piece(midL,   midR,    top,    midT),
            TopRight    = piece(midR,   right,   top,    midT),
            Left        = piece(left,   midL,    midT,   midB),
            Right       = piece(midR,   right,   midT,   midB),
            BottomLeft  = piece(left,   midL,    midB,   bottom),
            Bottom      = piece(midL,   midR,    midB,   bottom),
            BottomRight = piece(midR,   right,   midB,   bottom),
            Center      = piece(midL,   midR,    midT,   midB),
        }
        layout.TopLeft.width      = marginL; layout.TopLeft.height     = marginT
        layout.Top.height         = marginT
        layout.TopRight.width     = marginR; layout.TopRight.height    = marginT
        layout.Left.width         = marginL
        layout.Right.width        = marginR
        layout.BottomLeft.width   = marginL; layout.BottomLeft.height  = marginB
        layout.Bottom.height      = marginB
        layout.BottomRight.width  = marginR; layout.BottomRight.height = marginB

        self:SetLayout(layout)
    end;

    SetFromTextureRegion = function(self, file, fileW, fileH, x, y, w, h, marginL, marginT, marginR, marginB, scale)
        local left   = x / fileW
        local top    = y / fileH
        local right  = (x + w) / fileW
        local bottom = (y + h) / fileH
        self:_SetNineSlice(MUI_TEX_PATH .. file, left, right, top, bottom, w, h, marginL, marginT, marginR, marginB, scale)
    end;

    -- Build a 9-slice layout from a single atlas region by splitting it into 9 sub-texcoord
    -- rects. Margins are in source pixels and define the corner/edge sizes.
    SetFromAtlas = function(self, atlas, regionName, marginL, marginT, marginR, marginB, scale)
        local r = atlas:GetRegion(regionName)
        if not r then return end
        self:_SetNineSlice(r.file, r.left, r.right, r.top, r.bottom, r.width, r.height, marginL, marginT, marginR, marginB, scale)
    end;
}


